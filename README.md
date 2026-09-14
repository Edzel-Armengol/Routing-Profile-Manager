# Amazon Connect Routing Profile Manager

This project provides a small application in the Amazon Connect Agent Workspace that lets an agent view and change their routing profile.

## Restored architecture

```text
Amazon Connect Agent Workspace
        |
        | loads the embedded application
        v
CloudFront + Amazon S3
        |
        | direct browser request
        v
Public Lambda Function URL
        |
        v
Lambda + Amazon Connect API
```

This restores the original test/demo architecture.

## How it works

1. The React application initializes inside the Amazon Connect Agent Workspace.
2. The Amazon Connect Agent Client returns the signed-in agent ARN and current routing profile.
3. The frontend calls the Lambda Function URL to list routing profiles.
4. When the agent selects a profile, the frontend sends the agent ARN and routing-profile ID to Lambda.
5. Lambda extracts the Connect user ID from the ARN and calls `UpdateUserRoutingProfile`.

## Frontend configuration

Copy `.env.example` to the environment file used by the React build and set:

```text
REACT_APP_API_BASE_URL=https://your-function-id.lambda-url.ap-southeast-2.on.aws
```

The value should be the `FunctionUrl` output from the CloudFormation stack.

## Backend deployment

The backend files are:

- `lambda/routing_profile_manager.py`
- `infrastructure/routing-profile-function.zip`
- `infrastructure/template.yaml`

The CloudFormation template creates:

- One Lambda function
- A public Lambda Function URL with `AuthType: NONE`
- The IAM permissions required to list routing profiles and update an agent routing profile

See `infrastructure/CLOUDFRONT.md` for the console deployment procedure.

### Restricting available routing profiles

By default all routing profiles in the Connect instance are shown in the dropdown and can be selected. To limit this to a specific set, set the `ALLOWED_ROUTING_PROFILES` environment variable on the Lambda function to a comma-separated list of routing profile **names**:

```
ALLOWED_ROUTING_PROFILES=Basic Routing Profile
```

Multiple values:

```
ALLOWED_ROUTING_PROFILES=Basic Routing Profile,Premium Routing Profile,Support Queue
```

When this variable is set:
- `GET /routing-profiles` returns only the named profiles.
- `PUT /routing-profile` rejects any profile ID that is not in the allowed set with a `400` error.

When the variable is blank or not set, all profiles remain available (the original behaviour).

This can also be set via the `AllowedRoutingProfiles` parameter when deploying or updating the CloudFormation stack.

## Amazon Connect integration

The embedded application requires these workspace permissions:

```json
["User.Details.View", "User.Configuration.View"]
```

The application must also be assigned to the required Amazon Connect security profile.

## Testing

Confirm that:

1. The application opens inside the Agent Workspace.
2. The current agent routing profile appears.
3. The routing-profile list loads.
4. Selecting and applying a profile updates the signed-in test agent.

This restored version should be treated as the original demonstration and test implementation.
