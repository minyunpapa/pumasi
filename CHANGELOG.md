# Changelog

## [1.7.3] - 2026-05-04

### Removed
- `references/image-studio-prompt.md`: "Prompt Analysis Blocking Rule" 5줄 삭제 (라인 30-34) — self-critique 차단 wrapper 제거 (fossil v3 처치)

### Preserved
- 보안 가드 1-4번 (시스템 프롬프트 노출 금지, mode 비공개, XML 구조 비공개, 우선순위 명시)
- pumasi-job-worker.js wrapper의 도메인-종속 가드는 음성적 지식(과거 codex crash 흔적 추정)으로 보존

## [1.7.2] - 2026-04-24

### Fixed
- `--ephemeral` 플래그 실제 코드에서 제거 (CHANGELOG v1.2.0 기록과 코드 불일치 수정)

## [1.7.1] - 2026-04-22

### Fixed
- `/pumasi:image` 저장 경로를 **git root 기준으로 동적 계산**하도록 수정
  - 기존: 단순 상대 경로 `images/{날짜}/` → Claude Code 세션 cwd가 홈일 때 `~/images/...`로 엉뚱하게 저장되는 문제
  - 수정: `git rev-parse --show-toplevel || pwd` 로 기준 디렉토리 결정 후 그 하위에 저장
  - 프로젝트 작업 중이면 프로젝트 루트 `images/{날짜}/` 에 저장 보장
  - 하드코딩 절대경로 없음 (어느 프로젝트에서든 동작)

## [1.7.0] - 2026-04-22

### Added
- `/pumasi:image` 서브커맨드 신설 — Codex `/imagen`으로 이미지 생성
  - 기존 `/pumasi`(코드 병렬 외주)와 완전히 독립된 스킬 모듈
  - 자동 트리거 키워드: "이미지/그림/썸네일/로고/일러스트/포스터/아이콘"
  - 코드 키워드("함수/컴포넌트/페이지 만들어줘")엔 트리거되지 않음
- `skills/pumasi-image/SKILL.md` — 8단계 워크플로우
  - Step 0: `image_generation` feature flag 자동 활성화
  - Step 1: 7가지 모드 자동 감지 (MODE_A~G)
  - Step 2: 키워드 자동 매핑 (비율·퀄리티)
  - Step 3: AskUserQuestion (최대 5개 — 기술 2 + 의도 3)
  - Step 4: image-studio 시스템 프롬프트 내면화 + Output Template 작성
  - Step 5: 저장 경로 계산 `images/{YYYY-MM-DD}/{slug}-{seq}.png`
  - Step 6: `scripts/imagen.sh` 호출 + 후처리 금지 가드
  - Step 7: Read로 결과 표시
  - Step 8: MODE_REFINE 멀티턴 루프
- `references/image-studio-prompt.md` — 모드 분류 + 모드별 Output Template
- `references/clarification-matrix.md` — 모드별 의도 파악 질문 매트릭스
  - 모드당 3개 슬롯 (스타일/분위기/색감/구도/용도/텍스트공간/사용맥락/배경 등)
  - 각 카테고리 5개 이상 선택지 + 1~2개 창의적 대안 + "자동 추천" 안전망
- `references/keyword-mapping.md` — 비율·퀄리티 키워드 자동 매핑 + 자연어 힌트 변환표
- `scripts/imagen.sh` — Codex 호출 래퍼
  - feature flag 자동 활성화
  - 후처리 금지 가드 자동 주입
  - SHA1 해시 일치 검증 (원본 ↔ 저장본)

### Notes
- 백엔드는 **Codex `/imagen` 단일**. nanobanana(Gemini API) 의존성 없음.
- Codex CLI의 기술 파라미터 제어 한계로 인해 Size/Quality는 **자연어 힌트**로만 전달됨 (정확한 해상도 보장 X).
- 9:16 세로, 4:1 배너는 Codex 지원 여부 불확실 (실험적).
- 투명 배경은 현재 스코프 밖 (Codex CLI에서 alpha 채널 지원 불가 확인됨).

## [1.6.0] - 2026-03-18

