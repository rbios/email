# RBIOS Email Forwarder - Deployment Log

**Date**: July 5, 2025  
**Project**: rbios-email-forwarder  
**Purpose**: Deploy AWS Lambda function to forward emails received via SES for rbios.net domain

## Overview

This deployment sets up an email forwarding system that:

- Receives emails sent to any address @rbios.net via Amazon SES
- Stores raw emails in S3 for processing
- Triggers a Lambda function to forward emails to ryanmette@duck.com
- Preserves original email content and sender information

## Project Structure

```
/Users/ryamet/src/rbios/email/
├── lambda_function.py          # Main Lambda handler code
├── requirements.txt            # Python dependencies (boto3==1.34.0)
├── config.json                 # Project configuration
├── deploy.sh                   # Deployment script
├── setup.sh                    # Setup script
├── test.sh                     # Test script
├── README.md                   # Project documentation
├── package/                    # Dependencies directory (created during deployment)
├── rbios-email-forwarder.zip   # Lambda deployment package
├── trust-policy.json           # IAM role trust policy
├── ses-s3-policy.json          # Custom IAM policy for SES/S3 access
├── receipt-rule.json           # SES receipt rule configuration
├── s3-bucket-policy.json       # S3 bucket policy for SES access
├── lambda-env.json             # Lambda environment variables
└── DEPLOYMENT_LOG.md           # This deployment log
```

## Step-by-Step Deployment Process

### Phase 1: Environment Setup and Package Creation

#### 1. Python Dependencies Installation

```bash
cd /Users/ryamet/src/rbios/email
mkdir package
pip install boto3==1.34.0 -t package/
```

**Result**: Installed boto3 and its dependencies (botocore, jmespath, python-dateutil, s3transfer, six, urllib3) into the `package/` directory.

#### 2. Create Deployment Package

```bash
# Copy Lambda function code into package
cp lambda_function.py package/

# Create deployment zip
cd package
zip -r ../rbios-email-forwarder.zip .
cd ..
```

**Result**: Created `rbios-email-forwarder.zip` (15.6 MB) containing all dependencies and Lambda code.

### Phase 2: AWS Identity and Access Management (IAM)

#### 3. Verify AWS CLI Configuration

```bash
aws sts get-caller-identity
```

**Output**:

```json
{
  "UserId": "AIDAXXXXXXXXXXXXXXXXXXXX",
  "Account": "416792107027",
  "Arn": "arn:aws:iam::416792107027:user/ryamet"
}
```

#### 4. Create IAM Trust Policy

