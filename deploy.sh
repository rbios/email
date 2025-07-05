#!/bin/bash

# Deploy Lambda function for rbios.net email forwarding

FUNCTION_NAME="rbios-email-forwarder"
ROLE_NAME="rbios-email-forwarder-role"

# Load config
if [ -f config.json ]; then
    FORWARD_TO_EMAIL=$(jq -r '.forwardTo' config.json)
    FROM_EMAIL=$(jq -r '.fromEmail' config.json)
else
    echo "config.json not found! Please create it first."
    exit 1
fi

echo "Deploying Lambda function: $FUNCTION_NAME"

# Create deployment package
echo "Creating deployment package..."
rm -f lambda-deployment.zip
zip -r lambda-deployment.zip lambda_function.py

# Get the role ARN
ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

if [ -z "$ROLE_ARN" ]; then
    echo "Role $ROLE_NAME not found. Please run setup.sh first."
    exit 1
fi

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME >/dev/null 2>&1; then
    echo "Function exists, updating..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://lambda-deployment.zip
        
    aws lambda update-function-configuration \
        --function-name $FUNCTION_NAME \
        --environment Variables="{FORWARD_TO_EMAIL=$FORWARD_TO_EMAIL,FROM_EMAIL=$FROM_EMAIL,DOMAIN=rbios.net}"
else
    echo "Creating new function..."
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime python3.9 \
        --role $ROLE_ARN \
        --handler lambda_function.lambda_handler \
        --zip-file fileb://lambda-deployment.zip \
        --timeout 30 \
        --memory-size 128 \
        --environment Variables="{FORWARD_TO_EMAIL=$FORWARD_TO_EMAIL,FROM_EMAIL=$FROM_EMAIL,DOMAIN=rbios.net}"
fi

# Give SES permission to invoke the function
echo "Setting up SES permissions..."
aws lambda add-permission \
    --function-name $FUNCTION_NAME \
    --statement-id ses-invoke \
    --action lambda:InvokeFunction \
    --principal ses.amazonaws.com \
    --source-account $(aws sts get-caller-identity --query Account --output text) \
    2>/dev/null || echo "Permission already exists"

echo "Deployment complete!"
echo "Function ARN: $(aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.FunctionArn' --output text)"
echo ""
echo "Next steps:"
echo "1. Set up SES domain verification for rbios.net"
echo "2. Create SES receipt rule to trigger this function"
echo "3. Test by sending email to contact@rbios.net"

# Clean up
rm -f lambda-deployment.zip
