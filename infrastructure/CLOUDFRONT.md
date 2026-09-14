# Console deployment

This is the original test-oriented deployment using CloudFront, Amazon S3, and a public Lambda Function URL.

## 1. Upload the Lambda package

1. Open Amazon S3 in the same Region as the Amazon Connect instance.
2. Create or select a deployment bucket.
3. Upload `routing-profile-function.zip`.

## 2. Create the backend stack

1. Open AWS CloudFormation in the same Region as Amazon Connect.
2. Choose **Create stack - With new resources**.
3. Upload `template.yaml`.
4. Enter the Lambda code bucket, ZIP object key, Connect instance ID, and Connect instance ARN.
   The instance ARN follows the format:
   `arn:aws:connect:<region>:<account-id>:instance/<ConnectInstanceId>`
5. For the original open test configuration, leave `FrontendOrigin` as `*`.
6. Acknowledge IAM resource creation and create the stack.
7. When the stack finishes, copy the `FunctionUrl` output.

## 3. Build and publish the frontend

1. Set `REACT_APP_API_BASE_URL` to the CloudFormation `FunctionUrl` output.
2. Produce the React build using the normal project build process.
3. Upload the contents of the `build` folder to the S3 bucket used by CloudFront.
4. Create a CloudFront invalidation for `/*`.

The browser calls the Lambda Function URL directly.

## 4. Configure the Connect application

In **Amazon Connect - Your instance - Integrations**, create or edit the third-party application:

- Access URL: the CloudFront distribution URL.
- Permissions:

```json
["User.Details.View", "User.Configuration.View"]
```

- Associate the integration with the test Connect instance.
- Grant the application to the agent's Amazon Connect security profile.

## 5. Test

1. Open the application from the Amazon Connect Agent Workspace.
2. Confirm the current routing profile appears.
3. Confirm the list of routing profiles loads.
4. Select a profile and apply it.
5. Confirm the signed-in Connect agent's routing profile changes.

This procedure restores the earlier test/demo deployment.
