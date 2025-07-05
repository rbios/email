#!/bin/bash

# Email forwarding setup script for rbios.net
# Run this after setting up SES domain verification

DOMAIN="rbios.net"
BUCKET_NAME="rbios-email-storage"
FUNCTION_NAME="rbios-email-forwarder"
FORWARD_TO_EMAIL="your-email@gmail.com"  # CHANGE THIS!

echo "Setting up email forwarding for $DOMAIN..."

# Create S3 bucket for email storage
echo "Creating S3 bucket..."
aws s3 mb s3://$BUCKET_NAME --region us-east-1

# Set bucket policy for SES
echo "Setting bucket policy..."
aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowSESPuts",
            "Effect": "Allow",
            "Principal": {
                "Service": "ses.amazonaws.com"
            },
            "Action": "s3:PutObject",
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
        }
    ]
}'

# Create Lambda execution role
echo "Creating Lambda execution role..."
aws iam create-role --role-name rbios-email-forwarder-role --assume-role-policy-document '{
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
}'

# Attach basic execution policy
aws iam attach-role-policy \
    --role-name rbios-email-forwarder-role \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create custom policy for SES and S3
aws iam create-policy --policy-name rbios-email-forwarder-policy --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject"
            ],
            "Resource": "arn:aws:s3:::'$BUCKET_NAME'/*"
        }
    ]
}'

# Attach custom policy
aws iam attach-role-policy \
    --role-name rbios-email-forwarder-role \
    --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):policy/rbios-email-forwarder-policy

echo "Setup complete!"
echo "Next steps:"
echo "1. Create Lambda function '$FUNCTION_NAME' with the provided Python code"
echo "2. Set environment variables: FORWARD_TO_EMAIL=$FORWARD_TO_EMAIL, FROM_EMAIL=noreply@$DOMAIN"
echo "3. Create SES receipt rule to trigger the Lambda function"
echo "4. Test by sending email to contact@$DOMAIN"
