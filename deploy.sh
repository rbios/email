#!/bin/bash

# Deploy/Update Lambda function for rbios.net email forwarding

FUNCTION_NAME="rbios-email-forwarder"
ROLE_NAME="rbios-email-forwarder-role"
BUCKET_NAME="rbios-email-bucket"

echo "🚀 Deploying/Updating Lambda function: $FUNCTION_NAME"
echo ""

# Check if we have dependencies installed
if [ ! -d "package" ]; then
    echo "📦 Installing Python dependencies..."
    mkdir -p package
    pip install -r requirements.txt -t package/
fi

# Create deployment package
echo "📦 Creating deployment package..."
rm -f rbios-email-forwarder.zip

# Copy Lambda function to package directory
cp lambda_function.py package/

# Create zip file
cd package
zip -r ../rbios-email-forwarder.zip .
cd ..

echo "✅ Deployment package created: rbios-email-forwarder.zip"

# Check if function exists and update it
if aws lambda get-function --function-name $FUNCTION_NAME >/dev/null 2>&1; then
    echo "🔄 Function exists, updating code..."
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://rbios-email-forwarder.zip
    
    echo "✅ Lambda function code updated successfully!"
    
    # Optionally update environment variables (uncomment if needed)
    # echo "🔧 Updating environment variables..."
    # aws lambda update-function-configuration \
    #     --function-name $FUNCTION_NAME \
    #     --environment file://lambda-env.json
else
    echo "❌ Function $FUNCTION_NAME does not exist!"
    echo "Please run the initial deployment process first."
    echo "See DEPLOYMENT_LOG.md for complete setup instructions."
    exit 1
fi

# Display current function info
echo ""
echo "📋 Current Function Status:"
aws lambda get-function --function-name $FUNCTION_NAME --query 'Configuration.[FunctionName,LastModified,CodeSize,Environment.Variables]' --output table

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🔍 Next steps:"
echo "1. Test the function with a sample email"
echo "2. Check CloudWatch logs: aws logs tail /aws/lambda/rbios-email-forwarder --follow"
echo "3. Monitor S3 bucket: aws s3 ls s3://$BUCKET_NAME/emails/"

# Clean up
echo ""
echo "🧹 Cleaning up..."
rm -f rbios-email-forwarder.zip
rm -rf package/

echo "✅ Cleanup complete!"
