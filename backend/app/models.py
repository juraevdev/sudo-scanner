from datetime import date, datetime, timezone

from sqlalchemy import Date, DateTime, ForeignKey, Integer, LargeBinary, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .database import Base


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class Student(Base):
    __tablename__ = "students"

    id: Mapped[int] = mapped_column(primary_key=True)
    student_code: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    full_name: Mapped[str] = mapped_column(String(120))
    age: Mapped[int] = mapped_column(Integer)
    faculty: Mapped[str] = mapped_column(String(120))
    phone: Mapped[str] = mapped_column(String(20))
    face_embedding: Mapped[bytes] = mapped_column(LargeBinary)
    photo: Mapped[bytes] = mapped_column(LargeBinary)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)

    card: Mapped["Card | None"] = relationship(
        back_populates="student", cascade="all, delete-orphan", uselist=False
    )


class Card(Base):
    __tablename__ = "cards"
    # Card numbers are derived from the id, so ids must never be reused.
    __table_args__ = {"sqlite_autoincrement": True}

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    card_number: Mapped[str | None] = mapped_column(String(32), unique=True, index=True)
    student_id: Mapped[int] = mapped_column(
        ForeignKey("students.id", ondelete="CASCADE"), unique=True
    )
    organization: Mapped[str] = mapped_column(String(120))
    access: Mapped[str] = mapped_column(String(32))
    issue_date: Mapped[date] = mapped_column(Date)
    valid_until: Mapped[date] = mapped_column(Date)

    student: Mapped[Student] = relationship(back_populates="card")


class FaceScan(Base):
    """Every successfully detected face. Unknown faces wait here for registration."""

    __tablename__ = "face_scans"

    id: Mapped[int] = mapped_column(primary_key=True)
    token: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    embedding: Mapped[bytes] = mapped_column(LargeBinary)
    photo: Mapped[bytes] = mapped_column(LargeBinary)
    student_id: Mapped[int | None] = mapped_column(
        ForeignKey("students.id", ondelete="SET NULL"), nullable=True, index=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=utcnow)
