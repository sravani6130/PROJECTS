import logging
import uuid
from datetime import datetime

# Create logger
logger = logging.getLogger("agent_logger")
logger.setLevel(logging.INFO)

# File handler
file_handler = logging.FileHandler("logs/agent.log")
file_handler.setLevel(logging.INFO)

# Log format
formatter = logging.Formatter(
    "[%(asctime)s] [%(levelname)s] [req=%(request_id)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)
file_handler.setFormatter(formatter)

# Add handler
logger.addHandler(file_handler)


# Helper: wrap logger to inject request_id
class RequestLoggerAdapter(logging.LoggerAdapter):
    def process(self, msg, kwargs):
        return msg, {"extra": {"request_id": self.extra["request_id"]}}


def get_request_logger():
    """Creates a logger adapter with a unique request ID."""
    request_id = str(uuid.uuid4())[:8]  # short uuid
    return RequestLoggerAdapter(logger, {"request_id": request_id})
