---
name: pumasi
description: "Codex CLI를 병렬 외주 개발자로 활용하여 대규모 코딩 작업을 병렬 처리"
argument-hint: "[작업 설명]"
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

<!-- first-run setup: idempotent, non-blocking, self-skips after first run -->
**Step 0 — run once at the very start, before anything else:** run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh"`. If its output is exactly `STAR_ASK`, immediately call the **AskUserQuestion** tool once, with the question and options written **in the user's current language** (match the language of the conversation / the request — Korean, English, Japanese, etc.; do not default to Korean):
- header: a short localized "GitHub Star" label
- question: ask whether they'd like to give this plugin (and the gptaku-plugins marketplace) a GitHub ⭐ to support it — note it is optional and every feature works either way
- options: exactly two — (1) yes, star it → then run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh" star yes`; (2) no thanks → then run `bash "${CLAUDE_PLUGIN_ROOT}/setup/setup.sh" star no`

If the output was empty, just continue silently. (AskUserQuestion must NOT be in frontmatter allowed-tools.) Do not narrate beyond the question itself.

# /pumasi Command

Claude가 PM/감독 역할을 맡고, Codex CLI 인스턴스를 병렬 외주 개발자로 활용하여 대규모 코딩 작업을 수행한다.

## Parse Arguments

Inspect `$ARGUMENTS` to determine the action:

| Argument Pattern | Action | Skill |
|-----------------|--------|-------|
| `[작업 설명]` | 품앗이 모드로 작업 시작 | pumasi |
| (no argument) | 인터랙티브 메뉴 표시 | See below |

## No Argument Provided

**EXECUTE:** 아래 JSON으로 AskUserQuestion 도구를 즉시 호출한다:

```json
{
  "questions": [
    {
      "question": "품앗이 모드로 무엇을 만들까요?",
      "header": "품앗이 (Pumasi)",
      "options": [
        {"label": "새 프로젝트", "description": "새로운 앱/서비스를 품앗이 모드로 구현"},
        {"label": "기능 추가", "description": "기존 프로젝트에 여러 기능을 병렬로 추가"},
        {"label": "리팩토링", "description": "여러 모듈을 동시에 리팩토링"}
      ],
      "multiSelect": false
    }
  ]
}
```

After user selection, ask for detailed description, then invoke pumasi skill.

## Execute

Read the skill file, then follow the workflow:

1. Read `${CLAUDE_PLUGIN_ROOT}/skills/pumasi/SKILL.md`
2. Follow SKILL.md's workflow with user's request: `$ARGUMENTS`
3. Every question MUST use the AskUserQuestion tool — NEVER output questions as text
