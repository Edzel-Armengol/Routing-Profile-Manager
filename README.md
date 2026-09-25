# Amazon Connect Routing Profile Manager

A React application embedded in the Amazon Connect Agent Workspace that lets agents view and change their own routing profile.

---

## Architecture

```text
Amazon Connect Agent Workspace
        |
        | loads the embedded application
        | (CSP header restricts iframe to Connect only)
        v
CloudFront + Amazon S3
        |
        | direct browser request
        | (Okta JWT Bearer token attached to every API call)
        v
Lambda Function URL
        |
        | validates Okta JWT, then calls Connect API
        v
Amazon Connect API
```

---

## Security

### Content Security Policy (CSP) Header
CloudFront automatically adds the following header to every response:

```
Content-Security-Policy: frame-ancestors https://*.awsapps.com https://*.my.connect.aws
```

This ensures the app can only be embedded inside the Amazon Connect Agent Workspace. Any attempt to load it in another website is blocked by the browser.

### Okta JWT Validation
Every API request to the Lambda must include a valid Okta access token in the `Authorization` header. The Lambda:
- Fetches Okta's public signing keys (JWKS) and caches them for 1 hour
- Verifies the token signature using RSA/SHA-256
- Validates the issuer (`iss`) matches the configured Okta tenant URL
- Validates the audience (`aud`) matches the configured OIDC app Client ID
- Validates the token has not expired

Any request without a valid token receives a `401 Unauthorized` response.

---

## How It Works

1. The agent logs into Amazon Connect via Okta SSO.
2. The Routing Profile Manager app loads inside the Agent Workspace.
3. The app silently obtains an Okta access token in the background — no extra login required.
4. The app fetches the agent's current routing profile from the Connect SDK.
5. The app calls the Lambda with the Okta token to load the list of available routing profiles.
6. The agent selects a new routing profile and clicks **Apply Routing Profile**.
7. The Lambda validates the token, then updates the agent's routing profile via the Connect API.

---

## Project Structure

```
├── infrastructure/
│   └── template.yaml          CloudFormation stack (Lambda, CloudFront, S3, CSP)
├── lambda/
│   └── routing_profile_manager.py   Lambda handler with Okta JWT validation
├── public/
│   └── index.html
├── src/
│   ├── App.js                 Main React component
│   ├── api.js                 API client (attaches Okta token to requests)
│   ├── config.js              Environment variable configuration
│   ├── App.css
│   ├── index.css
│   └── index.js
├── .env.example               Template for required environment variables
├── package.json
└── README.md
```

---

## Prerequisites

Before deploying, make sure you have:

- An AWS account with permissions to create CloudFormation stacks, Lambda, S3, and CloudFront
- An Amazon Connect instance configured with **SAML 2.0 authentication** (Okta as the identity provider)
- Agents already able to log into Amazon Connect via Okta SSO
- AWS CLI installed and configured (`aws configure`)
- Node.js and npm installed
- PowerShell (for packaging the Lambda)

---

## Deployment Guide

### PHASE 1 — Request from the Client's Okta Administrator

You need the client's Okta admin to create an OIDC app for the Routing Profile Manager. Send them these instructions:

> **Instructions for Okta Admin:**
>
> 1. Log into the Okta Admin Console
> 2. Go to **Applications → Applications → Create App Integration**
> 3. Select **OIDC - OpenID Connect** → **Single-Page Application** → click **Next**
> 4. Fill in the following:
>    - **App integration name**: `Routing Profile Manager`
>    - **Grant type**: enable both **Authorization Code** and **Implicit (Hybrid)**
>    - **Sign-in redirect URIs**: enter `https://placeholder.cloudfront.net` for now — this will be updated after deployment
>    - **Controlled access**: select **Enable immediate access with Federation Broker Mode**
> 5. Click **Save**
> 6. From the app's **General** tab, copy the **Client ID**
> 7. Also note the **Okta Tenant URL** (e.g. `https://your-org.okta.com`)
> 8. Send both values back to the deployer

