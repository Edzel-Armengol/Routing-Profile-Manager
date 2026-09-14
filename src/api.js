import { API_BASE_URL } from "./config";

export class ApiError extends Error {
  constructor(message, status) {
    super(message);
    this.name = "ApiError";
    this.status = status;
  }
}

async function request(path, options = {}) {
  const body = options.body ? JSON.stringify(options.body) : null;
  const response = await fetch(`${API_BASE_URL}${path}`, {
    method: options.method || "GET",
    cache: "no-store",
    headers: {
      Accept: "application/json",
      ...(body ? { "Content-Type": "application/json" } : {})
    },
    ...(body ? { body } : {})
  });

  const contentType = response.headers.get("content-type") || "";
  const payload = contentType.includes("application/json")
    ? await response.json()
    : null;

  if (!response.ok) {
    throw new ApiError(
      payload?.error || "The routing profile service request failed.",
      response.status
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
