#!/bin/bash

# Monitor SES domain verification status

DOMAIN="rbios.net"

echo "🔍 Monitoring SES domain verification for: $DOMAIN"
echo "📋 This may take a few minutes..."
echo ""

for i in {1..20}; do
    status=$(aws ses get-identity-verification-attributes --identities $DOMAIN --query "VerificationAttributes.\"$DOMAIN\".VerificationStatus" --output text)
    
    echo "Attempt $i: Status = $status"
    
    if [ "$status" = "Success" ]; then
        echo ""
        echo "✅ Domain verification complete!"
        echo "📧 You can now receive emails at $DOMAIN"
        break
    elif [ "$status" = "Failed" ]; then
        echo ""
        echo "❌ Domain verification failed!"
        echo "Please check your DNS records and try again."
        break
    else
        echo "   Waiting 30 seconds..."
        sleep 30
    fi
done

if [ "$status" != "Success" ] && [ "$status" != "Failed" ]; then
    echo ""
    echo "⏰ Verification still pending after 10 minutes."
    echo "💡 This is normal - verification can take up to 72 hours."
    echo "🔄 You can check manually with: aws ses get-identity-verification-attributes --identities $DOMAIN"
fi
