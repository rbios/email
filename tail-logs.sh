#!/bin/bash

# Tail logs for rbios-email-forwarder Lambda function

FUNCTION_NAME="rbios-email-forwarder"
LOG_GROUP="/aws/lambda/$FUNCTION_NAME"

echo "📋 Tailing logs for Lambda function: $FUNCTION_NAME"
echo "📂 Log group: $LOG_GROUP"
echo ""

# Check if log group exists
if aws logs describe-log-groups --log-group-name-prefix "$LOG_GROUP" --query "logGroups[?logGroupName=='$LOG_GROUP']" --output text | grep -q "$LOG_GROUP"; then
    echo "✅ Log group exists. Starting to tail logs..."
    echo "Press Ctrl+C to stop following logs"
    echo "----------------------------------------"
    aws logs tail $LOG_GROUP --follow
else
    echo "⚠️  Log group doesn't exist yet. This is normal for a new Lambda function."
    echo ""
    echo "The log group will be created automatically when the Lambda function runs for the first time."
    echo ""
    echo "To trigger the function and create logs:"
    echo "1. Send an email to your domain (e.g., test@rbios.net)"
    echo "2. Or invoke the function manually with: aws lambda invoke --function-name $FUNCTION_NAME response.json"
    echo ""
    echo "After the function runs, you can use this script to monitor logs."
fi
