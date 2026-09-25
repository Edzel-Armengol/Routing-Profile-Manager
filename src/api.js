import { OktaAuth } from "@okta/okta-auth-js";
import { API_BASE_URL, OKTA_ISSUER, OKTA_CLIENT_ID } from "./config";

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

// ---------------------------------------------------------------------------
// Okta Auth JS client
// Initialised once at module load. Uses the Okta Auth JS SDK which handles
// silent token renewal via postMessage — works correctly inside iframes such
// as the Amazon Connect Agent Workspace.
// ---------------------------------------------------------------------------
let _oktaAuth = null;

function getOktaAuth() {
  if (!_oktaAuth) {
    if (!OKTA_ISSUER || !OKTA_CLIENT_ID) {
      throw new ApiError("Okta is not configured.", 500);
    }
    _oktaAuth = new OktaAuth({
      issuer: OKTA_ISSUER,
      clientId: OKTA_CLIENT_ID,
      redirectUri: window.location.origin,
      scopes: ["openid", "profile"],
      pkce: false,          // use implicit flow — no auth code exchange needed
      tokenManager: {
        autoRenew: true,    // SDK renews the token automatically before expiry
        storage: "memory",  // store tokens in memory only — no localStorage
      },
    });
  }
  return _oktaAuth;
}

// ---------------------------------------------------------------------------
// Okta token retrieval
// Gets a cached access token from the SDK token manager, or fetches a fresh
// one silently using getWithoutPrompt (no login prompt shown to the agent).
// ---------------------------------------------------------------------------
async function getOktaToken() {
  const oktaAuth = getOktaAuth();

  // Check if we already have a valid token in the token manager
  try {
    const existingToken = await oktaAuth.tokenManager.get("accessToken");
    if (existingToken && !oktaAuth.tokenManager.hasExpired(existingToken)) {
      return existingToken.accessToken;
    }
  } catch {
    // Token manager empty or expired — fall through to fetch a fresh token
  }

  // Fetch a fresh token silently — agent is already authenticated via Okta SSO
  try {
    const { tokens } = await oktaAuth.token.getWithoutPrompt({
      responseType: ["token"],
      scopes: ["openid", "profile"],
    });

    if (!tokens?.accessToken) {
      throw new ApiError("Unable to obtain authentication token.", 401);
    }

    // Store for future calls
    oktaAuth.tokenManager.setTokens(tokens);
    return tokens.accessToken.accessToken;
  } catch (error) {
    if (error instanceof ApiError) throw error;

    // Okta returned an error — agent session may have expired
    throw new ApiError("Authentication failed. Please log in again.", 401);
  }
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
      ...(body ? { "Content-Type": "application/json" } : {}),
    },
    ...(body ? { body } : {}),
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
    body: { agentArn, routingProfileId },
  });
}
