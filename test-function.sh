#!/bin/bash

# Test the rbios-email-forwarder Lambda function

FUNCTION_NAME="rbios-email-forwarder"

echo "🧪 Testing Lambda function: $FUNCTION_NAME"
echo ""

# Create a simple test payload
cat > test-payload.json << 'EOF'
{
  "Records": [
    {
      "eventSource": "aws:ses",
      "eventVersion": "1.0",
      "ses": {
        "mail": {
          "messageId": "test-message-id",
          "source": "test@example.com",
          "destination": ["test@rbios.net"],
          "commonHeaders": {
            "subject": "Test Email",
            "from": ["test@example.com"],
            "to": ["test@rbios.net"]
          }
        },
        "receipt": {
          "recipients": ["test@rbios.net"],
          "action": {
            "type": "S3",
            "bucketName": "rbios-email-storage",
            "objectKey": "test-email-object"
          }
        }
      }
    }
  ]
}
EOF

echo "📤 Invoking Lambda function with test payload..."
aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file://test-payload.json \
    --cli-binary-format raw-in-base64-out \
    response.json

echo ""
echo "📋 Response:"
cat response.json
echo ""

echo ""
echo "🧹 Cleaning up test files..."
rm -f test-payload.json response.json

echo ""
echo "✅ Test complete. You can now use ./tail-logs.sh to monitor logs."
