# Checkpoint Dev Session Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create two reusable Claude Code skills (`/checkpoint` and `/resume`) that provide automatic progress tracking across development sessions using `.project/PROGRESS_TRACKING.md`.

**Architecture:** Two markdown skill files at `~/.claude/skills/`. Both read and write a shared `.project/PROGRESS_TRACKING.md` in the current project. `/checkpoint` initializes or reads the file at session start and auto-saves after each task. `/resume` reads the last checkpoint and resumes immediately without asking.

**Tech Stack:** Claude Code skills (markdown files), no external dependencies

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `C:/Users/gugag/.claude/skills/checkpoint.md` | Create | `/checkpoint` skill — session start + auto-checkpoints |
| `C:/Users/gugag/.claude/skills/resume.md` | Create | `/resume` skill — session recovery |

---

## Task 1: Create skills directory

**Files:**
- Create: `C:/Users/gugag/.claude/skills/` (directory)

- [ ] **Step 1: Create the directory**

```bash
mkdir -p /c/Users/gugag/.claude/skills
```

Expected: directory created with no error (or already exists)

- [ ] **Step 2: Verify it exists**

```bash
ls /c/Users/gugag/.claude/skills
```

Expected: empty directory (no error)

---

## Task 2: Write the `/checkpoint` skill

**Files:**
- Create: `C:/Users/gugag/.claude/skills/checkpoint.md`

- [ ] **Step 1: Create the file with the following content**

Write to `C:/Users/gugag/.claude/skills/checkpoint.md`:

```markdown
---
name: checkpoint
description: Start a development session with automatic progress checkpoints. Reads or generates .project/PROGRESS_TRACKING.md, asks user what to do (or resumes automatically in automode), and saves a checkpoint after each completed task and phase.
---

# Checkpoint Dev Session

You are starting a development session with automatic progress tracking. Follow each step exactly and in order.

---

## Step 1: Initialize tracking file

Check if `.project/PROGRESS_TRACKING.md` exists in the current working directory.

**If the file does NOT exist:**

Locate a plan file in `.project/` using this priority order:
1. `PLAN.md`
2. `IMPLEMENTATION_PLAN.md`
3. `SPEC.md`
4. First `*.md` file whose content contains phase/task heading patterns (`## Phase`, `## Fase`, `- [ ]`)

