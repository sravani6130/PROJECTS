"""`python -m app` starts the API with settings from the environment / .env."""

import logging

import uvicorn

from .config import Settings
from .main import create_app


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
    settings = Settings.from_env()
    # access_log off: uvicorn's access log includes query strings; our own
    # middleware logs method, path and status only.
    uvicorn.run(create_app(settings), host=settings.host, port=settings.port, access_log=False)


if __name__ == "__main__":
    main()
