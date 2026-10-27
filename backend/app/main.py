import logging
import secrets
from contextlib import asynccontextmanager
from datetime import timedelta

from fastapi import Depends, FastAPI, File, HTTPException, Query, Request, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session, selectinload

from . import config
from .auth import require_api_key
from .database import Base, SessionLocal, engine, get_db
from .face import FaceEngine, InvalidImageError, best_match, embedding_from_bytes, embedding_to_bytes
from .models import FaceScan, Student, utcnow
from .rate_limit import check_scan_rate
from .schemas import RegisterIn, ScanResponse, StudentListOut, StudentOut
from .services import (
    count_students_with_card,
    generate_student_code,
    issue_card,
    phone_taken,
    purge_old_scans,
    register_lock,
    student_out,
)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SCAN_MESSAGES = {
    "no_face": "Yuz topilmadi. Kameraga to'g'ri qarang",
    "multiple_faces": "Kadrda faqat bitta yuz bo'lishi kerak",
    "too_far": "Kameraga yaqinroq keling",
    "matched": "Talaba topildi",
    "new": "Yangi yuz. Ro'yxatdan o'ting",
}

_ALLOWED_IMAGE_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "application/octet-stream",
    "",
    None,
}


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(engine)
    app.state.face_engine = FaceEngine(config.MODELS_DIR)
    db = SessionLocal()
    try:
        purge_old_scans(db)
    finally:
        db.close()
    yield


app = FastAPI(
    title="Sudo Scanner API",
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs" if config.DOCS_ENABLED else None,
    redoc_url="/redoc" if config.DOCS_ENABLED else None,
    openapi_url="/openapi.json" if config.DOCS_ENABLED else None,
)

if config.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=config.CORS_ORIGINS,
        allow_methods=["GET", "POST"],
        allow_headers=["*"],
    )


def get_face_engine(request: Request) -> FaceEngine:
    return request.app.state.face_engine


def _closest_student(db: Session, embedding) -> tuple[int, float] | None:
    candidates = [tuple(row) for row in db.execute(select(Student.id, Student.face_embedding))]
    match = best_match(embedding, candidates)
    if match is None or match[1] < config.FACE_MATCH_THRESHOLD:
        return None
    return match


def _load_student(db: Session, student_id: int) -> Student | None:
    return db.scalar(
        select(Student).options(selectinload(Student.card)).where(Student.id == student_id)
    )


def _maybe_purge(db: Session) -> None:
    # Lightweight opportunistic cleanup (~2% of scan requests).
    if secrets.randbelow(50) == 0:
        try:
            purge_old_scans(db)
        except Exception:
            logger.exception("face_scans cleanup failed")
            db.rollback()


@app.get("/api/health")
def health():
    from sqlalchemy import text

    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False
    return {
        "status": "ok" if db_ok else "degraded",
        "database": db_ok,
        "models_dir": str(config.MODELS_DIR),
    }


@app.post("/api/scan", response_model=ScanResponse, dependencies=[Depends(require_api_key)])
def scan_face(
    request: Request,
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    face_engine: FaceEngine = Depends(get_face_engine),
):
    check_scan_rate(request)
    _maybe_purge(db)

    content_type = (image.content_type or "").split(";")[0].strip().lower()
    if content_type not in _ALLOWED_IMAGE_TYPES:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Faqat rasm fayli qabul qilinadi")

    data = image.file.read(config.MAX_UPLOAD_BYTES + 1)
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Rasm yuborilmadi")
    if len(data) > config.MAX_UPLOAD_BYTES:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Rasm hajmi juda katta")

    try:
        analysis = face_engine.analyze(data)
    except InvalidImageError as exc:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

    if analysis.status != "ok":
        return ScanResponse(
            status=analysis.status,
            message=SCAN_MESSAGES.get(analysis.status, "Yuz topilmadi"),
        )

    scan = FaceScan(
        token=secrets.token_urlsafe(24),
        embedding=embedding_to_bytes(analysis.embedding),
        photo=analysis.photo_jpeg,
    )
    match = _closest_student(db, analysis.embedding)

    if match is None:
        db.add(scan)
        db.commit()
        return ScanResponse(status="new", message=SCAN_MESSAGES["new"], scan_token=scan.token)

    student = _load_student(db, match[0])
    if student is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Talaba topilmadi")
    if student.card is None:
        issue_card(db, student)
    scan.student_id = student.id
    db.add(scan)
    db.commit()
    return ScanResponse(
        status="matched",
        message=SCAN_MESSAGES["matched"],
        similarity=round(match[1], 4),
        student=student_out(student),
    )


@app.post(
    "/api/students",
    response_model=StudentOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_api_key)],
)
def register_student(payload: RegisterIn, db: Session = Depends(get_db)):
    with register_lock:
        scan = db.scalar(select(FaceScan).where(FaceScan.token == payload.scan_token))
        if scan is None or scan.student_id is not None:
            raise HTTPException(
                status.HTTP_404_NOT_FOUND,
                "Skaner ma'lumoti topilmadi, qayta skanerlang",
            )
        if utcnow() - scan.created_at > timedelta(minutes=config.PENDING_SCAN_TTL_MINUTES):
            raise HTTPException(status.HTTP_410_GONE, "Skaner muddati tugagan, qayta skanerlang")

        if phone_taken(db, payload.phone):
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu telefon raqam allaqachon band")

        try:
            embedding = embedding_from_bytes(scan.embedding)
        except InvalidImageError as exc:
            raise HTTPException(status.HTTP_400_BAD_REQUEST, str(exc)) from exc

        if _closest_student(db, embedding) is not None:
            raise HTTPException(status.HTTP_409_CONFLICT, "Bu yuz allaqachon ro'yxatdan o'tgan")

        student = Student(
            student_code=generate_student_code(db),
            full_name=payload.full_name,
            age=payload.age,
            faculty=payload.faculty,
            phone=payload.phone,
            face_embedding=scan.embedding,
            photo=scan.photo,
        )
        db.add(student)
        try:
            db.flush()
            scan.student_id = student.id
            issue_card(db, student)
            db.commit()
        except IntegrityError as exc:
            db.rollback()
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                "Ro'yxatdan o'tishda konflikt. Qayta urinib ko'ring",
            ) from exc

        student = _load_student(db, student.id)
        if student is None or student.card is None:
            raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Karta yaratilmadi")
        return student_out(student)


@app.get("/api/students", response_model=StudentListOut, dependencies=[Depends(require_api_key)])
def list_students(
    db: Session = Depends(get_db),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    total = count_students_with_card(db)
    students = db.scalars(
        select(Student)
        .options(selectinload(Student.card))
        .join(Student.card)
        .order_by(Student.id.desc())
        .limit(limit)
        .offset(offset)
    )
    return StudentListOut(
        items=[student_out(s) for s in students],
        total=total,
        limit=limit,
        offset=offset,
    )


@app.get(
    "/api/students/{student_id}",
    response_model=StudentOut,
    dependencies=[Depends(require_api_key)],
)
def get_student(student_id: int, db: Session = Depends(get_db)):
    student = _load_student(db, student_id)
    if student is None or student.card is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Talaba topilmadi")
    return student_out(student)


@app.get("/api/students/{student_id}/photo", dependencies=[Depends(require_api_key)])
def get_student_photo(student_id: int, db: Session = Depends(get_db)):
    student = _load_student(db, student_id)
    if student is None or student.card is None or not student.photo:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Rasm topilmadi")
    return Response(
        student.photo,
        media_type="image/jpeg",
        headers={"Cache-Control": "private, max-age=3600"},
    )
