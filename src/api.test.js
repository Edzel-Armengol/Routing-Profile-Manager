import {
  ApiError,
  listRoutingProfiles,
  updateRoutingProfile
} from "./api";

function jsonResponse(status, payload) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: { get: () => "application/json" },
    json: async () => payload
  };
}

describe("routing profile API client", () => {
  beforeEach(() => {
    global.fetch = jest.fn();
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  test("lists routing profiles from the Lambda endpoint", async () => {
    global.fetch.mockResolvedValue(jsonResponse(200, { routingProfiles: [] }));

    await listRoutingProfiles();

    expect(global.fetch).toHaveBeenCalledWith(
      "/routing-profiles",
      expect.objectContaining({
        method: "GET",
        cache: "no-store",
        headers: {
          Accept: "application/json"
        }
      })
    );
  });

  test("sends the Connect agent ARN and selected profile", async () => {
    global.fetch.mockResolvedValue(jsonResponse(200, { success: true }));

    await updateRoutingProfile("agent-arn", "profile-id");

    const [path, options] = global.fetch.mock.calls[0];
    expect(path).toBe("/routing-profile");
    expect(options.method).toBe("PUT");
    expect(JSON.parse(options.body)).toEqual({
      agentArn: "agent-arn",
      routingProfileId: "profile-id"
    });
    expect(options.headers.Authorization).toBeUndefined();
  });

  test("returns the API error message", async () => {
    global.fetch.mockResolvedValue(jsonResponse(400, { error: "Invalid request." }));

    await expect(listRoutingProfiles()).rejects.toEqual(
      new ApiError("Invalid request.", 400)
    );
  });
});