You will receive:
- **Okta Tenant URL** — e.g. `https://your-org.okta.com`
- **Client ID** — e.g. `0oa1b2c3d4e5f6g7h8i9`

---

### PHASE 2 — Collect the Amazon Connect Instance Details

1. Open the **AWS Console → Amazon Connect**
2. Click on your instance
3. Copy the following from the instance details page:
   - **Instance ID** — the UUID at the end of the Instance ARN
   - **Instance ARN** — the full ARN, e.g. `arn:aws:connect:ap-southeast-2:123456789012:instance/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

---

### PHASE 3 — Package the Lambda

Run the following command from the root of this project in PowerShell:

```powershell
Compress-Archive -Path "lambda\routing_profile_manager.py" -DestinationPath "infrastructure\routing-profile-function.zip" -Force
```

This creates `infrastructure\routing-profile-function.zip` which is the Lambda deployment package.

> Note: `routing-profile-function.zip` is excluded from the repository — it must always be built from the current source code.

---

### PHASE 4 — Upload the Lambda ZIP to S3

1. Open **AWS Console → S3**
2. Create a new S3 bucket in the **same region** as your Connect instance (e.g. `ap-southeast-2`)
   - Name it something like `routing-profile-manager-deployment`
   - Leave all other settings as default
3. Upload `infrastructure\routing-profile-function.zip` to this bucket

---

### PHASE 5 — Deploy the CloudFormation Stack

1. Open **AWS Console → CloudFormation**
2. Click **Create stack → With new resources (standard)**
3. Select **Upload a template file** and upload `infrastructure\template.yaml`
4. Click **Next**
5. Give the stack a name, e.g. `routing-profile-manager`
6. Fill in all parameters:

| Parameter | Where to find it | Example |
|---|---|---|
| `LambdaCodeBucket` | The S3 bucket name from Phase 4 | `routing-profile-manager-deployment` |
| `LambdaCodeKey` | Always this value | `routing-profile-function.zip` |
| `ConnectInstanceId` | From Phase 2 | `5455ba30-b941-4270-a0bf-b3f57317121f` |
| `ConnectInstanceArn` | From Phase 2 | `arn:aws:connect:ap-southeast-2:...` |
| `OktaIssuer` | Okta Tenant URL from Phase 1 | `https://your-org.okta.com` |
| `OktaClientId` | Client ID from Phase 1 | `0oa1b2c3d4e5f6g7h8i9` |
| `AllowedRoutingProfiles` | Optional — leave blank for all profiles | `Basic Routing Profile,Support Queue` |
| `FrontendBucketName` | A globally unique name you choose | `routing-profile-manager-frontend-prod` |

7. Click **Next** → **Next** → check **I acknowledge that AWS CloudFormation might create IAM resources** → **Submit**
8. Wait for the stack status to show **CREATE_COMPLETE** (approximately 3-5 minutes)

---

### PHASE 6 — Note Down the Stack Outputs

Once the stack is complete:

1. Click on your stack → go to the **Outputs** tab
2. Copy these three values:

| Output Key | What it is |
|---|---|
| `CloudFrontUrl` | The public HTTPS URL of your app — e.g. `https://d1234abcd.cloudfront.net` |
| `FunctionUrl` | The Lambda API URL |
| `FrontendBucketName` | The S3 bucket for the React build |

---

### PHASE 7 — Update the Okta Redirect URI

Send the `CloudFrontUrl` to the client's Okta admin and ask them to:

1. Open the **Routing Profile Manager** OIDC app in Okta
2. Go to the **General** tab → **General Settings** → click **Edit**
3. Under **Sign-in redirect URIs**, replace `https://placeholder.cloudfront.net` with the real `CloudFrontUrl`
4. Click **Save**

---

### PHASE 8 — Build and Deploy the React Frontend

