# rbios.net Email Forwarding Setup

This project sets up email forwarding for rbios.net using AWS SES and Lambda.

## 🚀 Deployment Status

✅ **DEPLOYED** - July 5, 2025  
**Function**: `rbios-email-forwarder`  
**Status**: Active, pending DNS verification

## Overview

The email forwarding system works like this:

1. Email is sent to any @rbios.net address
2. AWS SES receives the email and stores it in S3 (`rbios-email-bucket`)
3. SES triggers a Lambda function (`rbios-email-forwarder`)
4. Lambda forwards the email to `ryanmette@duck.com` with original content attached

## Files

- `lambda_function.py` - The Lambda function code that handles email forwarding
- `requirements.txt` - Python dependencies (boto3==1.34.0)
- `DEPLOYMENT_LOG.md` - Complete deployment documentation
- `rbios-email-forwarder.zip` - Lambda deployment package
- **Configuration Files:**
  - `receipt-rule.json` - SES receipt rule configuration
  - `lambda-env.json` - Lambda environment variables
  - `trust-policy.json` - IAM role trust policy
  - `ses-s3-policy.json` - Custom IAM policy for SES/S3 access
  - `s3-bucket-policy.json` - S3 bucket policy for SES access

## ⚡ Quick Start (Already Deployed)

The system is already deployed and configured! You just need to complete the DNS setup:

### 1. Required DNS Records

Add these DNS records to your rbios.net domain:

#### Domain Verification (TXT Record)

```
Record Type: TXT
Name: _amazonses.rbios.net
Value: PCUaDtGJnd4oBOArD3QvjRcugl0r7GIoR04uBkG8I/o=
TTL: 1800
```

#### MX Record for Email Reception

```
Record Type: MX
Name: rbios.net
Value: 10 inbound-smtp.us-east-1.amazonaws.com
TTL: 1800
```

### 2. Email Verification

Check your email for verification messages:

- Verify `ryanmette@duck.com` (click the verification link)
- Verify `noreply@rbios.net` (if you have access to that mailbox)

### 3. Test the System

Once DNS propagates (15-30 minutes), send a test email to `test@rbios.net` and check `ryanmette@duck.com`.

## 📋 Deployed Resources

- **Lambda Function**: `rbios-email-forwarder` (us-east-1)
- **S3 Bucket**: `rbios-email-bucket` (email storage)
- **SES Rule Set**: `rbios-email-rules` (active)
- **SES Receipt Rule**: `rbios-email-forwarder-rule`
- **IAM Role**: `rbios-email-forwarder-role`

## Setup Instructions (For Reference)

### 1. Prerequisites

- AWS CLI configured with appropriate permissions
- Domain rbios.net with Route53 hosted zone
- Access to SES (Simple Email Service)

### 2. Configure Email Forwarding

The system is configured to forward ALL emails to `ryanmette@duck.com`:

**Environment Variables** (already set):

```bash
FORWARD_TO_EMAIL=ryanmette@duck.com
DOMAIN=rbios.net
FROM_EMAIL=noreply@rbios.net
```

**Catch-All Setup**: This configuration forwards ALL emails sent to ANY address @rbios.net to `ryanmette@duck.com`. Examples:

- `contact@rbios.net` → ryanmette@duck.com
- `admin@rbios.net` → ryanmette@duck.com
- `randomname@rbios.net` → ryanmette@duck.com
- `anything@rbios.net` → ryanmette@duck.com

### 3. Deployment Commands Used

The deployment was completed using AWS CLI. See `DEPLOYMENT_LOG.md` for complete details.

### 4. Verification Status Check

Check verification status:

```bash
aws ses get-identity-verification-attributes --identities rbios.net noreply@rbios.net ryanmette@duck.com
```

## Catch-All Email Setup

This setup creates a **catch-all** email forwarding system:

- **ANY** email sent to **ANY** address @rbios.net will be forwarded to `ryanmette@duck.com`
- Examples that will all work:

  - `contact@rbios.net`
  - `admin@rbios.net`
  - `info@rbios.net`
  - `support@rbios.net`
  - `hello@rbios.net`
  - `randomname@rbios.net`
  - `anything@rbios.net`

- **Special addresses**:
  - `noreply@rbios.net` - Used for sending notifications (configured as FROM_EMAIL)

## Cost Estimation

- **SES**: $0.10 per 1,000 emails received
- **Lambda**: Essentially free for typical email volumes
- **S3**: Minimal storage costs for email retention

## Troubleshooting

### Common Issues

1. **Domain not verified**: Make sure all DNS records are added to Route53
2. **Lambda permissions**: Ensure the execution role has SES and S3 permissions
3. **Receipt rule not triggering**: Check that the rule is enabled and active

### Logs

Check CloudWatch logs for the Lambda function:

```bash
aws logs tail /aws/lambda/rbios-email-forwarder --follow
```

### Check Deployment Status

Verify Lambda function:

```bash
aws lambda get-function --function-name rbios-email-forwarder
```

Check SES rule:

```bash
aws ses describe-receipt-rule --rule-set-name rbios-email-rules --rule-name rbios-email-forwarder-rule
```

### Testing SES

Test domain verification:

```bash
aws ses get-identity-verification-attributes --identities rbios.net
```

View S3 bucket contents (received emails):

```bash
aws s3 ls s3://rbios-email-bucket/emails/ --recursive
```

### Testing Lambda Function

Test the Lambda function manually:

```bash
./test-function.sh
```

This script invokes the Lambda function with a test payload to verify it's working correctly.

Monitor real-time logs:

```bash
./tail-logs.sh
```

This script will show real-time logs from the Lambda function. If the function hasn't been invoked yet, it will display helpful instructions.

## Security Notes

- Emails are stored in S3 temporarily for processing
- Lambda function has minimal required permissions
- Consider setting up S3 lifecycle rules to delete old emails
- All forwarded emails include original sender information

## Customization

To modify forwarding configuration:

### Change Destination Email

```bash
aws lambda update-function-configuration \
  --function-name rbios-email-forwarder \
  --environment 'Variables={"FORWARD_TO_EMAIL":"new-email@example.com","DOMAIN":"rbios.net","FROM_EMAIL":"noreply@rbios.net"}'
```

### Update Lambda Code

1. Modify `lambda_function.py`
2. Create new deployment package:
   ```bash
   cp lambda_function.py package/
   cd package && zip -r ../rbios-email-forwarder.zip . && cd ..
   ```
3. Update function:
   ```bash
   aws lambda update-function-code --function-name rbios-email-forwarder --zip-file fileb://rbios-email-forwarder.zip
   ```

All emails to ANY @rbios.net address will automatically forward to the configured destination.