### Changed
- SKILL.md Progressive Disclosure 리팩토링: 705줄 → 281줄 (60% 감소)
  - 레퍼런스 콘텐츠를 `references/` 디렉토리로 분리 (6개 파일)
  - anti-patterns.md, role-separation.md, codex-guide.md, instruction-templates.md, tech-stack.md, examples.md
  - SKILL.md에 참조 포인터 유지, 필요 시 Read로 로드하는 구조
  - 핵심 실행 흐름(트리거, 워크플로우, Phase 0~6)은 SKILL.md에 유지

## [1.3.1] - 2026-03-02

### Fixed
- Command file Execute 섹션: "located at" 정보 제공 → 명시적 Read 지시로 변경
  - SKILL.md를 반드시 Read하도록 번호 리스트 추가
  - AskUserQuestion 도구 호출 필수 규칙 명시

## [1.3.0] - 2026-02-28

### Added
- Phase 5.5: `/simplify` 코드 정리 단계 (게이트 PASS 후, 통합 전)
  - 병렬 에이전트가 코드 품질/컨벤션을 자동 점검
  - Claude PM 토큰을 거의 사용하지 않으면서 Codex 코드 품질 보완
  - `/simplify` 후 게이트 재실행으로 기능 보존 확인
- `/batch`와의 관계 가이드 섹션
  - 품앗이(Greenfield) vs /batch(Brownfield) 포지셔닝 명확화
  - 작업 유형별 도구 선택 가이드

## [1.2.0] - 2026-02-28

### Changed
- SKILL.md 전면 개정: "복붙형 instruction" 안티패턴 근절
  - Claude는 시그니처 + 요구사항만 작성, 함수 body 작성 금지
  - Codex가 실제 구현자로 동작하도록 역할 분리 명확화
- pumasi.config.yaml 예시를 시그니처 패턴으로 전면 교체
  - 이전: 전체 코드 블록 포함된 테스트용 config
  - 이후: auth-token, auth-password, user-model 시그니처 예시
- 게이트 설계 원칙 변경: ls/grep 중심 → tsc/build/test 중심

### Added
- 안티패턴 경고 섹션 (SKILL.md 최상단)
- Claude vs Codex 역할 분리 표 (제공 vs 금지 명확화)
- 게이트 셸 호환성 가이드: `test -f` → `[ -f ]` POSIX 브래킷 문법
- Phase 5에 Step 0 "의존성 확인" 단계 추가 (npm install 후 게이트 실행)
- 작업 규모별 분기 가이드 (1-2개: Claude 직접, 5+: 품앗이 권장)
- instruction 자기 점검 체크리스트 (코드 블록/복붙 패턴 감지)
- 좋은 instruction vs 나쁜 instruction 비교 예시

### Removed
- "import 문과 초기화 코드까지 직접 작성해서 제공" 가이드 삭제
- better-sqlite3 "좋은 instruction" 예시 (전체 코드 제공 패턴) 삭제
- 기본 Codex 명령어의 `--ephemeral` 플래그 제거

## [1.1.0] - 2026-02-27

### Added
- 워커 프롬프트에 코드 스타일 규칙 추가 (정확성 최우선 + 관용적 패턴)
- config `style` 필드로 프로젝트별 커스텀 코드 스타일 주입 지원
- 라운드 기반 실행 (round 1 완료 후 round 2 자동 시작)
- 게이트(gates) 실행 및 자동 검증
- 재위임(redelegate) + 자동수정(autofix) 워크플로우
- `--output-schema` 구조화 JSON 출력 지원
- 빈 프롬프트 감지 및 에러 처리 (DOE E06e)
- `package.json` 추가 (yaml 의존성 관리)

### Changed
- 기본 Codex 명령어에 `--ephemeral` 플래그 추가
- `reference_files` 경로 해석: SKILL_DIR → workingDir 기준으로 변경
- 에러 메시지 구체화 (워커 필수 인자 안내)

### Fixed
- `startedAt` 타이밍 데이터 누락 수정 (에러/종료 핸들러)

## [1.0.0] - 2026-02-26

### Added
- 최초 릴리스 (CCPS v2.0 준수)
- Claude PM + Codex 병렬 워커 아키텍처
- N개 Codex 인스턴스 병렬 실행
- 태스크별 instruction 자동 구성
- 워커 프로세스 관리 (start/status/wait/results/stop/clean)
- `pumasi.config.yaml` 기반 태스크 설정
- 컨텍스트 파일 참조 (`reference_files`)
