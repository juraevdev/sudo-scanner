import hashlib
import io
import logging
import threading
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Literal

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

from . import config

logger = logging.getLogger(__name__)

_MODEL_BASE = "https://github.com/opencv/opencv_zoo/raw/main/models"
DETECTOR_MODEL = "face_detection_yunet_2023mar.onnx"
RECOGNIZER_MODEL = "face_recognition_sface_2021dec.onnx"
_MODEL_URLS = {
    DETECTOR_MODEL: f"{_MODEL_BASE}/face_detection_yunet/{DETECTOR_MODEL}",
    RECOGNIZER_MODEL: f"{_MODEL_BASE}/face_recognition_sface/{RECOGNIZER_MODEL}",
}
# Official opencv_zoo hashes (sha256). Fail closed on mismatch.
_MODEL_SHA256 = {
    DETECTOR_MODEL: "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
    RECOGNIZER_MODEL: "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79",
}

MAX_IMAGE_SIDE = 960
MIN_FACE_RATIO = 0.15
SECOND_FACE_RATIO = 0.5
_DOWNLOAD_TIMEOUT_SEC = 120
_NORM_EPS = 1e-6

FaceStatus = Literal["ok", "no_face", "multiple_faces", "too_far"]

# Decompression bomb guard for Pillow.
Image.MAX_IMAGE_PIXELS = config.MAX_IMAGE_PIXELS


class InvalidImageError(ValueError):
    pass


@dataclass
class FaceAnalysis:
    status: FaceStatus
    embedding: np.ndarray | None = None
    photo_jpeg: bytes | None = None


def _sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def ensure_models(models_dir: Path) -> None:
    models_dir.mkdir(parents=True, exist_ok=True)
    for name, url in _MODEL_URLS.items():
        target = models_dir / name
        expected = _MODEL_SHA256[name]
        if target.exists() and target.stat().st_size > 0:
            digest = _sha256_file(target)
            if digest == expected:
                continue
            logger.warning("Model checksum mismatch for %s — re-downloading", name)
            target.unlink(missing_ok=True)

        logger.info("Downloading %s ...", name)
        tmp = target.with_suffix(".part")
        try:
            with urllib.request.urlopen(url, timeout=_DOWNLOAD_TIMEOUT_SEC) as resp:
                data = resp.read()
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            raise RuntimeError(f"Model yuklab bo'lmadi: {name}") from exc

        digest = hashlib.sha256(data).hexdigest()
        if digest != expected:
            raise RuntimeError(
                f"Model checksum noto'g'ri: {name} (got {digest}, expected {expected})"
            )
        tmp.write_bytes(data)
        tmp.replace(target)


def _decode(data: bytes) -> np.ndarray:
    try:
        image = Image.open(io.BytesIO(data))
        image.load()
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise InvalidImageError("Rasmni o'qib bo'lmadi") from exc

    width, height = image.size
    if width <= 0 or height <= 0:
        raise InvalidImageError("Rasm o'lchami noto'g'ri")
    if max(width, height) > config.MAX_IMAGE_SIDE_BEFORE_DECODE:
        raise InvalidImageError("Rasm o'lchami juda katta")
    if width * height > config.MAX_IMAGE_PIXELS:
        raise InvalidImageError("Rasm piksel soni juda katta")

    try:
        image = ImageOps.exif_transpose(image).convert("RGB")
    except (OSError, ValueError) as exc:
        raise InvalidImageError("Rasmni o'qib bo'lmadi") from exc

    image.thumbnail((MAX_IMAGE_SIDE, MAX_IMAGE_SIDE))
    return cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2BGR)


def _crop_photo(img: np.ndarray, face: np.ndarray, size: int = 320) -> bytes:
    h, w = img.shape[:2]
    x, y, fw, fh = face[:4]
    side = max(fw, fh) * 1.6
    cx, cy = x + fw / 2, y + fh / 2
    x0, y0 = int(max(cx - side / 2, 0)), int(max(cy - side / 2, 0))
    x1, y1 = int(min(cx + side / 2, w)), int(min(cy + side / 2, h))
    crop = cv2.resize(img[y0:y1, x0:x1], (size, size), interpolation=cv2.INTER_AREA)
    ok, buf = cv2.imencode(".jpg", crop, [cv2.IMWRITE_JPEG_QUALITY, 88])
    if not ok:
        raise InvalidImageError("Rasmni saqlab bo'lmadi")
    return buf.tobytes()


class FaceEngine:
    def __init__(self, models_dir: Path):
        ensure_models(models_dir)
        self._detector = cv2.FaceDetectorYN.create(
            str(models_dir / DETECTOR_MODEL), "", (320, 320), 0.85, 0.3, 50
        )
        self._recognizer = cv2.FaceRecognizerSF.create(str(models_dir / RECOGNIZER_MODEL), "")
        # OpenCV DNN networks are not safe to share between threads.
        self._lock = threading.Lock()

    def analyze(self, data: bytes) -> FaceAnalysis:
        img = _decode(data)
        h, w = img.shape[:2]

        with self._lock:
            self._detector.setInputSize((w, h))
            _, faces = self._detector.detect(img)
            if faces is None or len(faces) == 0:
                return FaceAnalysis("no_face")

            faces = sorted(faces, key=lambda f: f[2] * f[3], reverse=True)
            main = faces[0]
            if len(faces) > 1 and faces[1][2] * faces[1][3] >= main[2] * main[3] * SECOND_FACE_RATIO:
                return FaceAnalysis("multiple_faces")
            if main[2] < min(w, h) * MIN_FACE_RATIO:
                return FaceAnalysis("too_far")

            aligned = self._recognizer.alignCrop(img, main)
            feature = self._recognizer.feature(aligned).astype(np.float32).ravel()

        norm = float(np.linalg.norm(feature))
        if not np.isfinite(norm) or norm < _NORM_EPS:
            return FaceAnalysis("no_face")

        return FaceAnalysis(
            "ok",
            embedding=feature / norm,
            photo_jpeg=_crop_photo(img, main),
        )


def embedding_to_bytes(embedding: np.ndarray) -> bytes:
    return embedding.astype(np.float32).tobytes()


def embedding_from_bytes(data: bytes) -> np.ndarray:
    expected = config.EMBEDDING_DIM * 4
    if len(data) != expected:
        raise InvalidImageError("Yuz embedding formati noto'g'ri")
    vec = np.frombuffer(data, dtype=np.float32).copy()
    if vec.shape != (config.EMBEDDING_DIM,) or not np.isfinite(vec).all():
        raise InvalidImageError("Yuz embedding formati noto'g'ri")
    norm = float(np.linalg.norm(vec))
    if norm < _NORM_EPS:
        raise InvalidImageError("Yuz embedding formati noto'g'ri")
    return vec / norm


def best_match(
    embedding: np.ndarray, candidates: list[tuple[int, bytes]]
) -> tuple[int, float] | None:
    """Returns (candidate id, cosine similarity) of the closest stored face."""
    if not candidates:
        return None
    ids: list[int] = []
    rows: list[np.ndarray] = []
    for cid, blob in candidates:
        try:
            rows.append(embedding_from_bytes(blob))
            ids.append(cid)
        except InvalidImageError:
            logger.warning("Skipping corrupt embedding for student %s", cid)
    if not rows:
        return None
    matrix = np.stack(rows)
    scores = matrix @ embedding
    best = int(np.argmax(scores))
    return ids[best], float(scores[best])
