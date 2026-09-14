import base64
import json
import logging
import os
import re
from typing import Any

import boto3
from botocore.exceptions import ClientError


LOGGER = logging.getLogger()
LOGGER.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

INSTANCE_ID = os.environ.get("CONNECT_INSTANCE_ID", "").strip()

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


class RequestError(Exception):
    def __init__(self, status_code: int, message: str):
        super().__init__(message)
        self.status_code = status_code
        self.message = message


def lambda_handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    request_id = getattr(context, "aws_request_id", "unknown")

    try:
        if not INSTANCE_ID:
            raise RuntimeError("CONNECT_INSTANCE_ID is required")

        method = event.get("requestContext", {}).get("http", {}).get("method", "")
        path = (event.get("rawPath") or "/").rstrip("/") or "/"

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


def response(status_code: int, body: dict[str, Any]) -> dict[str, Any]:
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
        },
        "body": json.dumps(body),
    }
