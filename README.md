# UzNext Scanner

Talabalarni yuz orqali aniqlash va ularga e-karta berish tizimi.

- `backend/` — Python / FastAPI. Yuzni aniqlash va tanish OpenCV (YuNet + SFace) orqali.
  Ma'lumotlar SQLite bazada (`backend/scanner.db`), `DATABASE_URL` bilan PostgreSQL ham ishlaydi.
- `app/` — Flutter ilova. Karta dizayni `sudo_e-card` loyihasidan olingan.

## Ishlash tartibi

1. Ilova ochilganda yuz biometriyasi uchun rozilik so'raladi (bir marta).
2. Skanerlash oynasi ochiladi, kamera kadrlarni serverga yuboradi.
3. Yuz bazada bo'lmasa (ketma-ket 2 marta tasdiqlangach), pastdan ro'yxatdan o'tish oynasi chiqadi:
   ism-familiya, yosh, fakultet, telefon raqam.
4. Saqlanganda talaba bazaga yoziladi va unga takrorlanmaydigan karta raqami beriladi
   (`UZN-<yil>-<tartib raqam>`).
5. Yuz oldin ro'yxatdan o'tgan bo'lsa, talaba ma'lumotlari va kartasi ko'rsatiladi.

Har bir aniqlangan yuz `face_scans` jadvaliga (rasm + embedding) yoziladi; muddati o'tganlar avtomatik tozalanadi.

## Backend

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\pip install -r requirements.txt
# Ixtiyoriy: .env.example dan .env nusxa oling
.\.venv\Scripts\python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Model fayllari (`models/*.onnx`) birinchi ishga tushirishda yuklab olinadi va SHA-256 bilan tekshiriladi.
API hujjati: http://localhost:8000/docs (productionda `DOCS_ENABLED=0`).

Barcha himoyalangan endpointlar `X-API-Key` headerini talab qiladi (standart: `dev-scanner-key`).

| Endpoint | Vazifasi |
| --- | --- |
| `GET /api/health` | holat (auth yo'q) |
| `POST /api/scan` | rasm (`image`) → `matched` / `new` / `no_face` / … |
| `POST /api/students` | `scan_token` + ma'lumotlar bilan ro'yxat / karta |
| `GET /api/students?limit=&offset=` | talabalar ro'yxati (pagination) |
| `GET /api/students/{id}` | bitta talaba |
| `GET /api/students/{id}/photo` | yuz rasmi (API key bilan) |

Muhim sozlamalar: `API_KEY`, `CARD_SIGNING_SECRET`, `DATABASE_URL`, `FACE_MATCH_THRESHOLD`,
`CORS_ORIGINS`, `PENDING_SCAN_TTL_MINUTES`, `MATCHED_SCAN_RETENTION_DAYS`.
To'liq ro'yxat: `backend/.env.example`.

**Eslatma:** Productionda `API_KEY` ni almashtiring, HTTPS ishlating, `0.0.0.0` ni faqat ishonchli tarmoqda oching.

## Ilova

```powershell
cd app
flutter pub get
# Telefon va kompyuter bitta tarmoqda; IP — backend manzili
flutter run --dart-define=API_URL=http://192.168.1.10:8000 --dart-define=API_KEY=dev-scanner-key
```

`API_URL` berilmasa: Android emulyatorda `http://10.0.2.2:8000`, boshqa platformalarda `http://localhost:8000`.
`API_KEY` backenddagi kalit bilan bir xil bo'lishi shart.

- Debug build: LAN uchun HTTP (cleartext) ruxsat etiladi.
- Release build: HTTPS talab qilinadi. Imzo uchun `android/key.properties` yarating
  (`key.properties.example` ga qarang).
