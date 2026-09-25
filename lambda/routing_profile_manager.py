import base64
import json
import logging
import os
import re
import time
import urllib.request
from typing import Any

import boto3
from botocore.exceptions import ClientError


LOGGER = logging.getLogger()
LOGGER.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

INSTANCE_ID = os.environ.get("CONNECT_INSTANCE_ID", "").strip()

# Okta JWT validation configuration
OKTA_ISSUER = os.environ.get("OKTA_ISSUER", "").strip()   # e.g. https://trial-7233824.okta.com
OKTA_CLIENT_ID = os.environ.get("OKTA_CLIENT_ID", "").strip()  # OIDC app client ID

# Optional comma-separated allowlist of routing profile names.
# When set, only those profiles are returned by GET /routing-profiles and
# only those profiles are accepted by PUT /routing-profile.
# When blank, all routing profiles in the Connect instance are available.
_raw_allowed = os.environ.get("ALLOWED_ROUTING_PROFILES", "").strip()
ALLOWED_ROUTING_PROFILES: set[str] = {
    name.strip() for name in _raw_allowed.split(",") if name.strip()
}

UUID_PATTERN = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-"
    r"[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
)
MAX_REQUEST_BODY_BYTES = 4096

connect = boto3.client("connect")

# ---------------------------------------------------------------------------
# Simple in-memory JWKS cache — avoids fetching Okta's public keys on every
# request. Refreshed automatically when the cache expires (1 hour TTL).
# ---------------------------------------------------------------------------
_jwks_cache: dict[str, Any] = {"keys": {}, "expires_at": 0}


class RequestError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


# ---------------------------------------------------------------------------
# Okta JWT validation
# ---------------------------------------------------------------------------

def _fetch_jwks() -> dict[str, Any]:
    """Fetch Okta's public keys from the JWKS endpoint and cache them."""
    global _jwks_cache

    now = time.time()
    if now < _jwks_cache["expires_at"] and _jwks_cache["keys"]:
        return _jwks_cache["keys"]

    jwks_url = f"{OKTA_ISSUER}/oauth2/v1/keys"
    try:
        with urllib.request.urlopen(jwks_url, timeout=5) as resp:
            jwks = json.loads(resp.read().decode("utf-8"))
    except Exception as error:
        LOGGER.error(f"Failed to fetch JWKS from Okta: {error}")
        raise RequestError(503, "Authentication service is unavailable.")

    # Index keys by kid (key ID) for fast lookup
    keys_by_kid = {key["kid"]: key for key in jwks.get("keys", [])}
    _jwks_cache = {"keys": keys_by_kid, "expires_at": now + 3600}
    return keys_by_kid


def _base64url_decode(value: str) -> bytes:
    """Decode a base64url-encoded string (no padding required)."""
    padding = 4 - len(value) % 4
    if padding != 4:
        value += "=" * padding
    return base64.urlsafe_b64decode(value)


def _decode_jwt_payload(token: str) -> dict[str, Any]:
    """Decode the JWT payload without verifying the signature.
    Signature verification is done separately using Okta's public keys.
    """
    parts = token.split(".")
    if len(parts) != 3:
        raise RequestError(401, "Invalid authorization token.")
    try:
        payload_bytes = _base64url_decode(parts[1])
        return json.loads(payload_bytes.decode("utf-8"))
    except Exception:
        raise RequestError(401, "Invalid authorization token.")


def _get_jwt_header(token: str) -> dict[str, Any]:
    """Decode the JWT header to extract the key ID (kid)."""
    parts = token.split(".")
    if len(parts) != 3:
        raise RequestError(401, "Invalid authorization token.")
    try:
        header_bytes = _base64url_decode(parts[0])
        return json.loads(header_bytes.decode("utf-8"))
    except Exception:
        raise RequestError(401, "Invalid authorization token.")


