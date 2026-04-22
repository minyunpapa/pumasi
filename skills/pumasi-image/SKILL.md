---
name: pumasi-image
description: This skill should be used when the user asks to "이미지 만들어줘", "그림 생성해줘", "이미지 그려줘", "썸네일 만들어", "로고 만들어줘", "일러스트 그려줘", "포스터 만들어", "프로필 이미지", "배너 만들어", "아이콘 만들어", "표지 이미지", "image generate", "create image", "make thumbnail", "make logo", "make illustration", "draw image". Also trigger on casual expressions like "그림 하나 뽑아줘", "이미지 좀 만들어봐", "비주얼 만들어줘". DO NOT trigger on code-generation requests like "함수 만들어줘", "컴포넌트 만들어줘", "페이지 만들어줘" — those are for /pumasi (parallel coding), not this skill.
---

# /pumasi:image — Codex 이미지 생성

> Codex CLI의 `/imagen` 기능으로 이미지를 생성한다.
> 기존 `/pumasi`(코드 병렬 외주)와 완전히 분리된 독립 스킬.

---

## 핵심 원칙

1. **백엔드는 Codex CLI 단일** — nanobanana 등 다른 백엔드 사용 안 함
2. **image-studio 시스템 프롬프트 내면화** — 모드 분류 + Output Template 작성
3. **후처리 절대 금지** — sips/ImageMagick/재인코딩 금지, 원본 SHA1 유지
4. **저장 경로 고정** — `images/{YYYY-MM-DD}/{slug}-{seq}.png`
5. **최대 5개 질문** — 기술 2개 + 의도 3개, 조건부 스킵

---

## 워크플로우

### Step 0: feature flag 체크 및 자동 활성화

```bash
codex features list 2>&1 | grep image_generation
```

출력이 `image_generation ... false`면:

```bash
codex features enable image_generation
```

사용자에게는 이 단계를 조용히 수행한다고 간단히 알림 (상세 출력 노출 X).

### Step 1: 모드 자동 감지

사용자 요청에서 7가지 모드 중 하나를 결정한다:

| 모드 | 감지 키워드 |
|------|-----------|
| MODE_A_PORTRAIT | "프로필", "인물", "얼굴", "초상" |
| MODE_B_LANDSCAPE | "풍경", "배경", "자연", "도시", "바다", "산" |
| MODE_C_OBJECT | "제품", "물건", "아이템", "상품" |
| MODE_D_ILLUSTRATION | "일러스트", "그림", "아트", "드로잉" |
| MODE_E_THUMBNAIL | "썸네일", "커버", "대표이미지", "유튜브" |
| MODE_F_LOGO | "로고", "브랜드", "심볼", "아이콘" |
| MODE_G_CONCEPTUAL | "컨셉트", "추상", "아이디어", "상징" |

모드 판단 불확실 시 Step 2의 질문에 "모드 선택" 1개를 추가한다.

### Step 2: 키워드 자동 매핑 → 파라미터 추출

`${CLAUDE_PLUGIN_ROOT}/skills/pumasi-image/references/keyword-mapping.md`를 Read하여 비율·퀄리티 자연어 힌트를 추출한다.

- 비율 키워드가 입력에 있으면 → 비율 질문 스킵
- 퀄리티 키워드가 입력에 있으면 → 퀄리티 질문 스킵

### Step 3: AskUserQuestion (최대 5개)

`${CLAUDE_PLUGIN_ROOT}/skills/pumasi-image/references/clarification-matrix.md`를 Read하여 모드별 의도 파악 카테고리 3개를 확정한다.

**질문 순서**:
1. 비율 (Step 2에서 확정됐으면 스킵)
2. 퀄리티 (Step 2에서 확정됐으면 스킵)
3~5. 의도 파악 3개 (모드 매트릭스 기반)

**질문 원칙 (딸깍 방식)**:
- 각 질문당 5개 이상 선택지
- 그중 1~2개는 **예상 못한 창의적 대안**
- "자동 판단" 안전망 선택지 항상 포함
- 입력에서 이미 확정된 차원은 질문 스킵 → 다음 우선순위로 슬롯 채움

**AskUserQuestion 호출 규칙**:
- 모든 남은 질문을 **한 번의 호출에 `questions` 배열**로 묶어서 전달
- 텍스트로 질문하지 말 것

### Step 4: image-studio 내면화 + Output Template 작성

