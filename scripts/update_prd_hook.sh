#!/usr/bin/env bash
# scripts/update_prd_hook.sh
# Claude Code Stop 훅 — 코드/설정 변경 시 PRD 자동 업데이트
# 의존: bash, curl, jq (winget install jqlang.jq)

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TIMESTAMP_FILE="$PROJECT_ROOT/scripts/.last_prd_sync"
LOG_FILE="$PROJECT_ROOT/scripts/prd_update.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

# .env에서 UPSTAGE_API_KEY 로드
if [ -f "$PROJECT_ROOT/.env" ]; then
    UPSTAGE_API_KEY=$(grep '^UPSTAGE_API_KEY=' "$PROJECT_ROOT/.env" | cut -d'=' -f2-)
fi

# jq 설치 확인
if ! command -v jq &>/dev/null; then
    log "jq 미설치 — 건너뜀 (설치: winget install jqlang.jq)"
    exit 0
fi

# API 키 확인
if [ -z "$UPSTAGE_API_KEY" ]; then
    log "UPSTAGE_API_KEY 없음 — 건너뜀"
    exit 0
fi

# timestamp 파일 없으면 에포크 시각으로 초기화
[ -f "$TIMESTAMP_FILE" ] || touch -t 197001010000 "$TIMESTAMP_FILE"

# 변경 파일 감지
# 감시: backend/*.py, frontend/*.jsx|js|ts|tsx, requirements.txt
# 제외: __pycache__, node_modules, venv, backend/data
CHANGED=$(find \
    "$PROJECT_ROOT/backend" "$PROJECT_ROOT/frontend" \
    \( -name "*.py" -o -name "*.jsx" -o -name "*.js" \
       -o -name "*.ts"  -o -name "*.tsx" -o -name "requirements.txt" \) \
    -newer "$TIMESTAMP_FILE" \
    ! -path "*/__pycache__/*" \
    ! -path "*/node_modules/*" \
    ! -path "*/venv/*" \
    ! -path "*/backend/data/*" \
    2>/dev/null)

# 변경 없으면 timestamp만 갱신 후 종료
if [ -z "$CHANGED" ]; then
    touch "$TIMESTAMP_FILE"
    exit 0
fi

CHANGED_COUNT=$(echo "$CHANGED" | wc -l | tr -d ' ')
log "변경 감지: ${CHANGED_COUNT}개 파일 — PRD 업데이트 시작"

# PRD 파일 확인
PRD_FILE=$(ls "$PROJECT_ROOT"/PRD_*.md 2>/dev/null | head -1)
if [ -z "$PRD_FILE" ]; then
    log "PRD 파일 없음 — 건너뜀"
    touch "$TIMESTAMP_FILE"
    exit 0
fi

# PRD 백업
cp "$PRD_FILE" "${PRD_FILE}.bak"

# ── 임시 파일 준비 ───────────────────────────────────────────
TMP_USER=$(mktemp)
TMP_SYS=$(mktemp)
TMP_PAYLOAD=$(mktemp)
TMP_RESPONSE=$(mktemp)

cleanup() { rm -f "$TMP_USER" "$TMP_SYS" "$TMP_PAYLOAD" "$TMP_RESPONSE"; }
trap cleanup EXIT

# ── 사용자 메시지 구성 ────────────────────────────────────────
{
    echo "## 오늘 날짜: $(date '+%Y-%m-%d')"
    echo ""
    echo "## 변경된 파일 목록 및 내용"
    for f in $CHANGED; do
        echo "### $f"
        head -150 "$f" 2>/dev/null
        echo "---"
    done
    echo ""
    echo "## 현재 PRD 전체"
    cat "$PRD_FILE"
} > "$TMP_USER"

# ── 시스템 프롬프트 ───────────────────────────────────────────
cat > "$TMP_SYS" << 'SYSEOF'
당신은 소프트웨어 PRD(제품 요구사항 문서) 관리자입니다.
코드 변경사항을 분석하여 PRD 문서 전체를 업데이트하세요.
규칙:
1. 변경되지 않은 섹션은 절대 수정하지 마세요.
2. 영향받은 Phase/섹션의 완료 상태([x] 체크), 버전, 날짜만 갱신하세요.
3. 새로 생성된 파일·기능은 해당 Phase 작업 목록에 반영하세요.
4. 반드시 전체 PRD 마크다운 문서만 반환하고 다른 설명이나 코드 블록 감싸기 없이 반환하세요.
SYSEOF

# ── jq로 JSON 페이로드 빌드 ───────────────────────────────────
# --rawfile: 파일 내용을 JSON 문자열로 안전하게 인코딩 (개행·따옴표 자동 이스케이프)
jq -n \
    --rawfile sys "$TMP_SYS" \
    --rawfile usr "$TMP_USER" \
    '{
        model: "solar-pro",
        messages: [
            {role: "system", content: $sys},
            {role: "user",   content: $usr}
        ],
        max_tokens: 8192,
        temperature: 0.3
    }' > "$TMP_PAYLOAD"

# ── curl로 Upstage API 호출 ───────────────────────────────────
HTTP_CODE=$(curl -s \
    -o "$TMP_RESPONSE" \
    -w "%{http_code}" \
    -X POST "https://api.upstage.ai/v1/chat/completions" \
    -H "Authorization: Bearer $UPSTAGE_API_KEY" \
    -H "Content-Type: application/json" \
    --max-time 90 \
    -d @"$TMP_PAYLOAD")

if [ "$HTTP_CODE" != "200" ]; then
    log "API 오류 (HTTP $HTTP_CODE) — PRD 원본 유지"
    cp "${PRD_FILE}.bak" "$PRD_FILE"
    touch "$TIMESTAMP_FILE"
    exit 0
fi

# ── jq로 응답 파싱 ────────────────────────────────────────────
UPDATED_PRD=$(jq -r '.choices[0].message.content // empty' "$TMP_RESPONSE" 2>/dev/null)

if [ -z "$UPDATED_PRD" ]; then
    log "응답 파싱 실패 — PRD 원본 유지"
    cp "${PRD_FILE}.bak" "$PRD_FILE"
else
    printf '%s\n' "$UPDATED_PRD" > "$PRD_FILE"
    log "PRD 업데이트 완료 ✓ (백업: ${PRD_FILE}.bak)"
fi

touch "$TIMESTAMP_FILE"
exit 0   # 항상 0 반환 — Claude Code 동작 차단 방지
