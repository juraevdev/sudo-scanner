import secrets

from fastapi import Header, HTTPException, status

from . import config


def require_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")) -> None:
    expected = config.API_KEY
    if not expected:
        raise HTTPException(
            status.HTTP_503_SERVICE_UNAVAILABLE,
            "API_KEY sozlanmagan",
        )
    if x_api_key is None or not secrets.compare_digest(x_api_key, expected):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "API kaliti noto'g'ri yoki yo'q")
