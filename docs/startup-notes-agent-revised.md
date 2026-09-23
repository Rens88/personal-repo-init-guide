# Daily use of the supervised builder-reviewer pipeline

Personal operating notes for the existing AMS pipeline. Initial cloning, sandbox authentication, dependency installation and setup confirmation are assumed complete. Do not repeat initialization as daily startup.

General references: [starter README](../src/agent-pipeline-demo-starter/README.md) and [standalone startup checklist](../dist/HUMAN_READABLE_STARTUP_CHECKLIST.html).

## Locations and roles

Pipeline root: `C:\Users\rmeer\CodeLibrary\agentic-ams-elarning-automatisation`. The spelling `elarning` matches the existing folder.

| Location | Purpose |
| --- | --- |
| `control` | Human preparation, submission and inspection of published work |
| `builder` | Dedicated Claude checkout, synchronized by the dispatcher |
| `reviewer` | Dedicated Codex checkout, synchronized by the dispatcher |
| `origin.git` | Local bare Git remote shared by the three clones |
| `logs` | Agent execution logs |
| `state` | Setup and processed-event records; preserve these between sessions |

**Dispatcher** and **Control** are PowerShell tab names. Both tabs normally work from the `control` folder. Agents run inside their sandboxes and do not require separate PowerShell tabs.

A push to `origin` here updates the local bare remote. It does not publish to Azure or update the original checkout outside this pipeline.

## 1. Open two PowerShell tabs

In each tab:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
Set-Location "C:\Users\rmeer\CodeLibrary\agentic-ams-elarning-automatisation\control"
```

Execution policy changes last for that PowerShell process only and do not require administrator privileges. Organization-enforced Group Policy can still block execution; this command cannot override it. Changing directory is a separate operation.

In **Control**, check your starting state:

```powershell
git status --short
git remote -v
```

A clean working tree produces no status output. Resolve unrelated changes deliberately; do not use blanket staging, reset or clean commands to make checks pass. When clean:

```powershell
git pull --ff-only origin main
```

If a command fails, resolve it before continuing. Pasting separate commands into PowerShell does not automatically stop execution after every native-command failure.

## 2. Start the dispatcher

In **Dispatcher**:

```powershell
.\automation\Start-AgentPipeline.ps1 -BuilderSandbox ams-elearning-builder -ReviewerSandbox ams-elearning-reviewer
```

Look for `Watching local origin:` and the correct sandbox names. Leave this tab running. Use one dispatcher and one task in flight per pipeline.

The dispatcher polls committed events on local `origin.git/main`, not unsaved files. It starts the agents when needed. Starting it before submission makes progress visible, but it can also pick up tasks submitted while it was stopped. Previously submitted unprocessed work may start immediately.

Do not run another interactive agent in either agent checkout during a job. Do not routinely stop sandboxes before each task: a running sandbox alone is not a fault. Closing PowerShell does not remove sandbox installations or authentication.

## 3. Generate and save a task

After reviewing their contents, use `control\skills\task-authoring\SKILL.md` and the guidance in `control\docs\task-authoring.md`. Paste or attach the instruction text in a fresh ChatGPT or Claude conversation. Do not assume the apps have identical native skill-installation mechanisms.

Supply relevant, non-secret context:

- Project purpose and the desired outcome.
- `AGENTS.md` and applicable linked repository guidance.
- Relevant source files, documentation and architecture constraints.
- `agent-pipeline.config.json` with its available validation profiles.
- Existing task IDs, prior reviews and decisions already made.

Never provide `.env` or credentials. Ask the assistant to challenge assumptions, ask focused questions, narrow scope and resolve material decisions before producing a submission-ready file. A fresh chat cannot infer local repository contents.

Check existing IDs in **Control**:

```powershell
Get-ChildItem .\builder-instructions\TASK-*.md | Select-Object -ExpandProperty Name
```

Choose a new unused ID. Four-digit numbering is a convention; the sequence need not start at 0100. Do not reuse TASK-0100 or edit its submitted instruction to request more work.

Ask for a UTF-8 Markdown file named `TASK-NNNN-short-description.md` with this recommended structure. Replace placeholders and fill every body section before submission:

```markdown
---
id: TASK-NNNN
title: One concrete outcome
validation-profile: default
spec-path:
spec-commit:
---

# Goal

# Requirements

