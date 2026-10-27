import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

DATABASE_URL = os.getenv("DATABASE_URL", f"sqlite:///{(BASE_DIR / 'scanner.db').as_posix()}")
MODELS_DIR = Path(os.getenv("MODELS_DIR", BASE_DIR / "models"))

# Cosine similarity between SFace embeddings; 0.363 is the threshold
# recommended by the model authors. Raise it to reduce false matches.
FACE_MATCH_THRESHOLD = float(os.getenv("FACE_MATCH_THRESHOLD", "0.363"))

CARD_ORGANIZATION = os.getenv("CARD_ORGANIZATION", "JizPi IT PARK")
CARD_ACCESS = os.getenv("CARD_ACCESS", "STUDENT")
CARD_PREFIX = os.getenv("CARD_PREFIX", "UZN")
STUDENT_CODE_PREFIX = os.getenv("STUDENT_CODE_PREFIX", "SA")

# How long an unknown face stays available for registration.
PENDING_SCAN_TTL_MINUTES = int(os.getenv("PENDING_SCAN_TTL_MINUTES", "30"))
# Matched face scans older than this (days) are purged. 0 disables.
MATCHED_SCAN_RETENTION_DAYS = int(os.getenv("MATCHED_SCAN_RETENTION_DAYS", "30"))

MAX_UPLOAD_BYTES = int(os.getenv("MAX_UPLOAD_BYTES", str(10 * 1024 * 1024)))
MAX_IMAGE_PIXELS = int(os.getenv("MAX_IMAGE_PIXELS", str(25_000_000)))
MAX_IMAGE_SIDE_BEFORE_DECODE = int(os.getenv("MAX_IMAGE_SIDE_BEFORE_DECODE", "4096"))

# Shared secret for app ↔ API. Override in production.
API_KEY = os.getenv("API_KEY", "dev-scanner-key")
# HMAC secret for QR authenticity (defaults to API_KEY).
CARD_SIGNING_SECRET = os.getenv("CARD_SIGNING_SECRET", API_KEY)

# Comma-separated origins. Empty = no CORS middleware (mobile app only).
CORS_ORIGINS = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]

# Scan rate limit per client IP.
SCAN_RATE_LIMIT_PER_MINUTE = int(os.getenv("SCAN_RATE_LIMIT_PER_MINUTE", "60"))

# Disable interactive docs in production: DOCS_ENABLED=0
DOCS_ENABLED = os.getenv("DOCS_ENABLED", "1").lower() not in {"0", "false", "no"}

EMBEDDING_DIM = 128
