#!/bin/bash

# Test the email forwarding setup

DOMAIN="rbios.net"
FUNCTION_NAME="rbios-email-forwarder"

echo "Testing email forwarding setup for $DOMAIN..."

# Check SES domain verification
echo "Checking SES domain verification..."
aws ses get-identity-verification-attributes --identities $DOMAIN

# Check Lambda function
echo "Checking Lambda function..."
aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.{FunctionName:FunctionName,State:State,LastModified:LastModified}'

# Check S3 bucket
echo "Checking S3 bucket..."
aws s3 ls s3://rbios-email-storage/ 2>/dev/null || echo "Bucket not found or empty"

# Check IAM role
echo "Checking IAM role..."
aws iam get-role --role-name rbios-email-forwarder-role --query 'Role.RoleName'

# Check SES receipt rules
echo "Checking SES receipt rules..."
aws ses describe-active-receipt-rule-set

echo "Test complete!"
echo ""
echo "To test email forwarding:"
echo "1. Send email to contact@rbios.net"
echo "2. Check CloudWatch logs: aws logs tail /aws/lambda/rbios-email-forwarder --follow"
echo "3. Check your personal email for forwarded message"
