#!/bin/bash

# Update environment variables for rbios-email-forwarder Lambda function

FUNCTION_NAME="rbios-email-forwarder"

echo "🔧 Updating environment variables for $FUNCTION_NAME"
echo ""

# Check if function exists
if ! aws lambda get-function --function-name $FUNCTION_NAME >/dev/null 2>&1; then
    echo "❌ Function $FUNCTION_NAME does not exist!"
    echo "Please run the initial deployment process first."
    exit 1
fi

# Check if lambda-env.json exists
if [ ! -f "lambda-env.json" ]; then
    echo "❌ lambda-env.json not found!"
    echo "Please create lambda-env.json with your environment variables."
    echo "Example format:"
    echo '{'
    echo '  "Variables": {'
    echo '    "FORWARD_TO_EMAIL": "your-email@example.com",'
    echo '    "DOMAIN": "rbios.net",'
    echo '    "FROM_EMAIL": "noreply@rbios.net"'
    echo '  }'
    echo '}'
    exit 1
fi

# Update environment variables
echo "📝 Updating environment variables from lambda-env.json..."
aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --environment file://lambda-env.json

if [ $? -eq 0 ]; then
    echo "✅ Environment variables updated successfully!"
    echo ""
    echo "📋 Current environment variables:"
    aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.Environment.Variables' --output table
else
    echo "❌ Failed to update environment variables"
    exit 1
fi