**1. Create your `.env` file** in the project root (copy from `.env.example`):

```text
REACT_APP_API_BASE_URL=<FunctionUrl from Phase 6>
REACT_APP_OKTA_ISSUER=<Okta Tenant URL from Phase 1>
REACT_APP_OKTA_CLIENT_ID=<Client ID from Phase 1>
```

**2. Install dependencies** (only needed once):

```powershell
npm install
```

**3. Build the React app:**

```powershell
npm run build
```

This creates a `build\` folder with the compiled frontend.

**4. Upload the build to S3:**

```powershell
aws s3 sync build\ s3://<FrontendBucketName from Phase 6> --delete
```

**5. Invalidate the CloudFront cache:**

```powershell
aws cloudfront create-invalidation --distribution-id <your-distribution-id> --paths "/*"
```

To find your CloudFront distribution ID, go to **AWS Console → CloudFront** and look for the distribution matching your `CloudFrontUrl`.

---

### PHASE 9 — Register the App in Amazon Connect

1. Open **AWS Console → Amazon Connect → your instance → View Amazon Connect console**
2. In the left navigation, go to **Channels → Integrations** (or **Integrations** depending on your console version)
3. Click **Add integration**
4. Fill in:
   - **Integration type**: Standard application
   - **Display name**: `Routing Profile Manager`
   - **Description** (optional): `Self-service routing profile switcher for agents`
   - **Access URL**: the `CloudFrontUrl` from Phase 6
   - **Contact scope**: Per session
5. Under **Permissions**, add:
   - `User.Details.View`
   - `User.Configuration.View`
6. Under **Instance association**, select your Connect instance
7. Click **Add integration**

---

### PHASE 10 — Assign the App to Agent Security Profiles

1. Inside the Amazon Connect console, go to **Users → Security profiles**
2. Open the security profile assigned to the agents who should have access to this app
3. Go to **Applications** (or search for the app name)
4. Enable the **Routing Profile Manager** application
5. Click **Save**

Repeat for every security profile that should have access.

---

### PHASE 11 — Test End to End

1. Log into Amazon Connect as a test agent via Okta SSO
2. Open the **Agent Workspace**
3. Click the **Apps launcher** (grid icon in the top right of the workspace)
4. The **Routing Profile Manager** app should appear — click it
5. Confirm the agent's **current routing profile** is displayed
6. Confirm the **dropdown list of routing profiles** loads
7. Select a different routing profile and click **Apply Routing Profile**
8. Confirm a success message appears and the displayed routing profile updates

---

## Restricting Available Routing Profiles

By default, all routing profiles in the Connect instance are shown. To limit which profiles agents can switch to, set the `AllowedRoutingProfiles` CloudFormation parameter to a comma-separated list of routing profile **names exactly as they appear in Amazon Connect**:

```
Basic Routing Profile,Support - Tier 1,Support - Tier 2
```

When set:
- Only those profiles appear in the dropdown
- The Lambda rejects any attempt to switch to a profile not in the list

When blank, all profiles are available.

---

## Updating the Lambda Code

If the Lambda code changes, repackage and redeploy:

```powershell
# 1. Repackage
Compress-Archive -Path "lambda\routing_profile_manager.py" -DestinationPath "infrastructure\routing-profile-function.zip" -Force

# 2. Upload to S3
aws s3 cp infrastructure\routing-profile-function.zip s3://<LambdaCodeBucket>/routing-profile-function.zip

# 3. Update the Lambda function
aws lambda update-function-code --function-name <FunctionName from stack outputs> --s3-bucket <LambdaCodeBucket> --s3-key routing-profile-function.zip
```

## Updating the Frontend

If the React app changes, rebuild and redeploy:

```powershell
# 1. Rebuild
npm run build

# 2. Upload to S3
aws s3 sync build\ s3://<FrontendBucketName> --delete

# 3. Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id <distribution-id> --paths "/*"
```