Read the plan file. Extract:
- Project name (from the file's `#` heading, or the directory name as fallback)
- Phases (headings that follow patterns like `## Phase N`, `## Fase N`, `### Phase N`)
- Tasks per phase (lines matching `- [ ]`, `**Task N:**`, or `- Task N:`)

Generate `.project/PROGRESS_TRACKING.md` using this exact format:

```
# <Project Name> — Progress Tracking

**Status:** 🟡 In Progress
**Last Updated:** <today's date YYYY-MM-DD>
**Current Phase:** Phase 1 — <Phase 1 Name> (0%)
**Last Completed:** —
**Next Task:** Task 1 — <first task description>
**Progress:** 0/<total tasks> tasks (0%)

---

## Phase 1 — <Name>

- [ ] Task 1: <description>  ⏳ Pending
- [ ] Task 2: <description>  ⏳ Pending

---

## Phase 2 — <Name>

- [ ] Task 3: <description>  ⏳ Pending
```

**If the file DOES exist:**

Read and extract: Current Phase, Last Completed, Next Task, Progress count.

---

## Step 2: Check automode

Determine if you are running autonomously (automode):
- You are in automode if you were invoked without interactive user input — for example, via `--automode` flag, as part of a scheduled agent, or through a non-interactive pipeline.
- You are NOT in automode if you are in an interactive session where the user is present and can respond.

**If in automode:** skip directly to Step 3b.

**If NOT in automode:** proceed to Step 3a.

---

## Step 3a: Ask user (interactive mode only)

Present the current state:

```
📋 Current Phase: <phase name and completion %>
✅ Last Completed: <task description, or "— (not started)" if none>
⏳ Next Task: <next pending task>
📊 Progress: <X/Y tasks (Z%)>
```

Ask the user:
> "Continue from where you left off (<Next Task>) or start a specific task?"

Wait for the user's answer before proceeding. If they name a specific task, start there instead of Next Task.

---

## Step 3b: Resume automatically (automode)

Without asking anything, resume from the task listed in **Next Task** in the header of `PROGRESS_TRACKING.md`.

---

## Step 4: Auto-checkpoint — run after EVERY completed task

After you complete each task during this session, immediately update `.project/PROGRESS_TRACKING.md`:

**4a. Mark the task as done:**

Find the task line in the file. Change:
```
- [ ] Task N: <description>  ⏳ Pending
```
to:
```
- [x] Task N: <description>  ✅ <today's date YYYY-MM-DD>
```

**4b. Update the header block:**

Replace the header values:
```
**Last Updated:** <today's date YYYY-MM-DD>
**Current Phase:** Phase <N> — <Name> (<X%>)
**Last Completed:** Task <N> — <description>
**Next Task:** Task <N+1> — <description of next pending task, or "— (all done)" if none>
**Progress:** <completed count>/<total count> tasks (<Z%>)
```

Calculate `<X%>` as: (completed tasks in current phase / total tasks in current phase) × 100, rounded to nearest integer.

**4c. Phase completion — only when the last task of a phase is done:**

After updating the task and header, if ALL tasks in the current phase are now marked `[x]`, append this block immediately after the last task in that phase (before the next `---`):

```
### Phase Summary
**Completed on:** <today's date YYYY-MM-DD>
**Tasks:** <N>/<N>
**Notes:** <2-3 sentences describing what was built in this phase>
```

Generate the Notes content yourself based on what was implemented during this phase.

---

## Reminders

- Checkpoint EVERY task — not just at the end of the session.
- If the session ends unexpectedly, the last checkpoint is what `/resume` will use to recover.
- Never skip the checkpoint step even for "small" tasks.
```

- [ ] **Step 2: Verify the file was created and has content**

```bash
wc -l /c/Users/gugag/.claude/skills/checkpoint.md
```

Expected: at least 80 lines

- [ ] **Step 3: Commit**

```bash
cd /c/Users/gugag/.claude
git add skills/checkpoint.md
git commit -m "feat: add /checkpoint skill for automatic dev session progress tracking"
```

---

## Task 3: Write the `/resume` skill

**Files:**
- Create: `C:/Users/gugag/.claude/skills/resume.md`

- [ ] **Step 1: Create the file with the following content**

Write to `C:/Users/gugag/.claude/skills/resume.md`:

```markdown
---
name: resume
description: Recover a crashed or interrupted development session. Reads the last checkpoint in .project/PROGRESS_TRACKING.md and resumes immediately from the next pending task — no questions asked.
---

# Resume Dev Session

You are recovering an interrupted development session. Follow each step exactly and in order. Do NOT ask the user anything — resume immediately.

---

## Step 1: Read the tracking file

Open `.project/PROGRESS_TRACKING.md`.

**If the file does NOT exist**, stop and tell the user:

> "No progress tracking file found. Run `/checkpoint` first to initialize the session."

Do not proceed further.

**If the file exists**, read:
- **Last Completed:** (the task that was done before the interruption)
- **Next Task:** (the task to resume from)
- **Current Phase:** (current phase name and %)
- **Progress:** (X/Y tasks)

---

## Step 2: Display recovery state

Show this exactly:

```
⚡ Resuming session...
✅ Last completed: <Last Completed value>
⏳ Next task: <Next Task value>
📊 Progress: <Progress value>
```

Then immediately begin working on the Next Task. Do not ask for confirmation.

---

## Step 3: Auto-checkpoint after every task

After you complete each task during this recovered session, immediately update `.project/PROGRESS_TRACKING.md` using the same checkpoint rules as `/checkpoint` Step 4:

**3a. Mark the task as done:**

Find the task line. Change:
```
- [ ] Task N: <description>  ⏳ Pending
```
to:
```
- [x] Task N: <description>  ✅ <today's date YYYY-MM-DD>
```

**3b. Update the header block:**

```
**Last Updated:** <today's date YYYY-MM-DD>
**Current Phase:** Phase <N> — <Name> (<X%>)
**Last Completed:** Task <N> — <description>
**Next Task:** Task <N+1> — <description, or "— (all done)" if none>
**Progress:** <completed>/<total> tasks (<Z%>)
```

**3c. Phase completion — only when the last task of a phase is done:**

Append immediately after the last task in the completed phase:

```
### Phase Summary
**Completed on:** <today's date YYYY-MM-DD>
**Tasks:** <N>/<N>
**Notes:** <2-3 sentences describing what was built in this phase>
```

---

## Reminders

- Resume immediately — the user invoked `/resume` because they want to continue, not to be asked about it.
- Checkpoint every task, just like a normal `/checkpoint` session.
- If there is no Next Task (all done), congratulate the user and display the final progress summary.
```

- [ ] **Step 2: Verify the file was created and has content**

```bash
wc -l /c/Users/gugag/.claude/skills/resume.md
```

Expected: at least 60 lines

- [ ] **Step 3: Commit**

```bash
cd /c/Users/gugag/.claude
git add skills/resume.md
git commit -m "feat: add /resume skill for mid-session recovery"
```

---

## Task 4: Verify skills are discoverable by Claude Code

Skills in `~/.claude/skills/` are loaded automatically by Claude Code at session start.

- [ ] **Step 1: List the skills directory**

```bash
ls /c/Users/gugag/.claude/skills/
```

Expected output:
```
checkpoint.md
resume.md
```

- [ ] **Step 2: Confirm skill frontmatter is valid**

Check that each file starts with a valid YAML frontmatter block (`---` delimiter, `name` and `description` fields):

```bash
head -5 /c/Users/gugag/.claude/skills/checkpoint.md
head -5 /c/Users/gugag/.claude/skills/resume.md
```

Expected: both files start with `---`, have `name:` and `description:` fields.

- [ ] **Step 3: Manual smoke test — `/checkpoint` on FutFun**

In the FutFun project directory (`E:/source/personal/futfun`):
1. Invoke `/checkpoint` in a new Claude Code session
2. Verify it reads `.project/PROGRESS_TRACKING.md` correctly
3. Verify it presents the current state (Phase 1, Task 10 pending)
4. Verify it asks whether to continue or start a specific task

- [ ] **Step 4: Manual smoke test — `/resume`**

1. Invoke `/resume` in a new Claude Code session
2. Verify it reads the same tracking file
3. Verify it displays the recovery state immediately without asking questions
4. Verify it would resume from Task 10

---

## Self-Review Checklist

- [x] Both skills cover all spec requirements (automode check, auto-checkpoint per task, phase summary, file generation from PLAN.md)
- [x] `/resume` correctly handles missing tracking file with clear error message
- [x] No placeholder content — all step content is fully specified
- [x] Task 4 steps are verification only, no new implementation
- [x] Checkpoint format is identical between `/checkpoint` Step 4 and `/resume` Step 3 — no drift
