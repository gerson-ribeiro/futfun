# Checkpoint Dev Session — Design Spec

**Date:** 2026-05-19  
**Status:** Approved  
**Skills:** `/checkpoint`, `/resume`

---

## Overview

Two generic, reusable Claude Code skills that provide automatic progress tracking for any project. They read and write a shared `.project/PROGRESS_TRACKING.md` file to persist development state across sessions.

---

## Goals

- Resume development across sessions without losing context
- Automatically save checkpoints after each completed task and each completed phase
- Support session recovery when a session crashes mid-development
- Work on any project that has a `.project/PLAN.md` (or similar plan file)

---

## Architecture

### Files

```
~/.claude/skills/
  checkpoint.md     ← /checkpoint skill (session start + auto-checkpoints)
  resume.md         ← /resume skill (session recovery)

<project>/
  .project/
    PLAN.md                  ← source of truth for task/phase structure
    PROGRESS_TRACKING.md     ← generated and maintained by the skills
```

### Shared State

Both skills read from and write to `.project/PROGRESS_TRACKING.md`. This file is the single source of truth for session state.

---

## `/checkpoint` Skill

### Invocation

Invoked by the user at the **start of a development session**.

### Behavior

**Step 1 — Initialize tracking file**
- Check if `.project/PROGRESS_TRACKING.md` exists
  - If **not found**: locate a plan file (`.project/PLAN.md`, `.project/IMPLEMENTATION_PLAN.md`, or any `.project/*.md` containing phases/tasks), parse it, and generate `PROGRESS_TRACKING.md` with all tasks set to `⏳ Pending`
  - If **found**: read current state (phase, last completed task, next task, progress %)

**Step 2 — Check automode**
- If Claude Code is running in **automode (autonomous mode)**:
  - Resume automatically from the next pending task — no questions asked
- If **not in automode**:
  - Present a summary:
    ```
    📋 Current Phase: Phase 1 — Infrastructure (90%)
    ✅ Last Completed: Task 9 — Create futfun-frontend repo
    ⏳ Next Task: Task 10 — Setup Flutter MVVM structure
    📊 Progress: 8/29 tasks (28%)
    ```
  - Ask: "Continue from where you left off (Task 10) or start a specific task?"

**Step 3 — Auto-checkpoint during session**

After each task is completed:
- Mark task as `✅` with completion date
- Update header fields: `Last Updated`, `Last Completed`, `Next Task`, `Progress`

After each phase is fully completed:
- Append a `### Phase Summary` block under the phase section:
  ```markdown
  ### Phase Summary
  **Completed on:** YYYY-MM-DD
  **Tasks:** N/N
  **Notes:** <agent-generated summary of what was built>
  ```

---

## `/resume` Skill

### Invocation

Invoked by the user **mid-session** when a session has crashed or been interrupted unexpectedly.

### Behavior

1. Read `.project/PROGRESS_TRACKING.md` (must exist — does not generate it)
2. Display recovery state:
   ```
   ⚡ Resuming session...
   ✅ Last completed: Task 9 — Create futfun-frontend repo
   ⏳ Next task: Task 10 — Setup Flutter MVVM structure
   ```
3. Resume immediately — no questions asked (user invoked `/resume` explicitly to continue)
4. After resuming, behave like `/checkpoint` automode: save checkpoint after each completed task

### Error case

If `.project/PROGRESS_TRACKING.md` does not exist, inform the user:
> "No progress tracking file found. Run `/checkpoint` first to initialize the session."

---

## Key Differences

| Behavior | `/checkpoint` | `/resume` |
|---|---|---|
| Invoked at | Session start | Mid-session recovery |
| Generates tracking file | Yes (from PLAN.md) | No |
| Asks user what to do | Only if not in automode | Never |
| Auto-checkpoints after tasks | Yes | Yes |

---

## `PROGRESS_TRACKING.md` Format

```markdown
# <Project Name> — Progress Tracking

**Status:** 🟡 In Progress
**Last Updated:** YYYY-MM-DD
**Current Phase:** Phase N — <Name> (X%)
**Last Completed:** Task N — <description>
**Next Task:** Task N+1 — <description>
**Progress:** X/Y tasks (Z%)

---

## Phase 1 — <Name>

- [x] Task 1: <description>  ✅ YYYY-MM-DD
- [x] Task 2: <description>  ✅ YYYY-MM-DD
- [ ] Task 3: <description>  ⏳ Pending

### Phase Summary
**Completed on:** YYYY-MM-DD
**Tasks:** N/N
**Notes:** <agent-generated summary>

---

## Phase 2 — <Name>

- [ ] Task 4: <description>  ⏳ Pending
...
```

---

## Auto-generation from PLAN.md

When generating `PROGRESS_TRACKING.md` from a plan file, the skill:

1. Searches `.project/` for a plan file using this priority order: `PLAN.md` → `IMPLEMENTATION_PLAN.md` → `SPEC.md` → first `*.md` file containing phase/task heading patterns. Uses the first match found.
2. Extracts phases using heading patterns (`## Phase`, `### Phase`, `## Fase`)
3. Extracts tasks using list patterns (`- [ ]`, `**Task N:**`, `- Task`)
4. Creates all tasks with status `⏳ Pending`
5. Sets header: `Progress: 0/N tasks (0%)`, `Next Task: Task 1`

---

## Out of Scope

- Integration with external issue trackers (Linear, Jira, GitHub Issues)
- Multi-project tracking in a single file
- Automatic git commits after checkpoints