def _verify_jwt_signature(token: str, jwk: dict[str, Any]) -> None:
    """Verify the JWT signature using the RSA public key from Okta's JWKS.

    Uses only the Python standard library (no PyJWT or cryptography package)
    so no additional Lambda layers are required.
    """
    import hashlib
    import struct

    parts = token.split(".")
    message = f"{parts[0]}.{parts[1]}".encode("utf-8")
    signature = _base64url_decode(parts[2])

    # Decode RSA public key components from JWK
    try:
        n = int.from_bytes(_base64url_decode(jwk["n"]), "big")
        e = int.from_bytes(_base64url_decode(jwk["e"]), "big")
    except Exception:
        raise RequestError(401, "Invalid authorization token.")

    # RSA signature verification: signature^e mod n should equal the
    # PKCS#1 v1.5 padded SHA-256 hash of the message.
    try:
        sig_int = int.from_bytes(signature, "big")
        key_size = (n.bit_length() + 7) // 8
        decrypted = pow(sig_int, e, n)
        decrypted_bytes = decrypted.to_bytes(key_size, "big")
    except Exception:
        raise RequestError(401, "Invalid authorization token.")

    # Verify PKCS#1 v1.5 padding and SHA-256 DigestInfo prefix
    sha256_digest_info_prefix = bytes([
        0x30, 0x31, 0x30, 0x0d, 0x06, 0x09, 0x60, 0x86,
        0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01, 0x05,
        0x00, 0x04, 0x20,
    ])
    expected_suffix = sha256_digest_info_prefix + hashlib.sha256(message).digest()
    expected_length = len(expected_suffix)

    # PKCS#1 v1.5: 0x00 0x01 <padding 0xff bytes> 0x00 <DigestInfo>
    if (
        len(decrypted_bytes) < expected_length + 11
        or decrypted_bytes[0] != 0x00
        or decrypted_bytes[1] != 0x01
        or decrypted_bytes[-(expected_length):] != expected_suffix
        or decrypted_bytes[-(expected_length + 1)] != 0x00
        or not all(b == 0xFF for b in decrypted_bytes[2:-(expected_length + 1)])
    ):
        raise RequestError(401, "Invalid authorization token.")


def verify_okta_token(event: dict[str, Any]) -> dict[str, Any]:
    """Extract and validate the Okta JWT from the Authorization header.

    Returns the decoded token payload on success.
    Raises RequestError(401) on any validation failure.
    """
    if not OKTA_ISSUER or not OKTA_CLIENT_ID:
        raise RuntimeError("OKTA_ISSUER and OKTA_CLIENT_ID are required")

    # Extract Bearer token from Authorization header
    headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
    auth_header = headers.get("authorization", "")
    if not auth_header.lower().startswith("bearer "):
        raise RequestError(401, "Authorization token is required.")

    token = auth_header[7:].strip()
    if not token:
        raise RequestError(401, "Authorization token is required.")

    # Decode header and payload (no signature check yet)
    jwt_header = _get_jwt_header(token)
    payload = _decode_jwt_payload(token)

    # Validate issuer
    token_issuer = payload.get("iss", "")
    if token_issuer != OKTA_ISSUER:
        LOGGER.warning(f"JWT issuer mismatch: {token_issuer}")
        raise RequestError(401, "Invalid authorization token.")

    # Validate audience — must include the OIDC client ID
    aud = payload.get("aud", "")
    if isinstance(aud, str):
        aud = [aud]
    if OKTA_CLIENT_ID not in aud:
        LOGGER.warning(f"JWT audience mismatch: {aud}")
        raise RequestError(401, "Invalid authorization token.")

    # Validate expiry
    exp = payload.get("exp", 0)
    if time.time() > exp:
        raise RequestError(401, "Authorization token has expired.")

    # Fetch Okta public keys and verify signature
    kid = jwt_header.get("kid")
    if not kid:
        raise RequestError(401, "Invalid authorization token.")

    jwks = _fetch_jwks()
    jwk = jwks.get(kid)

    if not jwk:
        # Key not in cache — force a refresh once in case Okta rotated keys
        _jwks_cache["expires_at"] = 0
        jwks = _fetch_jwks()
        jwk = jwks.get(kid)

    if not jwk:
        LOGGER.warning(f"JWT kid not found in JWKS: {kid}")
        raise RequestError(401, "Invalid authorization token.")

    _verify_jwt_signature(token, jwk)

    LOGGER.info(json.dumps({
        "event": "token_verified",
        "subject": payload.get("sub", "unknown"),
    }))

    return payload


# ---------------------------------------------------------------------------
# Lambda handler
# ---------------------------------------------------------------------------

