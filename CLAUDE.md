# CLAUDE.md

이 파일은 이 저장소에서 작업할 때 Claude Code (claude.ai/code)에게 제공되는 가이드입니다.

## 프로젝트 개요

영수증 지출 관리 앱 — 사용자가 영수증 이미지/PDF를 업로드하면 Upstage Vision LLM이 LangChain을 통해 지출 데이터를 구조화하여 추출하고, 프론트엔드에서 필터링 및 관리 기능과 함께 지출 목록을 표시합니다.

## 명령어

### 백엔드

```bash
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
uvicorn backend.main:app --reload   # http://localhost:8000/docs
```

### 프론트엔드

```bash
cd frontend
npm install
npm run dev    # http://localhost:5173
npm run build
```

### 환경 설정

`.env.example`을 `.env`로 복사한 후 `UPSTAGE_API_KEY`를 설정합니다.

## 아키텍처

**기술 스택**: React 18 + Vite + TailwindCSS (프론트엔드) / Python FastAPI + LangChain + Upstage Vision LLM (백엔드) / JSON 파일 영속성.

**데이터 흐름**: 영수증 이미지 → FastAPI `/api/upload` → PIL/pdf2image → Base64 → LangChain 체인 → Upstage `document-digitization-vision` 모델 → 구조화된 JSON → `backend/data/expenses.json`.

**백엔드 구조**:
- `backend/main.py` — FastAPI 앱 진입점
- `backend/routers/` — `upload.py`, `expenses.py`, `summary.py`
- `backend/services/ocr_service.py` — LangChain + Upstage 연동
- `backend/services/storage_service.py` — expenses.json CRUD
- `backend/data/expenses.json` — 유일한 영속성 계층 (DB 없음)

**프론트엔드 구조**:
- `frontend/src/pages/` — `Dashboard.jsx`, `UploadPage.jsx`, `ExpenseDetail.jsx`
- `frontend/src/components/` — UI 컴포넌트 (DropZone, ParsePreview, ExpenseCard 등)
- `frontend/src/api/axios.js` — 백엔드 베이스 URL을 향하는 Axios 클라이언트

**API 명세**:
| 메서드 | 엔드포인트 | 용도 |
|--------|----------|---------|
| POST | `/api/upload` | 영수증 OCR 파싱 → 구조화된 JSON 반환 |
| GET | `/api/expenses` | 지출 목록 조회 (날짜 필터 선택사항) |
| PUT | `/api/expenses/{id}` | 지출 항목 수정 |
| DELETE | `/api/expenses/{id}` | UUID로 지출 항목 삭제 |
| GET | `/api/summary` | 집계 통계 (합계, 월별, 카테고리별) |

## 주요 제약사항

- **Upstage 모델**: `langchain-upstage`를 통한 `solar-vision-ocr` 또는 `document-digitization-vision` 사용. API 키는 `UPSTAGE_API_KEY`에 설정.
- **PDF 지원**: Upstage 전송 전 `pdf2image`로 변환 필요 (PATH에 Poppler 설치 필요).
- **DB 없음**: 모든 상태는 `backend/data/expenses.json`에 저장. 이 MVP에서는 동시 쓰기 안전성 불필요.
- **배포**: Vercel 서버리스 — 백엔드는 Mangum ASGI 어댑터 필요, 프론트엔드는 Vite 정적 빌드. 설정 파일은 `vercel.json`.
- **테스트 영수증**: 수동 OCR 테스트용 샘플 이미지와 PDF 1개가 `images/`에 있음.

### 답변은 반드시 한국어로 해줘.


### 나의 github 계정 이름은 jshkma 입니다.
### 나의 github 계정 이메일은 ssanghee@gmail.com 입니다.
