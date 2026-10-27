import threading
import time
from collections import defaultdict

from fastapi import HTTPException, Request, status

from . import config

_lock = threading.Lock()
_hits: dict[str, list[float]] = defaultdict(list)


def check_scan_rate(request: Request) -> None:
    limit = config.SCAN_RATE_LIMIT_PER_MINUTE
    if limit <= 0:
        return
    client = request.client.host if request.client else "unknown"
    now = time.monotonic()
    with _lock:
        window = [t for t in _hits[client] if now - t < 60.0]
        if len(window) >= limit:
            _hits[client] = window
            raise HTTPException(
                status.HTTP_429_TOO_MANY_REQUESTS,
                "Juda ko'p so'rov. Biroz kuting",
            )
        window.append(now)
        _hits[client] = window
