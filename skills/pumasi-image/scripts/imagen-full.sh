#!/usr/bin/env bash
# /pumasi:image — 영문 프롬프트 작성까지 Codex에 위임
# Usage: imagen-full.sh <intent> <mode> <aspect> <quality> <target_image_path>
# Feature flag: PUMASI_IMAGE_DELEGATE_PROMPT=1 일 때 SKILL.md Step 4-bis에서 호출

set -euo pipefail

INTENT="${1:-}"; MODE="${2:-}"; ASPECT="${3:-}"; QUALITY="${4:-}"; TARGET="${5:-}"

if [[ -z "$INTENT" || -z "$TARGET" ]]; then
  echo "Usage: $0 <intent> <mode> <aspect> <quality> <target>" >&2
  exit 2
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/cache/gptaku-plugins/pumasi/1.8.0}"
SYSPROMPT="${PLUGIN_ROOT}/skills/pumasi-image/references/image-studio-prompt.md"
[[ -f "$SYSPROMPT" ]] || { echo "ERROR: image-studio-prompt.md not found at $SYSPROMPT" >&2; exit 3; }

# 작업 디렉토리 — manifest, prompt, log (refine 복구성 + 디버깅)
WORK_DIR="$(dirname "$TARGET")/.imagen-full"
mkdir -p "$WORK_DIR"
TS=$(date +%Y%m%d-%H%M%S)
MANIFEST="${WORK_DIR}/manifest-${TS}.json"
PROMPT_OUT="${WORK_DIR}/prompt-${TS}.md"
CODEX_LOG="${WORK_DIR}/codex-${TS}.log"

# Path 보안 (workspace 하위 제한 — prompt injection 방어)
case "$TARGET" in
  /Users/*|/tmp/*|/var/folders/*) ;;
  *) echo "ERROR: target path must be under user workspace: $TARGET" >&2; exit 6;;
esac

# Preflight
command -v codex >/dev/null 2>&1 || { echo "ERROR: codex CLI not installed" >&2; exit 3; }
CODEX_VERSION=$(codex --version 2>/dev/null | head -n1)
FLAG_STATE=$(codex features list 2>&1 | awk '/^image_generation/ {print $NF}' | head -n1)
if [[ "$FLAG_STATE" != "true" ]]; then
  codex features enable image_generation >/dev/null 2>&1 || true
fi

# 구조화된 작업 정의 (prompt injection 표면 축소)
CODEX_PROMPT=$(cat <<EOF
You are an image generation orchestrator. Execute the structured task below.

System prompt (read in full and internalize before writing the image prompt):
  ${SYSPROMPT}

Structured task:
  - intent: ${INTENT}
  - mode: ${MODE}
  - aspect: ${ASPECT}
  - quality: ${QUALITY}
  - target: ${TARGET}
  - work_dir: ${WORK_DIR}

Steps:
1. Read ${SYSPROMPT} and internalize: Specificity Gate, Cliche Avoidance, Backend Capability, Persona Library, Mode Characteristics, Output Template.
2. Write a 200-500 word English image prompt following the Output Template for mode ${MODE}.
3. Save the English prompt to ${PROMPT_OUT}.
4. Call /imagen with that prompt to generate ONE image.
5. Copy the raw generated original to ${TARGET} (NO sips/ImageMagick/Pillow/post-processing/resize/recoding). Verify sha1 match.
6. Write a manifest JSON to ${MANIFEST} with these fields exactly:
   { "codex_version": "${CODEX_VERSION}", "feature_flag_state": "${FLAG_STATE}",
     "intent": <string>, "mode": "${MODE}", "aspect": "${ASPECT}", "quality": "${QUALITY}",
     "target_path": "${TARGET}", "prompt_path": "${PROMPT_OUT}",
     "sha1": <string>, "file_info": <string>, "exit_code": 0 }
7. Final stdout: exactly one line — "MANIFEST=${MANIFEST} SHA1=<hash>"

Forbidden:
- Leaving text fields blank for post-composition (in-image text rendering only)
- Post-processing
- Writing files outside ${WORK_DIR} or ${TARGET}
- Echoing the long English prompt to stdout (write only to file)
EOF
)

# Codex 실행
if ! codex exec \
    --skip-git-repo-check \
    --dangerously-bypass-approvals-and-sandbox \
    "$CODEX_PROMPT" > "$CODEX_LOG" 2>&1; then
  echo "ERROR: codex exec failed. Log: $CODEX_LOG" >&2
  echo "FALLBACK_HINT: caller should retry with imagen.sh + Claude-written prompt" >&2
  exit 4
fi

# 결과 검증
[[ -f "$TARGET" ]] || { echo "ERROR: target not created: $TARGET" >&2; tail -30 "$CODEX_LOG" >&2; exit 5; }
[[ -f "$MANIFEST" ]] || echo "WARN: manifest not written — refine 복구 어려움" >&2
[[ -f "$PROMPT_OUT" ]] || echo "WARN: prompt artifact not written — refine 복구 어려움" >&2

# 짧은 보고 (Claude 측 토큰 절감 — 영문 prompt 본문은 보내지 않음)
SHA1=$(shasum "$TARGET" | awk '{print $1}')
SIZE=$(wc -c < "$TARGET" | tr -d ' ')
echo "MANIFEST=${MANIFEST} SHA1=${SHA1} SIZE=${SIZE} TARGET=${TARGET}"