def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_id = getattr(context, "aws_request_id", "unknown")

    try:
        if not INSTANCE_ID:
            raise RuntimeError("CONNECT_INSTANCE_ID is required")

        method = event.get("requestContext", {}).get("http", {}).get("method", "")
        path = (event.get("rawPath") or "/").rstrip("/") or "/"

        # Allow CORS preflight requests through without auth
        if method == "OPTIONS":
            return response(200, {})

        # Validate Okta JWT on every non-OPTIONS request
        verify_okta_token(event)

        if method == "GET" and path.endswith("/routing-profiles"):
            profiles = list_routing_profiles()
            LOGGER.info(json.dumps({
                "event": "routing_profiles_listed",
                "requestId": request_id,
                "resultCount": len(profiles),
            }))
            return response(200, {"routingProfiles": profiles})

        if method == "PUT" and path.endswith("/routing-profile"):
            body = parse_json_body(event)
            if set(body) != {"agentArn", "routingProfileId"}:
                raise RequestError(
                    400,
                    "agentArn and routingProfileId are required.",
                )

            result = update_agent_routing_profile(
                agent_arn=body.get("agentArn"),
                routing_profile_id=body.get("routingProfileId"),
                request_id=request_id,
            )
            return response(200, result)

        raise RequestError(404, "Route not found.")

    except RequestError as error:
        LOGGER.warning(json.dumps({
            "event": "request_rejected",
            "requestId": request_id,
            "statusCode": error.status_code,
            "reason": error.message,
        }))
        return response(error.status_code, {"error": error.message})
    except ClientError as error:
        error_code = error.response.get("Error", {}).get("Code", "Unknown")
        LOGGER.error(json.dumps({
            "event": "connect_api_error",
            "requestId": request_id,
            "errorCode": error_code,
        }))
        if error_code in {
            "ResourceNotFoundException",
            "InvalidParameterException",
            "InvalidRequestException",
        }:
            return response(400, {"error": "The routing profile change is invalid."})
        return response(500, {"error": "The routing profile service is unavailable."})
    except Exception:
        LOGGER.exception(json.dumps({
            "event": "unhandled_error",
            "requestId": request_id,
        }))
        return response(500, {"error": "The routing profile service is unavailable."})


# ---------------------------------------------------------------------------
# Request helpers
# ---------------------------------------------------------------------------

def parse_json_body(event: dict[str, Any]) -> dict[str, Any]:
    raw_body = event.get("body") or ""
    if not isinstance(raw_body, str):
        raise RequestError(400, "Request body must be valid JSON.")

    try:
        body_bytes = (
            base64.b64decode(raw_body, validate=True)
            if event.get("isBase64Encoded")
            else raw_body.encode("utf-8")
        )
    except (ValueError, UnicodeError) as error:
        raise RequestError(400, "Request body must be valid JSON.") from error

    if len(body_bytes) > MAX_REQUEST_BODY_BYTES:
        raise RequestError(413, "Request body is too large.")

    try:
        body = json.loads(body_bytes.decode("utf-8"))
    except (json.JSONDecodeError, UnicodeError) as error:
        raise RequestError(400, "Request body must be valid JSON.") from error

    if not isinstance(body, dict):
        raise RequestError(400, "Request body must be a JSON object.")
    return body


def connect_user_id_from_arn(agent_arn: Any) -> str:
    if not isinstance(agent_arn, str):
        raise RequestError(400, "agentArn must be provided.")

    marker = f":instance/{INSTANCE_ID}/agent/"
    if marker not in agent_arn:
        raise RequestError(400, "agentArn does not belong to this Connect instance.")

    connect_user_id = agent_arn.rsplit("/", 1)[-1]
    if not UUID_PATTERN.fullmatch(connect_user_id):
        raise RequestError(400, "agentArn is invalid.")
    return connect_user_id


# ---------------------------------------------------------------------------
# Connect API wrappers
# ---------------------------------------------------------------------------

def list_routing_profiles() -> list[dict[str, str]]:
    routing_profiles = []
    paginator = connect.get_paginator("list_routing_profiles")

    for page in paginator.paginate(InstanceId=INSTANCE_ID):
        for profile in page.get("RoutingProfileSummaryList", []):
            name = profile.get("Name", "")
            # Apply allowlist filter if configured
            if ALLOWED_ROUTING_PROFILES and name not in ALLOWED_ROUTING_PROFILES:
                continue
            routing_profiles.append({
                "id": profile["Id"],
                "name": name,
            })

    routing_profiles.sort(key=lambda profile: profile["name"].casefold())
    return routing_profiles


def update_agent_routing_profile(
    agent_arn: Any,
    routing_profile_id: Any,
    request_id: str,
) -> dict[str, Any]:
    connect_user_id = connect_user_id_from_arn(agent_arn)

    if not isinstance(routing_profile_id, str) or not UUID_PATTERN.fullmatch(routing_profile_id):
        raise RequestError(400, "routingProfileId must be a valid identifier.")

    available_profiles = {
        profile["id"]: profile["name"]
        for profile in list_routing_profiles()
    }
    if routing_profile_id not in available_profiles:
        raise RequestError(400, "The selected routing profile is not available.")

    connect.update_user_routing_profile(
        RoutingProfileId=routing_profile_id,
        UserId=connect_user_id,
        InstanceId=INSTANCE_ID,
    )

    LOGGER.info(json.dumps({
        "event": "routing_profile_updated",
        "requestId": request_id,
        "connectUserId": connect_user_id,
        "routingProfileId": routing_profile_id,
    }))

    return {
        "success": True,
        "routingProfile": {
            "id": routing_profile_id,
            "name": available_profiles[routing_profile_id],
        },
    }


# ---------------------------------------------------------------------------
# Response helper
# ---------------------------------------------------------------------------

def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }
