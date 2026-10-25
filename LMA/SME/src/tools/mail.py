import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.base import MIMEBase
from email import encoders
import os


def send_email(recipient: str, subject: str, body: str, attachments: list[str] = None) -> str:
    """
    Send an email using Gmail SMTP with optional attachments.
    :param recipient: Receiver's email
    :param subject: Email subject
    :param body: Email body text
    :param attachments: List of file paths to attach
    """
    sender_email = os.environ.get("GMAIL_USER")
    app_password = os.environ.get("GMAIL_APP_PASSWORD")

    if not sender_email or not app_password:
        return "❌ Missing GMAIL_USER or GMAIL_APP_PASSWORD in environment."

    try:
        msg = MIMEMultipart()
        msg["From"] = sender_email
        msg["To"] = recipient
        msg["Subject"] = subject

        # Add body text
        msg.attach(MIMEText(body, "plain"))

        # Attach files
        if attachments:
            for file_path in attachments:
                if not os.path.isfile(file_path):
                    return f"❌ Attachment not found: {file_path}"

                filename = os.path.basename(file_path)

                with open(file_path, "rb") as f:
                    part = MIMEBase("application", "octet-stream")
                    part.set_payload(f.read())

                encoders.encode_base64(part)
                part.add_header(
                    "Content-Disposition",
                    f"attachment; filename= {filename}",
                )

                msg.attach(part)

        # Send email
        with smtplib.SMTP("smtp.gmail.com", 587) as server:
            server.starttls()
            server.login(sender_email, app_password)
            server.send_message(msg)

        return f"📨 Email (with attachments) sent successfully to {recipient}!"

    except Exception as e:
        return f"❌ Failed to send email: {e}"

# print(send_email(
#     recipient="sdivyar11@gmail.com",
#     subject="Here are your files",
#     body="Please check the attached documents.",
#     attachments=["outputs/p.md", "exp.txt"]
# ))