# Acceptance criteria
```

Use a confirmed validation profile. A frozen specification requires both its repository-relative path and valid full commit SHA; otherwise leave both spec fields empty.

This is the **recommended authoring format**, not the validator's minimum contract. The shared validator does not require a title or these body headings, defaults an omitted profile to `default`, and allows both spec fields to be absent. Passing validation does not prove a task is clear or that human decisions are resolved.

Save the reviewed file under `control\builder-instructions\`. Unicode punctuation and non-English text are allowed; save as UTF-8. Saving or staging alone does not trigger the pipeline.

## 4. Submit the task

In **Control**, set the actual file path. This filename is an example; replace it before running:

```powershell
$taskPath = '.\builder-instructions\TASK-0101-short-description.md'
Get-Content -Raw -Encoding UTF8 $taskPath
git status --short
```

Only that task file may be changed or untracked. `??` means untracked; a staged new file can show `A`. Unrelated modified or untracked files block submission.

After reviewing the saved file:

```powershell
.\automation\Submit-Task.ps1 -Path $taskPath
```

The script pulls local main, validates the task, stages it, commits it with pipeline event metadata and pushes to local `origin.git`. **This submission is your signoff.** Do not manually commit first: ordinary commits lack the event metadata, and task IDs are immutable once submitted.

If submission fails after making a commit, inspect `git status` and `git log -1` before retrying. Do not create a duplicate task simply because a push failed.

## 5. Watch the run

The normal sequence in **Dispatcher** is:

1. Synchronize the builder to the instruction commit.
2. Claude implements the requested task and runs validation.
3. Check and publish its single implementation commit to local main.
4. Synchronize the reviewer to that implementation.
5. Codex independently reviews and validates it.
6. Check and publish the review, plus a follow-up draft when needed.

The builder implements whichever task was submitted, not always documentation and a skill. Implementation reaches local main before review; review is not a merge gate keeping unreviewed changes off that local branch.

Wait for **Published review** and the verdict. An agent saying it finished does not prove the dispatcher accepted or published its commit.

The launcher prints the exact log path. List recent logs from **Control**:

```powershell
Get-ChildItem ..\logs\*.log | Sort-Object LastWriteTime -Descending | Select-Object -First 6 Name, LastWriteTime
```

Do not push unrelated changes while a build/review is pending. Publication requires local main to remain at its expected parent. Leave recovery patches uncommitted until the pending review is published, then pull and commit them separately.

## 6. Pull and manually inspect published work

In **Control**, use the ID of the run being inspected:

```powershell
$taskId = 'TASK-0100'
git pull --ff-only origin main
Get-Content -Raw -Encoding UTF8 ".\reviews\$taskId.md"
git log -8 --oneline --decorate
```

Stop if the pull fails. Inspect:

- The original instruction and its acceptance criteria.
- The review's findings, actual commands/results, missing checks and residual risks.
- The exact implementation diff, including unexpected changes or omissions.
- Changed documentation or UI as a human would use it.
- The follow-up draft, if present, and any unresolved decisions.

Use the exact instruction and implementation SHAs recorded in the review. Do not assume `HEAD~1` identifies the build; review and maintenance commits may intervene. Replace these placeholders before execution:

```powershell
$instructionCommit = 'PASTE_INSTRUCTION_SHA_FROM_REVIEW'
$implementationCommit = 'PASTE_IMPLEMENTATION_SHA_FROM_REVIEW'
git diff --stat "${instructionCommit}..${implementationCommit}"
git diff "${instructionCommit}..${implementationCommit}"
```

You can also open the local `control` folder in File Explorer or an editor:

```powershell
explorer.exe .
```

For TASK-0100, inspect `README.md`, `docs\agent-workflow.md`, `docs\task-authoring.md` and `skills\task-authoring\SKILL.md`, together with its instruction, review and follow-up draft. Check `TASKS.md` when repository governance requires progress tracking. Test section links in the intended Markdown renderer.

| Verdict | Human action |
| --- | --- |
| `PASS` | Inspect the report and changes, then decide whether to accept the work |
| `CHANGES_REQUESTED` | Review the findings and draft; edit and submit a follow-up if you agree |
| `DECISION_REQUIRED` | Resolve the questions before submitting a follow-up |

PASS is evidence, not automatic human acceptance or external publication. There is no separate built-in PASS-signoff script. A negative review is not completion: address it or explicitly defer/abandon the work. Passing Python tests alone does not resolve documentation findings.

## 7. Promote, review and submit a follow-up

Run these steps in **Control** after review publication. The dispatcher may remain watching while you prepare the follow-up.

Read both files and check for a clean tree:

```powershell
$parentTask = 'TASK-0100'
git pull --ff-only origin main
Get-Content -Raw -Encoding UTF8 ".\reviews\$parentTask.md"
Get-Content -Raw -Encoding UTF8 ".\followups\$parentTask.draft.md"
git status --short
```

Promotion requires a clean tree. Resolve any pending launcher changes separately before promotion; do not discard them automatically.

Choose a short lowercase hyphenated slug and promote:

```powershell
.\automation\Promote-Followup.ps1 -TaskId $parentTask -Slug correct-workflow-docs
```

The script creates an instruction file using the next ID after the highest committed task number and prints its exact path. If TASK-0100 is still the highest, it creates `builder-instructions/TASK-0101-correct-workflow-docs.md`. Use the actual printed path if it differs.

**Promotion does not commit, push or trigger an agent. It is not signoff.** The original committed draft remains as an audit record. Edit the newly generated instruction, not the original draft or previously submitted task:

```powershell
$followupPath = '.\builder-instructions\TASK-0101-correct-workflow-docs.md'
notepad $followupPath
```

Pause to edit and save before continuing. Preserve the assigned ID, `parent-task`, and a valid validation profile. For `DECISION_REQUIRED`, answer every question, incorporate the decisions into concrete requirements, and remove the obsolete unresolved-decisions section. Record the choices explicitly in the new task when useful.

Read CHANGES_REQUESTED drafts too: the reviewer cannot authorize a broader scope for you. The scripts do not prove that prose questions are answered; you are responsible for making the instruction ready.

Review the saved file and confirm it is the only change:

```powershell
Get-Content -Raw -Encoding UTF8 $followupPath
git status --short
```

Then sign off by submitting:

```powershell
.\automation\Submit-Task.ps1 -Path $followupPath
```

If the dispatcher is stopped, start it in **Dispatcher** using step 2. After publication, pull and inspect the new task's review, for example `reviews\TASK-0101.md`.

If another follow-up is needed, promote from TASK-0101, not TASK-0100. Otherwise perform human acceptance and prepare the next task. Automatic feedback resubmission is not implemented.

The default limit is three follow-up rounds after the initial task; check `followups.maxRounds` in configuration for the actual value. At the limit, reassess scope or requirements. Do not remove ancestry to evade it. `-Force` allows an intentional fork from a task that already has a committed follow-up; it is neither a routine retry flag nor a round-limit override.

## 8. Failures, stopping and maintenance

- Stop an idle dispatcher with Ctrl+C. Interrupting active work may leave partial files or an agent process; inspect before restarting.
- On failure, inspect logs and preserve useful uncommitted agent work. Synchronization hard-resets and runs `git clean -fdx` in the dedicated agent clones, deleting ignored files too.
- Keep `state\processed-commits.txt`. Failed events are not marked processed; matching published events prevent duplicate jobs.
- Retry infrastructure failures by fixing the cause and restarting the dispatcher, not resubmitting an existing task.
- Keep virtual environments outside checkouts. This setup has `/home/agent/.venvs/ams-elearning` separately inside each sandbox.
- `sbx exec` uses the sandbox working directory, not your PowerShell folder. Host Conda packages are separate from sandbox packages.
- Do not rerun initialization or `Confirm-PipelineSetup.ps1` as daily startup steps.
- Change pipeline configuration/governance separately before submitting new tasks. Agents cannot modify protected files. Validation is selected from the instruction commit; later configuration changes do not rewrite old tasks.
- Publishing accepted work to Azure is a separate operation. Check the destination and the changes to be published first.

## Review of the original notes

The original sequence was mostly sound. All three `@Agent` sections are filled above. The main corrections and additions are:

1. Tab names and working directories are different concepts.
2. Process execution policy cannot override organization policy.
3. Task generation needs context, unique IDs, UTF-8 files and human decisions. The recommended format is stricter than machine validation.
4. Submission supplies the event metadata and signoff; an ordinary manual commit is insufficient.
5. The expected build description must apply to any task, not only TASK-0100.
6. Inspect exact implementation changes and actual evidence, not just the verdict.
7. Promotion prepares a file; submission separately authorizes execution.
8. Later follow-ups use the latest task ID and respect the round budget.
9. Local publication, human acceptance and external publication are separate.
10. Routine operation and failure recovery differ; preserve state and avoid competing pushes.

At revision time, TASK-0100 had a published CHANGES_REQUESTED review for an inaccurate description of validator enforcement and two broken Markdown section anchors. Its draft proposes those fixes. The launcher fix was committed on local main and `control` was clean. Recheck status before using the examples.
