import re
from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel, Field, field_validator


class CardOut(BaseModel):
    card_number: str
    organization: str
    access: str
    issue_date: date
    valid_until: date
    sig: str


class StudentOut(BaseModel):
    id: int
    student_code: str
    full_name: str
    age: int
    faculty: str
    phone: str
    photo_url: str
    created_at: datetime
    card: CardOut


class StudentListOut(BaseModel):
    items: list[StudentOut]
    total: int
    limit: int
    offset: int


class ScanResponse(BaseModel):
    status: Literal["matched", "new", "no_face", "multiple_faces", "too_far"]
    message: str
    scan_token: str | None = None
    similarity: float | None = None
    student: StudentOut | None = None


class RegisterIn(BaseModel):
    scan_token: str = Field(min_length=10, max_length=64)
    full_name: str
    age: int = Field(ge=14, le=100)
    faculty: str
    phone: str

    @field_validator("full_name")
    @classmethod
    def _full_name(cls, v: str) -> str:
        v = " ".join(v.split())
        if len(v) < 5 or len(v) > 120 or len(v.split(" ")) < 2:
            raise ValueError("Ism va familiyani to'liq kiriting")
        return v

    @field_validator("faculty")
    @classmethod
    def _faculty(cls, v: str) -> str:
        v = " ".join(v.split())
        if len(v) < 2 or len(v) > 120:
            raise ValueError("Fakultet nomini kiriting")
        return v

    @field_validator("phone")
    @classmethod
    def _phone(cls, v: str) -> str:
        digits = re.sub(r"\D", "", v)
        if len(digits) == 9:
            digits = "998" + digits
        if not re.fullmatch(r"998\d{9}", digits):
            raise ValueError("Telefon raqam +998 XX XXX XX XX ko'rinishida bo'lsin")
        return f"+998 {digits[3:5]} {digits[5:8]} {digits[8:10]} {digits[10:12]}"
