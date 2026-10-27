import hashlib
import hmac
import logging
import secrets
import threading
from datetime import date, datetime, timedelta, timezone

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from . import config
from .models import Card, FaceScan, Student, utcnow
from .schemas import CardOut, StudentOut

logger = logging.getLogger(__name__)

register_lock = threading.Lock()


def _utc_today() -> date:
    return datetime.now(timezone.utc).date()


def _add_years(d: date, years: int) -> date:
    try:
        return d.replace(year=d.year + years)
    except ValueError:  # 29 February
        return d.replace(year=d.year + years, day=28)


def card_signature(card_number: str, student_code: str, valid_until: date) -> str:
    payload = f"{card_number}|{student_code}|{valid_until.isoformat()}".encode()
    digest = hmac.new(
        config.CARD_SIGNING_SECRET.encode(),
        payload,
        hashlib.sha256,
    ).hexdigest()
    return digest[:24]


def generate_student_code(db: Session) -> str:
    for _ in range(32):
        code = f"{config.STUDENT_CODE_PREFIX}-{secrets.randbelow(900_000) + 100_000}"
        if db.scalar(select(Student.id).where(Student.student_code == code)) is None:
            return code
    raise RuntimeError("Talaba kodini yaratib bo'lmadi")


def issue_card(db: Session, student: Student) -> Card:
    today = _utc_today()
    card = Card(
        student=student,
        organization=config.CARD_ORGANIZATION,
        access=config.CARD_ACCESS,
        issue_date=today,
        valid_until=_add_years(today, 1),
    )
    db.add(card)
    db.flush()
    card.card_number = f"{config.CARD_PREFIX}-{today.year}-{card.id:04d}"
    return card


def student_out(student: Student) -> StudentOut:
    card = student.card
    if card is None or card.card_number is None:
        raise ValueError("Talabada karta yo'q")
    return StudentOut(
        id=student.id,
        student_code=student.student_code,
        full_name=student.full_name,
        age=student.age,
        faculty=student.faculty,
        phone=student.phone,
        photo_url=f"/api/students/{student.id}/photo",
        created_at=student.created_at,
        card=CardOut(
            card_number=card.card_number,
            organization=card.organization,
            access=card.access,
            issue_date=card.issue_date,
            valid_until=card.valid_until,
            sig=card_signature(card.card_number, student.student_code, card.valid_until),
        ),
    )


def phone_taken(db: Session, phone: str) -> bool:
    return db.scalar(select(Student.id).where(Student.phone == phone)) is not None


def count_students_with_card(db: Session) -> int:
    return int(
        db.scalar(
            select(func.count())
            .select_from(Student)
            .join(Card, Card.student_id == Student.id)
        )
        or 0
    )


def purge_old_scans(db: Session) -> int:
    """Delete expired pending scans and old matched scan photos."""
    now = utcnow()
    pending_cutoff = now - timedelta(minutes=config.PENDING_SCAN_TTL_MINUTES)
    deleted = 0

    pending = db.execute(
        delete(FaceScan).where(
            FaceScan.student_id.is_(None),
            FaceScan.created_at < pending_cutoff,
        )
    )
    deleted += pending.rowcount or 0

    if config.MATCHED_SCAN_RETENTION_DAYS > 0:
        matched_cutoff = now - timedelta(days=config.MATCHED_SCAN_RETENTION_DAYS)
        matched = db.execute(
            delete(FaceScan).where(
                FaceScan.student_id.is_not(None),
                FaceScan.created_at < matched_cutoff,
            )
        )
        deleted += matched.rowcount or 0

    if deleted:
        db.commit()
        logger.info("Purged %s old face_scans", deleted)
    return deleted
