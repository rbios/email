import boto3
import json
import os
import re
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.base import MIMEBase
from email import encoders
import logging

# Set up logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    """
    Lambda function to forward emails received via SES
    """

    # Configuration - Set these as environment variables
    # Catch-all forwarding: forward ALL @rbios.net emails to one address
    FORWARD_TO_EMAIL = os.environ.get("FORWARD_TO_EMAIL", "ryanmette@duck.com")
    DOMAIN = os.environ.get("DOMAIN", "rbios.net")

    FROM_EMAIL = os.environ.get("FROM_EMAIL", "noreply@rbios.net")

    # Initialize SES client
    ses = boto3.client("ses", region_name="us-east-1")
    s3 = boto3.client("s3")

    try:
        # Parse the SES event
        logger.info(f"Received event: {json.dumps(event)}")

        for record in event["Records"]:
            # Get mail object from SES
            mail = record["ses"]["mail"]
            receipt = record["ses"]["receipt"]

            # Extract email details
            message_id = mail["messageId"]
            source = mail["commonHeaders"]["from"][0]
            subject = mail["commonHeaders"]["subject"]
            recipients = mail["commonHeaders"]["to"]

            logger.info(
                f"Processing email - From: {source}, To: {recipients}, Subject: {subject}"
            )

            # Get the raw email from S3 (SES stores it there)
            bucket = receipt["action"]["bucketName"]
            key = receipt["action"]["objectKey"]

            # Download the email from S3
            response = s3.get_object(Bucket=bucket, Key=key)
            raw_email = response["Body"].read()

            # Forward ALL @rbios.net emails (catch-all)
            for recipient in recipients:
                # Check if recipient is for our domain
                if recipient.lower().endswith(f"@{DOMAIN.lower()}"):
                    # Create forwarded message
                    msg = MIMEMultipart()
                    msg["From"] = FROM_EMAIL
                    msg["To"] = FORWARD_TO_EMAIL
                    msg["Subject"] = f"[{recipient}] {subject}"
                    msg["Reply-To"] = source

                    # Create body with original sender info
                    body = f"--- Forwarded Message ---\n"
                    body += f"From: {source}\n"
                    body += f"To: {recipient}\n"
                    body += f"Subject: {subject}\n"
                    body += f"Date: {mail['commonHeaders']['date']}\n\n"

                    # Add original message (you might want to parse this better)
                    body += "Original message attached as raw email.\n"

                    msg.attach(MIMEText(body, "plain"))

                    # Attach the original email
                    attachment = MIMEBase("message", "rfc822")
                    attachment.set_payload(raw_email)
                    encoders.encode_base64(attachment)
                    attachment.add_header(
                        "Content-Disposition",
                        'attachment; filename="original-email.eml"',
                    )
                    msg.attach(attachment)

                    # Send the forwarded email
                    try:
                        response = ses.send_raw_email(
                            Source=FROM_EMAIL,
                            Destinations=[FORWARD_TO_EMAIL],
                            RawMessage={"Data": msg.as_string()},
                        )
                        logger.info(
                            f"Email forwarded successfully from {recipient} to {FORWARD_TO_EMAIL}. MessageId: {response['MessageId']}"
                        )
                    except Exception as e:
                        logger.error(
                            f"Error forwarding email from {recipient}: {str(e)}"
                        )

                else:
                    logger.warning(
                        f"Email received for non-{DOMAIN} address: {recipient}"
                    )

        return {
            "statusCode": 200,
            "body": json.dumps("Email(s) processed successfully"),
        }

    except Exception as e:
        logger.error(f"Error processing email: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error processing email: {str(e)}"),
        }


# Simple version without S3 storage (for basic forwarding)
def simple_lambda_handler(event, context):
    """
    Simplified version that just forwards notification without original email content
    """

    FORWARD_TO_EMAIL = os.environ.get("FORWARD_TO_EMAIL", "your-email@gmail.com")
    FROM_EMAIL = os.environ.get("FROM_EMAIL", "noreply@rbios.net")
    DOMAIN = os.environ.get("DOMAIN", "rbios.net")

    ses = boto3.client("ses", region_name="us-east-1")

    try:
        for record in event["Records"]:
            mail = record["ses"]["mail"]

            # Extract details
            source = mail["commonHeaders"]["from"][0]
            subject = mail["commonHeaders"]["subject"]
            recipients = mail["commonHeaders"]["to"]

            # Create notification email
            msg = MIMEMultipart()
            msg["From"] = FROM_EMAIL
            msg["To"] = FORWARD_TO_EMAIL
            msg["Subject"] = f"[rbios.net] New email: {subject}"

            body = f"You received a new email at rbios.net\n\n"
            body += f"From: {source}\n"
            body += f"To: {', '.join(recipients)}\n"
            body += f"Subject: {subject}\n"
            body += f"Date: {mail['commonHeaders']['date']}\n\n"
            body += f"Reply directly to this email to respond to the sender.\n"

            msg.attach(MIMEText(body, "plain"))

            # Send notification
            response = ses.send_raw_email(
                Source=FROM_EMAIL,
                Destinations=[FORWARD_TO_EMAIL],
                RawMessage={"Data": msg.as_string()},
            )

            logger.info(f"Notification sent. MessageId: {response['MessageId']}")

        return {"statusCode": 200, "body": "Success"}

    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return {"statusCode": 500, "body": str(e)}