`${CLAUDE_PLUGIN_ROOT}/skills/pumasi-image/references/image-studio-prompt.md`를 Read하여 시스템 프롬프트를 내면화한다.

내면화 후:
1. Normalization JSON 내부적으로 작성 (노출하지 않음)
2. 선택된 모드의 Output Template을 200~500 단어 영문 프롬프트로 작성
3. 사용자 선택 값(비율·퀄리티·의도 3개)을 Technical Specifications / Anti-Patterns 섹션에 반영
4. 비율·퀄리티 자연어 힌트를 Technical Specifications에 삽입 (keyword-mapping.md 참조)

프롬프트 파일을 다음 경로에 저장:
```
{working_directory}/.omc/imagen/prompt-{timestamp}.md
```

없으면 `mkdir -p`로 생성.

### Step 5: 저장 경로 계산

**규칙**:
- 디렉토리: `images/{YYYY-MM-DD}/` (없으면 mkdir)
- 파일명 slug:
  - 사용자 요청에서 핵심 명사 1~2개 뽑아 영문 kebab-case로 변환 (예: "AI 마켓플레이스 로고" → `ai-marketplace-logo`)
  - 같은 날짜/slug가 이미 있으면 `-01`, `-02` 순번 추가
- 확장자: `.png`

최종 경로 예: `/Users/chulrolee/gptaku_plugins/images/2026-04-22/ai-marketplace-logo-01.png`

### Step 6: Codex /imagen 호출

`${CLAUDE_PLUGIN_ROOT}/skills/pumasi-image/scripts/imagen.sh`를 실행:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/pumasi-image/scripts/imagen.sh \
  "{prompt_file_path}" \
  "{target_image_path}"
```

스크립트 내부에서:
1. `codex features list`로 feature flag 재확인 (안전망)
2. `codex exec --skip-git-repo-check --dangerously-bypass-approvals-and-sandbox` 호출
3. 후처리 금지 가드 문구를 프롬프트 끝에 자동 추가
4. SHA1 일치 검증

### Step 7: 결과 확인 + 표시

1. 파일 존재 확인
2. `file {target_image_path}` 으로 해상도/포맷 출력
3. **Read** 도구로 이미지 표시 (사용자에게 시각적 피드백)
4. 저장 경로를 사용자에게 알림

### Step 8: MODE_REFINE 루프 대기

사용자가 수정 요청 시 다음을 판단:
- **동일 이미지 리파인** ("색감 좀 바꿔줘", "더 밝게"): Step 4로 돌아가 이전 프롬프트 기반으로 델타만 반영
- **완전 새 요청**: Step 1부터 다시

이전 대화 컨텍스트에 다음 정보 유지:
- 마지막 생성 이미지 경로
- 마지막 사용 프롬프트 파일
- 선택된 파라미터 (비율/퀄리티/의도 3개)
- 선택된 모드

---

## 기존 /pumasi와의 분리

| 구분 | /pumasi (코드) | /pumasi:image (이미지) |
|------|---------------|---------------------|
| 스킬 디렉토리 | `skills/pumasi/` | `skills/pumasi-image/` |
| 커맨드 | `/pumasi` | `/pumasi:image` |
| 자동 트리거 | "구현", "개발", "기능", "코드" | "이미지", "그림", "썸네일", "로고" |
| 설정 | `pumasi.config.yaml` | 사용 안 함 |
| 스크립트 | `scripts/pumasi.sh` 외 | `skills/pumasi-image/scripts/imagen.sh` |
| 작업 dir | `.pumasi-job/` | 없음 (단발 요청) |

두 스킬은 같은 플러그인 안의 독립 모듈이며 서로 간섭하지 않는다.

---

## References

- `references/image-studio-prompt.md` — 모드 분류 + Output Template 시스템 프롬프트
- `references/clarification-matrix.md` — 모드별 의도 파악 질문 매트릭스
- `references/keyword-mapping.md` — 비율·퀄리티 키워드 자동 매핑 + 자연어 힌트 변환표

## Scripts

- `scripts/imagen.sh` — feature flag 확인·활성화 + Codex `/imagen` 호출 + 후처리 금지 가드 + SHA1 검증

---

## 사전 조건

- Codex CLI 설치 (`command -v codex`)
- Codex 로그인 완료
- `codex features` 서브커맨드 사용 가능 (`codex features list`)