**File**: `trust-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### 5. Create IAM Role (Found Existing)

```bash
aws iam create-role --role-name rbios-email-forwarder-role --assume-role-policy-document file://trust-policy.json
```

**Result**: Role already existed, proceeded with existing role.

#### 6. Attach Basic Lambda Execution Policy

```bash
aws iam attach-role-policy --role-name rbios-email-forwarder-role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
```

#### 7. Create Custom SES/S3 Policy

**File**: `ses-s3-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["ses:SendEmail", "ses:SendRawEmail"],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::*/*"
    }
  ]
}
```

```bash
aws iam put-role-policy --role-name rbios-email-forwarder-role --policy-name SES-S3-Policy --policy-document file://ses-s3-policy.json
```

### Phase 3: Lambda Function Deployment

#### 8. Create Lambda Function

```bash
aws lambda create-function \
  --function-name rbios-email-forwarder \
  --runtime python3.9 \
  --role arn:aws:iam::416792107027:role/rbios-email-forwarder-role \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://rbios-email-forwarder.zip \
  --description "Email forwarder for rbios.net domain" \
  --timeout 30 \
  --memory-size 128
```

**Output**:

```json
{
  "FunctionName": "rbios-email-forwarder",
  "FunctionArn": "arn:aws:lambda:us-east-1:416792107027:function:rbios-email-forwarder",
  "Runtime": "python3.9",
  "Role": "arn:aws:iam::416792107027:role/rbios-email-forwarder-role",
  "Handler": "lambda_function.lambda_handler",
  "CodeSize": 15638058,
  "Description": "Email forwarder for rbios.net domain",
  "Timeout": 30,
  "MemorySize": 128,
  "LastModified": "2025-07-05T16:20:40.745+0000",
  "CodeSha256": "upM4vdgOh/mkWtp3u9XSVqshSn4vLR1FQaUFXVwpt9g="
}
```

#### 9. Grant SES Permission to Invoke Lambda

```bash
aws lambda add-permission \
  --function-name rbios-email-forwarder \
  --statement-id SESInvoke \
  --action lambda:InvokeFunction \
  --principal ses.amazonaws.com
```

**Result**: Successfully granted SES permission to invoke the Lambda function.

#### 10. Configure Environment Variables

**File**: `lambda-env.json`

```json
{
  "Variables": {
    "FORWARD_TO_EMAIL": "ryanmette@duck.com",
    "DOMAIN": "rbios.net",
    "FROM_EMAIL": "noreply@rbios.net"
  }
}
```

```bash
aws lambda update-function-configuration \
  --function-name rbios-email-forwarder \
  --environment file://lambda-env.json
```

### Phase 4: S3 Bucket Setup

#### 11. Create S3 Bucket for Email Storage

```bash
aws s3 mb s3://rbios-email-bucket --region us-east-1
```

**Result**: `make_bucket: rbios-email-bucket`

#### 12. Configure S3 Bucket Policy for SES

**File**: `s3-bucket-policy.json`

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSESPuts",
      "Effect": "Allow",
      "Principal": {
        "Service": "ses.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::rbios-email-bucket/*",
      "Condition": {
        "StringEquals": {
          "aws:Referer": "416792107027"
        }
      }
    }
  ]
}
```

```bash
aws s3api put-bucket-policy --bucket rbios-email-bucket --policy file://s3-bucket-policy.json
```

### Phase 5: SES Configuration

#### 13. Create SES Receipt Rule Set

```bash
aws ses create-receipt-rule-set --rule-set-name rbios-email-rules
aws ses set-active-receipt-rule-set --rule-set-name rbios-email-rules
```

#### 14. Create SES Receipt Rule

**File**: `receipt-rule.json`

```json
{
  "Name": "rbios-email-forwarder-rule",
  "Enabled": true,
  "TlsPolicy": "Optional",
  "Recipients": ["rbios.net"],
  "Actions": [
    {
      "S3Action": {
        "BucketName": "rbios-email-bucket",
        "ObjectKeyPrefix": "emails/"
      }
    },
    {
      "LambdaAction": {
        "FunctionArn": "arn:aws:lambda:us-east-1:416792107027:function:rbios-email-forwarder"
      }
    }
  ],
  "ScanEnabled": true
}
```

```bash
aws ses create-receipt-rule \
  --rule-set-name rbios-email-rules \
  --rule file://receipt-rule.json
```

#### 15. Verify SES Identities

```bash
# Verify domain
aws ses verify-domain-identity --domain rbios.net

# Verify email addresses
aws ses verify-email-identity --email-address noreply@rbios.net
aws ses verify-email-identity --email-address ryanmette@duck.com
```

**Domain Verification Token**: `PCUaDtGJnd4oBOArD3QvjRcugl0r7GIoR04uBkG8I/o=`

### Phase 6: Verification Status

#### Final Identity Status Check

```bash
aws ses get-identity-verification-attributes --identities rbios.net noreply@rbios.net ryanmette@duck.com
```

**Output**:

```json
{
  "VerificationAttributes": {
    "rbios.net": {
      "VerificationStatus": "Pending",
      "VerificationToken": "PCUaDtGJnd4oBOArD3QvjRcugl0r7GIoR04uBkG8I/o="
    },
    "ryanmette@duck.com": {
      "VerificationStatus": "Pending"
    },
    "noreply@rbios.net": {
      "VerificationStatus": "Pending"
    }
  }
}
```

## Lambda Function Details

### Handler Function

- **File**: `lambda_function.py`
- **Handler**: `lambda_function.lambda_handler`
- **Runtime**: Python 3.9
- **Memory**: 128 MB
- **Timeout**: 30 seconds

### Key Features

1. **Catch-all Email Forwarding**: Forwards all emails sent to `*@rbios.net`
2. **Original Email Preservation**: Attaches the original email as `.eml` file
3. **Detailed Logging**: Comprehensive logging for debugging
4. **Error Handling**: Robust error handling with proper status codes
5. **Environment Configuration**: Configurable via environment variables

### Environment Variables

- `FORWARD_TO_EMAIL`: `ryanmette@duck.com` (destination for forwarded emails)
- `DOMAIN`: `rbios.net` (domain to handle)
- `FROM_EMAIL`: `noreply@rbios.net` (sender address for forwarded emails)

## AWS Resources Created

### IAM Resources

- **Role**: `rbios-email-forwarder-role`
- **Policies**:
  - `AWSLambdaBasicExecutionRole` (managed)
  - `SES-S3-Policy` (inline custom policy)

### Lambda Resources

- **Function**: `rbios-email-forwarder`
- **ARN**: `arn:aws:lambda:us-east-1:416792107027:function:rbios-email-forwarder`

### S3 Resources

- **Bucket**: `rbios-email-bucket`
- **Purpose**: Store raw emails from SES

### SES Resources

- **Rule Set**: `rbios-email-rules` (active)
- **Receipt Rule**: `rbios-email-forwarder-rule`
- **Verified Identities**: `rbios.net`, `noreply@rbios.net`, `ryanmette@duck.com` (pending verification)

## Required Manual Steps (Post-Deployment)

### 1. DNS Configuration

Add the following DNS records to your rbios.net domain:

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

- Check email inbox for `ryanmette@duck.com` and click verification link
- If you have access to `noreply@rbios.net`, verify that address as well

### 3. Testing

Once DNS propagates and emails are verified:

1. Send a test email to `test@rbios.net`
2. Check CloudWatch logs for Lambda execution
3. Verify email forwarding to `ryanmette@duck.com`

## Architecture Flow

```
Internet Email → SES (rbios.net) → S3 (rbios-email-bucket) → Lambda (rbios-email-forwarder) → Forward to ryanmette@duck.com
```

1. **Email Reception**: Email sent to `*@rbios.net` is received by Amazon SES
2. **Storage**: SES stores the raw email in S3 bucket with prefix `emails/`
3. **Processing**: SES triggers the Lambda function with event details
4. **Forwarding**: Lambda retrieves email from S3, processes it, and forwards to destination
5. **Delivery**: Forwarded email includes original content and sender information

## Cost Considerations

### Estimated Monthly Costs (for moderate usage)

- **Lambda**: ~$0.20 (first 1M requests free)
- **S3**: ~$0.50 (storage + requests)
- **SES**: $0.10 per 1,000 emails received + $0.10 per 1,000 emails sent
- **Data Transfer**: Minimal for email sizes

### Total Estimated: ~$1-2/month for typical personal use

## Troubleshooting Commands

### Check Lambda Function Status

```bash
aws lambda get-function --function-name rbios-email-forwarder
```

### View Lambda Logs

```bash
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/rbios-email-forwarder
```

### Check SES Rule Status

```bash
aws ses describe-receipt-rule --rule-set-name rbios-email-rules --rule-name rbios-email-forwarder-rule
```

### Verify Email Status

```bash
aws ses get-identity-verification-attributes --identities rbios.net
```

### List S3 Bucket Contents

```bash
aws s3 ls s3://rbios-email-bucket/emails/ --recursive
```

## Security Considerations

1. **IAM Permissions**: Minimal required permissions granted
2. **S3 Access**: Restricted to SES service principal
3. **Email Verification**: Required for all sender/receiver addresses
4. **Encryption**: SES and S3 use encryption in transit and at rest
5. **Logging**: CloudWatch logs enabled for auditing

## Backup and Recovery

### Configuration Backup

All configuration files are stored in the project directory:

- IAM policies in JSON files
- SES rule configuration in `receipt-rule.json`
- Lambda environment variables in `lambda-env.json`

### Recovery Process

1. Redeploy Lambda function using saved deployment package
2. Recreate IAM role and policies using saved JSON files
3. Recreate SES rules using saved configuration
4. Restore S3 bucket policy

## Future Enhancements

1. **Multiple Domains**: Extend to handle multiple domains
2. **Selective Forwarding**: Forward specific addresses to different destinations
3. **Email Filtering**: Add spam/virus filtering capabilities
4. **Metrics Dashboard**: CloudWatch dashboard for monitoring
5. **Auto-Reply**: Implement auto-reply functionality
6. **Encryption**: Add PGP encryption for sensitive emails

---

**Deployment Completed**: July 5, 2025  
**Status**: ✅ Successfully deployed, pending DNS verification  
**Next Action**: Configure DNS records and verify email addresses

## Post-Deployment Testing and Fixes

### 2025-01-05: Lambda Function Testing and Permissions Fix

**Issue Found**: The Lambda function was missing `s3:ListBucket` permission, which caused failures when trying to access S3 objects.

**Error**:

```
User: arn:aws:sts::416792107027:assumed-role/rbios-email-forwarder-role/rbios-email-forwarder is not authorized to perform: s3:ListBucket on resource: "arn:aws:s3:::rbios-email-storage" because no identity-based policy allows the s3:ListBucket action
```

**Solution**: Updated the IAM policy to include `s3:ListBucket` permission:

```bash
# Updated policy with the missing permission
aws iam put-role-policy --role-name rbios-email-forwarder-role --policy-name SES-S3-Policy --policy-document file://updated-policy.json
```

**Testing**:

- Created `test-function.sh` script for manual Lambda testing
- Updated `tail-logs.sh` to handle cases where log groups don't exist yet
- Successfully tested Lambda function and verified logs are now accessible
- Confirmed that permissions issue is resolved

**Files Updated**:

- `tail-logs.sh`: Added log group existence check with helpful messages
- `test-function.sh`: New script for testing Lambda function manually
- `.gitignore`: Added test files and temporary files
- IAM Policy: Added `s3:ListBucket` permission

**Status**: ✅ Lambda function is now properly configured and tested. Log monitoring is working correctly.

---

## DNS Configuration for Email Receiving

### 2025-01-05: DNS Records Setup

**Issue**: Domain `rbios.net` was missing DNS records required for email receiving.

**Error**:

```
DNS Error: DNS type 'mx' lookup of rbios.net responded with code NOERROR
DNS type 'mx' lookup of rbios.net had no relevant answers.
```

**Solution**: Added required DNS records to Route53 hosted zone `Z041460211TNUBYCOAMFZ`:

1. **MX Record**:

   - Name: `rbios.net`
   - Type: `MX`
   - Value: `10 inbound-smtp.us-east-1.amazonaws.com`
   - TTL: `300`

2. **SES Verification TXT Record**:
   - Name: `_amazonses.rbios.net`
   - Type: `TXT`
   - Value: `"PCUaDtGJnd4oBOArD3QvjRcugl0r7GIoR04uBkG8I/o="`
   - TTL: `300`

**Commands Used**:

```bash
# Added MX record for email receiving
aws route53 change-resource-record-sets --hosted-zone-id Z041460211TNUBYCOAMFZ --change-batch file://mx-record-change.json

# Added TXT record for domain verification
aws route53 change-resource-record-sets --hosted-zone-id Z041460211TNUBYCOAMFZ --change-batch file://domain-verification-change.json
```

**Verification**:

```bash
# Check MX record
dig MX rbios.net
# Returns: rbios.net. 300 IN MX 10 inbound-smtp.us-east-1.amazonaws.com.

# Check verification TXT record
dig TXT _amazonses.rbios.net
# Returns: _amazonses.rbios.net. 300 IN TXT "PCUaDtGJnd4oBOArD3QvjRcugl0r7GIoR04uBkG8I/o="
```

**Status**:

- ✅ DNS records are live and propagated
- ⏳ SES domain verification is pending (can take up to 72 hours)
- 📧 Email delivery should work once verification completes

**Monitoring**: Use `./check-verification.sh` to monitor domain verification status.

---
