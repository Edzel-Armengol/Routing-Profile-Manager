# Amazon Connect Routing Profile Manager

A React application embedded in the Amazon Connect Agent Workspace that lets agents view and change their own routing profile.

## Architecture

```text
Amazon Connect Agent Workspace
        |
        | loads the embedded application (iframe restricted to Connect only via CSP)
        v
CloudFront + Amazon S3
        |
        | direct browser request (Okta JWT Bearer token on every call)
        v
Public Lambda Function URL (AuthType: NONE — auth enforced at application layer)
        |
        v
Lambda — validates Okta JWT, then calls Amazon Connect API
```

## Security

Two security measures are implemented as per AWS recommendations:

### 1. Content Security Policy (CSP) Header
CloudFront adds a `Content-Security-Policy` header on every response restricting the app to only be embeddable inside Amazon Connect:

```
Content-Security-Policy: frame-ancestors https://*.awsapps.com https://*.my.connect.aws
```

This prevents the app from being iframed in any other website.

### 2. Okta JWT Validation
Every request to the Lambda must include a valid Okta JWT Bearer token in the `Authorization` header. The Lambda:
- Fetches Okta's public keys (JWKS) and caches them for 1 hour
- Verifies the token signature using RSA/SHA-256
- Validates the issuer (`iss`) matches the configured Okta tenant
- Validates the audience (`aud`) matches the configured OIDC client ID
- Validates the token has not expired

Requests without a valid token receive a `401` response.

## How it works

1. The React application initialises inside the Amazon Connect Agent Workspace.
2. The agent is already authenticated via Okta SSO (used to log into Connect).
3. The app silently obtains an Okta access token using the implicit flow (no login prompt).
4. The agent's ARN and current routing profile are fetched from the Connect SDK.
5. The frontend calls the Lambda with the Okta token to list available routing profiles.
6. When the agent selects a profile and clicks Apply, the frontend sends the agent ARN, routing profile ID, and Okta token to Lambda.
7. Lambda validates the token, then calls `UpdateUserRoutingProfile` on the Connect API.

## Frontend configuration

Copy `.env.example` to `.env` and set:

```text
REACT_APP_API_BASE_URL=https://your-function-id.lambda-url.ap-southeast-2.on.aws
REACT_APP_OKTA_ISSUER=https://your-org.okta.com
REACT_APP_OKTA_CLIENT_ID=your-okta-client-id
```

- `REACT_APP_API_BASE_URL` — the `FunctionUrl` output from the CloudFormation stack
- `REACT_APP_OKTA_ISSUER` — your Okta tenant URL (no trailing slash)
- `REACT_APP_OKTA_CLIENT_ID` — the Client ID of the Routing Profile Manager OIDC app in Okta

## Backend deployment

### Prerequisites
- An Okta tenant with:
  - Amazon Connect configured as a SAML identity provider (agents log into Connect via Okta)
  - A separate OIDC Single-Page Application created for the Routing Profile Manager
- An Amazon Connect instance configured with SAML 2.0 authentication (Okta)

### CloudFormation parameters

| Parameter | Description |
|---|---|
| `LambdaCodeBucket` | S3 bucket containing the Lambda ZIP |
| `LambdaCodeKey` | S3 object key for the ZIP (default: `routing-profile-function.zip`) |
| `ConnectInstanceId` | Amazon Connect instance ID |
| `ConnectInstanceArn` | Amazon Connect instance ARN |
| `OktaIssuer` | Okta tenant URL (e.g. `https://your-org.okta.com`) |
| `OktaClientId` | Client ID of the Routing Profile Manager OIDC app in Okta |
| `AllowedRoutingProfiles` | Optional comma-separated routing profile name allowlist |
| `FrontendBucketName` | Globally unique S3 bucket name for the React frontend |

### What the CloudFormation stack creates

- S3 bucket (private) for the React frontend
- CloudFront distribution with CSP response headers policy
- CloudFront Origin Access Control (OAC) for secure S3 access
- Lambda function with Okta JWT validation
- Lambda Function URL (`AuthType: NONE` — auth handled at application layer)
- IAM permissions for Connect API calls

### Packaging and deploying the Lambda

```powershell
Compress-Archive -Path "lambda\routing_profile_manager.py" -DestinationPath "infrastructure\routing-profile-function.zip" -Force
```

Upload `routing-profile-function.zip` to your S3 deployment bucket, then deploy the CloudFormation stack.

### After deployment

1. Copy the `CloudFrontUrl` output — this is the Access URL for the Connect integration
2. Copy the `FunctionUrl` output — set this as `REACT_APP_API_BASE_URL` in your `.env`
3. Update the Okta OIDC app sign-in redirect URI to the `CloudFrontUrl` value
4. Build the React app and upload the `build/` folder contents to the S3 frontend bucket
5. Create a CloudFront invalidation for `/*`

### Restricting available routing profiles

Set `ALLOWED_ROUTING_PROFILES` to a comma-separated list of routing profile names to limit which profiles agents can switch to:

```
ALLOWED_ROUTING_PROFILES=Basic Routing Profile,Premium Routing Profile
```

When blank, all routing profiles in the instance are available.

## Amazon Connect integration

The embedded application requires these workspace permissions in the agent's security profile:

```json
["User.Details.View", "User.Configuration.View"]
```

Register the app under **Amazon Connect → Integrations → Applications**:
- **Access URL**: the `CloudFrontUrl` output from CloudFormation
- **Permissions**: `User.Details.View`, `User.Configuration.View`

Assign the integration to the relevant security profiles.

## Testing

1. Log into Amazon Connect via Okta SSO.
2. Open the Routing Profile Manager from the Agent Workspace apps launcher.
3. Confirm the current routing profile is displayed.
4. Confirm the routing profile list loads.
5. Select a profile and click **Apply Routing Profile**.
6. Confirm the agent's routing profile updates successfully.
