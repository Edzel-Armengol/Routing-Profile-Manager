import { API_BASE_URL, OKTA_ISSUER, OKTA_CLIENT_ID } from "./config";

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// Okta token management
// Obtains an ID token from Okta using the implicit flow (no redirect needed
// for apps already running inside an authenticated Okta session via SSO).
// The token is cached in memory and refreshed when it expires.
// ---------------------------------------------------------------------------
let _cachedToken = null;
let _tokenExpiresAt = 0;

async function getOktaToken() {
  const now = Date.now() / 1000;

  // Return cached token if still valid (with 60 second buffer)
  if (_cachedToken && now < _tokenExpiresAt - 60) {
    return _cachedToken;
  }

  if (!OKTA_ISSUER || !OKTA_CLIENT_ID) {
    throw new ApiError("Okta is not configured.", 500);
  }

  // Use the Okta /authorize endpoint with response_type=token (implicit flow)
  // Since the agent is already authenticated via Okta SSO, this returns a
  // token silently using a hidden iframe (no user interaction required).
  const authorizeUrl = new URL(`${OKTA_ISSUER}/oauth2/v1/authorize`);
  authorizeUrl.searchParams.set("client_id", OKTA_CLIENT_ID);
  authorizeUrl.searchParams.set("response_type", "token");
  authorizeUrl.searchParams.set("scope", "openid profile");
  authorizeUrl.searchParams.set("redirect_uri", window.location.origin);
  authorizeUrl.searchParams.set("nonce", crypto.randomUUID());
  authorizeUrl.searchParams.set("prompt", "none"); // silent — no login prompt
  authorizeUrl.searchParams.set("response_mode", "fragment");

  return new Promise((resolve, reject) => {
    const iframe = document.createElement("iframe");
    iframe.style.display = "none";

    const cleanup = () => {
      if (iframe.parentNode) {
        document.body.removeChild(iframe);
      }
    };

    const timeout = setTimeout(() => {
      cleanup();
      reject(new ApiError("Authentication timed out. Please refresh the page.", 401));
    }, 10000);

    iframe.onload = () => {
      try {
        const hash = iframe.contentWindow.location.hash;
        const params = new URLSearchParams(hash.substring(1));
        const accessToken = params.get("access_token");
        const expiresIn = parseInt(params.get("expires_in") || "3600", 10);
        const error = params.get("error");

        clearTimeout(timeout);
        cleanup();

        if (error) {
          reject(new ApiError("Authentication failed. Please log in again.", 401));
          return;
        }

        if (!accessToken) {
          reject(new ApiError("Unable to obtain authentication token.", 401));
          return;
        }

        _cachedToken = accessToken;
        _tokenExpiresAt = Date.now() / 1000 + expiresIn;
        resolve(accessToken);
      } catch {
        // Cross-origin error means the redirect went to a different origin
        // which shouldn't happen with prompt=none in a same-session context
        clearTimeout(timeout);
        cleanup();
        reject(new ApiError("Authentication failed. Please log in again.", 401));
      }
    };

    iframe.src = authorizeUrl.toString();
    document.body.appendChild(iframe);
  });
}

// ---------------------------------------------------------------------------
// HTTP request helper — attaches Okta Bearer token on every call
// ---------------------------------------------------------------------------
async function request(path, options = {}) {
  const token = await getOktaToken();
  const body = options.body ? JSON.stringify(options.body) : null;

  const fetchResponse = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method || "GET",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      Authorization: `Bearer ${token}`,
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    ...(body ? { body } : {})
  });

  const contentType = fetchResponse.headers.get("content-type") || "";
  const payload = contentType.includes("application/json")
    ? await fetchResponse.json()
    : null;

  if (!fetchResponse.ok) {
    throw new ApiError(
      payload?.error || "The routing profile service request failed.",
      fetchResponse.status
    );
  }

  return payload;
}

export function listRoutingProfiles() {
  return request("/routing-profiles");
}

export function updateRoutingProfile(agentArn, routingProfileId) {
  return request("/routing-profile", {
    method: "PUT",
    body: { agentArn, routingProfileId }
  });
}
