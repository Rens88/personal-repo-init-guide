# Implementation Plan: Integrate the Personal Docker Sandbox Cheatsheet and Remaining Backlog Work

## 1. Objective

Expand `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html` so that the useful, repeatedly used commands in `personal-cheatsheet.md` have a clear, safe, copy-ready place in the standalone checklist. At the same time:

- retain the backlog features that are already implemented;
- finish or refine backlog items that are only partially implemented;
- remove personal/local-machine-specific paths and examples from the distributable HTML;
- replace every Projexcellent-specific value with the appropriate Project context field or a neutral field default;
- explain why each chapter and major workflow choice exists, not only which commands to run;
- keep prompts visually and behaviorally distinct from shell commands;
- preserve the single-file, dependency-free nature of the checklist;
- keep the guide suitable for users with basic programming knowledge who may know one Python workflow but do not yet have an overview of stack choices, while retaining correct macOS/Linux variants where the checklist already supports them.

This plan intentionally does not implement any HTML, JavaScript, CSS, or starter-template changes yet.

## 2. Repository Constraints and Intended File Scope

The root `AGENTS.md` makes the standalone HTML the source of truth for checklist UX, copy, and interaction behavior. Therefore the expected implementation scope is:

- Primary implementation file: `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html`
- Planning input only: `personal-cheatsheet.md`
- Backlog inputs only:
  - `backlog.txt`
  - `backlog(1).txt`
  - `backlog_combined.txt`
  - `docker_sandbox_backlog(1).txt`
  - `speckit_extras_backlog.txt`
- Normally out of scope:
  - `src/bootstrap_repo.py`
  - `src/AGENTS.md`
  - `src/AGENTS_INIT.md`

The proposed changes affect checklist guidance, not downloaded starter-file content. Therefore `src/` and the embedded downloads should not need changes. Before finishing implementation, verify that no proposed wording has accidentally created a policy mismatch with the starter files. If a downloaded starter file must change after all, edit its canonical copy under `src/` first and then synchronize the embedded HTML copy as required by `AGENTS.md`.

Do not add a build system, package dependency, external stylesheet, external script, or sibling-file runtime dependency.

## 3. Audit Summary

### 3.1 Backlog implementation status

| Backlog source | Requested idea | Current status | Evidence in the standalone HTML | Work still needed |
|---|---|---:|---|---|
| `backlog.txt`, item 1 | Do not show PowerShell/cmd/Bash tabs for suggested agent prompts | Implemented | The `prompt()` helper sets `prompt: true`; `renderCard()` only creates shell/provider tabs when `!card.prompt`; the Chapter 8 agent text and all other suggested prompts use `prompt()` | Preserve and add regression checks for every newly added prompt |
| `backlog.txt`, item 2 | Explain `sbx --clone`, file access, commit/push/PR flow, with manual and agent options | Partially implemented | The Docker Sandbox model explains the private clone; “How sandbox work returns to the host” mentions manual and agent paths; Daily Dev has a sandbox handoff | Expand the two paths into explicit, ordered workflows; explain when the sandbox remote is available; make the feature branch inside the clone the primary path; provide a copy-ready agent prompt |
| `backlog(1).txt` | Daily Dev “Keep Committing” local-files vs Docker-Sandbox toggle and host-side fetch/merge/push flow | Implemented | `daily-commit-location` choice exists; local cards are gated to `local-files`; sandbox cards inspect/fetch/log/switch/merge/commit/push; `daily-finish` contains the handoff reminder | Preserve it, but align refinements with the clearer clone-mode workflow and current Docker guidance |
| `backlog_combined.txt` | Same Daily Dev toggle work | Implemented duplicate | File content is byte-for-byte identical to `backlog(1).txt` | Treat as one requirement, not two separate implementation tasks |
| `docker_sandbox_backlog(1).txt` | “Use the Sandbox Yourself”; run ordinary commands directly; reserve Codex for reasoning | Mostly implemented | Docker Sandbox cards already cover `pwd`, `ls`, `git status`, `git diff`, `git log`, branches, `pytest`, and `npm test`; the guide says “Think of Codex as a software engineer, not as your terminal” | Add the missing interactive shell entry point and a Python check; make the yes/no decision rule more scannable; integrate file viewing and app/process checks without duplicating existing cards |
| `speckit_extras_backlog.txt` | Full Spec Kit workflow with eight skills, prompts, outputs, checkpoints, example workflow, and decision tree | Implemented | The Extras `spec-kit` chapter contains every requested skill, separate explanation/prompt cards, expected output, checkpoints, a complete example, and a quick decision tree | No new feature work; preserve and regression-test prompt classification and standalone rendering |

### 3.2 Personal cheatsheet coverage

| Cheatsheet topic | Current coverage | Planned disposition |
|---|---|---|
| Open an interactive sandbox Bash shell with `sbx exec -it ... bash` | Missing | Add near the start of “Use the sandbox yourself” as the basic entry point for manual work |
| Run the Streamlit app locally | Only indirectly present in the embedded starter file; no user-facing operational card | Add a local path in a new optional app-runtime chapter |
| Run the Streamlit app inside the sandbox | Missing | Add a sandbox path with the correct bind address and port |
| List/stop Streamlit processes in the sandbox | Missing | Add process inspection, preferred single-PID stop, and clearly warned all-Streamlit stop |
| Publish and unpublish a sandbox port | Missing | Add `sbx ports` publish/list/unpublish steps and explain host-port versus sandbox-port order |
| Copy a one-off file from host to sandbox | Missing; cheatsheet marks it as uncertain | Add only with verified `sbx cp` syntax, explicit source/destination checks, and a post-copy verification step |
| Copy generated artifacts from sandbox to host | Already implemented in depth | Preserve; remove local-machine-specific examples and integrate with the two-way transfer explanation |
| Give the agent a bug-reproduction/Playwright prompt using a copied image | Missing | Add as a real prompt card, with no shell tabs |
| Read a sandbox file with `cat` or `less` | Missing | Add non-paginated and interactive-pager variants; ensure `less` receives a TTY |
| Force local default branch to exactly match `origin/main` and delete untracked files | Missing | Add only as an explicitly destructive recovery path under Troubleshooting, never as the ordinary update routine |
| Refresh the sandbox clone from GitHub with status/branch/remotes and `pull --ff-only` | Partially covered by generic Daily Dev Git commands, but not clearly scoped to commands running inside the sandbox clone | Add a dedicated sandbox-clone refresh routine and connect it to Daily Dev startup guidance |

### 3.3 Local-machine- and Projexcellent-specific reference audit

The distributable must derive project, repository, sandbox, and host-path references from the Project context rather than embedding values from the machine and project used to test the checklist.

There is no literal `rensm` occurrence in the current repository content inspected for this plan. The distributable HTML does contain eight occurrences of the likely intended username marker, `rmeer`:

- two initial Project context input values;
- two Windows path defaults in `PLATFORM_DEFAULT_PATHS`;
- two matching initial values in the `fields` object;
- one observed Playwright artifact path;
- one concrete `tar` example using the same machine path.

The distributable also contains Projexcellent-specific values in several contexts:

- `projexcellent-app` as the visible and JavaScript default for both Project folder and Repository name;
- `projexcellent-codex` as the visible and JavaScript default for Docker Sandbox name;
- prose and expected-output examples in the artifact chapter;
- a concrete artifact path and `tar` command combining the test username, project folder, sandbox name, dated run folder, and generated video identifier.

The required replacement rule is contextual:

| Hard-coded test value represents | Replacement in commands/prose | Neutral initial Project context value |
|---|---|---|
| Local project directory name | `{projectName}` | `my-project` |
| Git hosting repository name | `{repoName}` | `my-project` |
| Docker Sandbox name | `{sandboxName}` | `my-project-codex` |
| Host-side project path | Compose from `{parentNative}` or `{parentPosix}` plus `{projectName}` | `C:\Users\your-name\CodeLibrary` and `/mnt/c/Users/your-name/CodeLibrary` |
| Host Git remote exposed by clone mode | `sandbox-{sandboxName}` | Derived; never hard-coded |
| Artifact run folder or filename | Generic relative placeholder or a Project-context-derived path | No real dated run or generated identifier |

This replacement must be semantic rather than a blind text substitution. For example, a repository URL needs `{repoName}`, an `sbx` command needs `{sandboxName}`, and a local `cd` command needs a parent-path field plus `{projectName}`.

Absolute paths are acceptable only when they are environment-owned, generic, and explained, such as `/tmp`, `/run/sandbox/source`, or a deliberately generic example such as `C:\path\to\old-repo` behind the `oldRepoPath` Project context field. User-project file references must not contain a real username, drive path, project name, run ID, or generated filename.

The cleanup target is the distributed/user-facing material and any canonical source that is embedded into it. `personal-cheatsheet.md` and `add-sandbox-artifact-extraction-workflow.md` are personal/historical inputs and should remain unchanged unless the user separately asks to generalize those source notes. The final audit must report remaining personal references outside the distributable so this distinction remains explicit.

### 3.4 Chapter “why” audit

The current checklist is generally strong at explaining individual commands through “what it does,” “why you do it,” expected output, and suspicious output. The weaker area is chapter-level orientation: several chapters tell the reader what to do without first explaining why this way of working is useful, what alternative exists, or why a more elaborate stack is justified.

Use the following standard for every chapter opening:

1. **Purpose:** what problem this chapter prevents or solves.
2. **When it applies:** which project situations make the chapter relevant.
3. **Trade-off or alternative:** what simpler or different path exists and why the user might choose it.
4. **Outcome:** what capability or safe state the user has after completing it.

The opening rationale should not repeat every command. It should give the reader a mental model that lets them make a deliberate choice.

| Chapter | Current clarity of “why” | Planned improvement |
|---|---|---|
| `0. Choose Your Working Stack` | Partial | Explain that platform and shell mainly change command syntax, Git hosting changes collaboration/policy, and the application stack changes development speed, flexibility, testing needs, and deployment complexity. Add a “choose the smallest useful stack” decision guide. |
| `1. Create Folder And Initialize Git` | Partial | Explain why a clean project boundary and version history should exist before app code, dependencies, or agent work are introduced. |
| `2. Connect Remote And Choose Default-Branch Policy` | Mostly clear | Add a plain distinction between local Git and a hosted remote. Explain that GitHub versus Azure DevOps is usually an organization/collaboration choice, not a Python or framework choice, and summarize the safety-versus-friction trade-off of branch protection. |
| `3. Add Starter Files` | Partial | Explain why the starter script and agent guidance must be present before generation: the script creates structure, `AGENTS.md` supplies durable rules, and `AGENTS_INIT.md` supplies the first-session handoff. |
| `4. Run The Starter Script` | Needs expansion | Add the main stack-choice decision guide: base shell versus standalone HTML prototype versus Streamlit POC versus React MVP versus deployment-oriented structure versus redesign from archive. Explain prototype/POC/MVP goals and the cost of choosing more structure too early. |
| `5. Create Runtime Environment Only When Relevant` | Mostly clear | Add a conceptual comparison: standalone HTML has no dependency runtime, Python uses a per-project virtual environment, and Node projects derive dependencies from the actual app scaffold/package manifest. |
| `6. Confirm Ignored And Private Files` | Mostly clear | Clarify that `.gitignore` prevents accidental versioning but is not encryption or access control. Explain why the check happens before the first commit. |
| `7. Make The Baseline Commit` | Clear | Preserve the current rationale and add one concise chapter-level statement that the baseline is a known-good comparison and rollback point before agent changes. |
| `8. Start The Agent` | Partial | Explain why the agent starts only after repository boundaries, privacy rules, and a baseline exist, and why context gathering/planning should precede implementation. |
| `A. Tool And Account Setup Helpers` | Partial | Explain that users should check only tools required by the chosen path; installing every optional tool adds maintenance and failure modes. Distinguish “installed,” “available in this shell,” and “authenticated.” |
| `B. Optional: Docker Sandbox` | Partial | The isolation benefit is stated, but add when local work is simpler, when sandbox isolation is worth the overhead, and how direct mode differs from clone mode. |
| `C. Retrieve Generated Artifacts` | Clear | Preserve the “when to use this” rationale; add why large/generated evidence usually belongs outside Git and why retrieval must happen before sandbox removal. |
| New Streamlit runtime chapter | Not yet present | Explain local execution as the simplest feedback loop and sandbox execution as stronger environment isolation with extra networking/process-management steps. |
| `D. Playwright` | Partial | Explain why browser-level testing catches integration/user-flow problems that unit tests cannot, and when manual checking is enough for a tiny prototype. |
| `E. Spec Kit Workflow` | Clear | Preserve its existing use/skip guidance and checkpoints. |
| `F. Context7` | Needs expansion | Explain that fast-moving library APIs can be newer than an agent’s built-in knowledge; Context7 supplies current documentation but does not replace reading the repository or testing behavior. |
| `G. Troubleshooting And Git Hygiene` | Partial | Explain diagnostic-first recovery: inspect state before changing it, prefer reversible actions, and reserve cleanup commands for a known symptom. |
| `I. Get Started` | Partial | Explain why daily work begins from the latest shared state and why a feature branch isolates one task. Add the practical local-VS-Code versus Docker-Sandbox trade-off. |
| `II. Keep Committing` | Mostly clear | Add why small logical commits improve review, rollback, and agent handoff; clarify staging versus committing and why file location changes the Git handoff. |
| `III. Finish Clean` | Mostly clear | Explain why push, PR, merge, and local default-branch refresh close the work loop and prevent the next task from starting on stale history. |

The target audience should not be expected to know that “more tooling” is not automatically “more professional.” The checklist should repeatedly favor the lightest workflow that meets the actual goal and state what additional capability justifies each extra layer.

## 4. Current Docker Documentation Baseline

Because Docker Sandbox is changing quickly, implementation should re-check command syntax against primary Docker documentation immediately before editing. The following official pages were checked while producing this plan on 2026-07-22:

- CLI overview: <https://docs.docker.com/reference/cli/sbx/>
- `sbx exec`: <https://docs.docker.com/reference/cli/sbx/exec/>
- `sbx cp`: <https://docs.docker.com/reference/cli/sbx/cp/>
- `sbx ports`: <https://docs.docker.com/reference/cli/sbx/ports/>
- Day-to-day usage and clone-mode behavior: <https://docs.docker.com/ai/sandboxes/usage/>
- Git and local-service workflow patterns: <https://docs.docker.com/ai/sandboxes/workflows/>

Important implementation consequences from the current documentation:

- `sbx exec -it {sandboxName} bash` is the supported interactive-shell form.
- `sbx cp` supports host-to-sandbox and sandbox-to-host copies; exactly one side must use `SANDBOX:PATH` notation.
- `sbx ports {sandboxName} --publish HOST_PORT:SANDBOX_PORT` and the matching `--unpublish` form are supported.
- Clone mode does not automatically create a feature branch; the clone starts from the host ref that was checked out when the sandbox was created.
- The host remote is named `sandbox-<sandbox-name>` by the CLI, which means this checklist’s `sandbox-{sandboxName}` convention is appropriate.
- The sandbox must be running for the host to fetch its sandbox remote.
- Removing a clone-mode sandbox destroys its private clone, so wanted commits must be fetched or pushed before removal.

These are documentation baselines, not a substitute for verification against the installed `sbx` version. Where helpful, the checklist should tell the user to run `sbx version`, `sbx --help`, or a subcommand’s `--help` before relying on newer options.

## 5. Proposed Information Architecture

Avoid placing every new command in the already long Docker Sandbox setup chapter. Organize the content by user intent:

1. Begin every chapter with a short rationale that covers purpose, applicability, trade-off/alternative, and intended outcome. Keep command-specific explanations where they already exist.
2. Expand Chapter 0 and the starter-profile choice into the main conceptual map for users who know one Python workflow but do not yet know how to choose among HTML, Streamlit, React, local work, sandboxed work, and deployment-oriented structure.
3. Keep `B. Optional: Docker Sandbox` focused on the model, setup, direct shell use, clone-mode Git behavior, and deciding whether to use a shell or Codex.
4. Add a new optional chapter immediately after it: `C. Optional: Run A Streamlit App Locally Or In Docker Sandbox`.
5. Retitle the current artifact chapter to cover two-way transfer, or add a concise host-to-sandbox subsection at its start. A suitable title is `D. Optional: Transfer Files And Retrieve Sandbox Artifacts`.
6. Renumber later Extras chapters consistently if the new chapter is inserted:
   - Playwright becomes `E`;
   - Spec Kit becomes `F`;
   - Context7 becomes `G`;
   - Troubleshooting becomes `H`.
7. Keep the Daily Dev book concise. Add a short, clearly sandbox-scoped refresh/handoff path there and point to the richer Extras explanations instead of duplicating all operational detail.

If renumbering creates unnecessary review noise, the fallback is to append the runtime chapter after the existing artifact chapter and adjust only later letters. Whichever option is chosen, chapter order and navigation labels must remain internally consistent.

## 6. Ordered Implementation Tasks

### Task 1: Re-verify command semantics and establish safe copy text

Before changing the HTML:

1. Check the installed CLI, when available, with:
   - `sbx version`
   - `sbx exec --help`
   - `sbx cp --help`
   - `sbx ports --help`
2. Compare the output with the official documentation links in Section 4.
3. Record any installed-version differences in implementation notes.
4. Prefer commands supported both by the current docs and the user’s actual CLI.
5. Do not preserve a cheatsheet command merely because it was used once if the current CLI documents a safer or clearer form.

Acceptance condition: every new `sbx` command has a verified syntax source or an explicit “check your installed version” note.

### Task 2: Remove machine-specific and run-specific references from the distributable

Make the standalone file safe to share before adding more examples.

1. Replace all Windows user-folder defaults in three synchronized locations:
   - the visible `parentNative`/`parentPosix` input values;
   - `PLATFORM_DEFAULT_PATHS.windows`;
   - the matching initial entries in `fields`.
2. Use neutral placeholders such as:
   - `C:\Users\your-name\CodeLibrary`
   - `/mnt/c/Users/your-name/CodeLibrary`
3. Replace Projexcellent-derived Project context defaults in all synchronized locations:
   - Project folder: use neutral initial value `my-project`;
   - Repository name: use neutral initial value `my-project`;
   - Docker Sandbox name: use neutral initial value `my-project-codex`;
   - GitHub owner: use `YOUR-GITHUB-OWNER` unless an intentional workshop default is explicitly approved.
4. Replace every Projexcellent-derived use outside the Project context form according to meaning:
   - local folder/path references use `{projectName}` plus `{parentNative}` or `{parentPosix}`;
   - hosting-service repository references use `{repoName}`;
   - sandbox commands and prose use `{sandboxName}`;
   - clone-mode host remote references use `sandbox-{sandboxName}`.
5. Replace the concrete artifact path with field-driven or documented generic placeholders such as:
   - `{PROJECT_DIR}`
   - `{RELATIVE_ARTIFACT_FOLDER}`
   - `{ARTIFACT_NAME}`
6. Replace the dated validation folder and generated Playwright filename with generic examples.
7. Preserve intentional TeamNL branding unless the user separately asks to change branding behavior.
8. Run a case-insensitive scan of the distributable and any embedded/canonical user-facing source for:
   - `rensm`
   - `rmeer`
   - `projexcellent`
   - concrete `C:\Users\...` identities
   - `C:/Users/...` identities
   - `/mnt/c/Users/...` identities
   - `/c/Users/...` identities
   - dated run folders and generated artifact hashes
9. Classify every remaining absolute path:
   - Project-owned path: must be assembled from Project context fields;
   - generic environment-owned path such as `/tmp` or `/run/sandbox/source`: may remain, but must be explained;
   - historical/personal input outside the distributable: report it without silently rewriting the source note.
10. Exercise each Project context field with a second, unrelated project name and sandbox name to prove copied commands no longer depend on Projexcellent.

Acceptance condition: the distributable contains no case-insensitive `projexcellent`, `rensm`, or `rmeer` occurrence; no real username or local project path remains; and every project/repository/sandbox reference renders from the correct Project context field.

### Task 3: Add chapter-level rationale and stack-choice guidance

Implement the audit in Section 3.4 before adding more operational cards so new and existing chapters follow the same teaching model.

1. Add or revise the first note in every chapter so it answers:
   - Why does this chapter exist?
   - When should the user use it?
   - What simpler/different alternative exists?
   - What safe capability or state will the user have afterward?
2. Keep each rationale compact. Aim for one short card or two short paragraphs, not a second tutorial before the commands.
3. Preserve the existing command-level `explain()` and `gitExplain()` content. Chapter rationale supplies the mental model; command explanations supply execution detail.
4. Expand Chapter 0 with a plain-language map of four independent decisions:
   - host platform and shell determine command syntax;
   - Git hosting determines where collaboration, backup, policies, and pull requests live;
   - app/runtime stack determines how quickly the idea can be built versus how much flexibility and deployment structure it has;
   - local versus Docker Sandbox work determines simplicity versus isolation.
5. Add a starter-profile decision guide:
   - **Base shell:** choose when the problem and app surface are not decided, or when only docs/scripts are needed.
   - **Standalone HTML prototype:** choose for a fast, shareable visual interaction with no backend/runtime requirement.
   - **Streamlit proof of concept:** choose when Python/data logic needs a quick interactive UI and a custom product frontend is not yet justified.
   - **React MVP with Playwright:** choose when product-like browser behavior, richer UI control, and repeatable browser tests justify more tooling.
   - **React with Azure/Docker structure:** choose only when deployment/operations requirements are real enough to shape the repo.
   - **From archive:** choose when old work supplies ideas or data but should not dictate the new architecture.
6. Define prototype, proof of concept, and MVP in terms of the question being answered:
   - prototype: “Can people understand and react to the interaction?”
   - proof of concept: “Can the important logic/data flow work?”
   - MVP: “Can a small real product be operated and extended responsibly?”
7. Add explicit local-versus-sandbox trade-off language:
   - local is simpler and gives immediate file visibility;
   - sandbox adds isolation and reproducibility but introduces clone, port, process, and transfer concepts.
8. Add the targeted rationale improvements from the Section 3.4 matrix without rewriting chapters already rated clear.
9. Check that optional chapters say when to skip them. Avoid implying that installing every optional tool is a maturity requirement.

Acceptance condition: before copying a command, a user with basic Python experience can explain why the chapter is relevant, why the selected stack/workspace path fits the project, and what complexity the rejected alternatives would add.

### Task 4: Strengthen the “Use the sandbox yourself” workflow

Extend the existing Docker Sandbox chapter instead of recreating its current command cards.

1. Add an `Open an interactive Bash shell` command card:
   - `sbx exec -it {sandboxName} bash`
2. Explain the difference between:
   - `sbx run --name {sandboxName}`: attach to the coding agent;
   - `sbx exec -it {sandboxName} bash`: open a shell for the user;
   - `sbx exec {sandboxName} bash -lc "..."`: run one known command from the host.
3. Add the missing simple Python check, preferably a non-blocking version check rather than dropping a beginner into an interactive REPL:
   - `python3 --version`
   - optionally `python3 -m pytest` when that is the repository’s actual test convention.
4. Convert the existing prose decision into a compact note or decision card:
   - Can an ordinary shell command answer the question?
   - Yes: run it inside the sandbox yourself.
   - No, reasoning is required: ask Codex.
5. Keep the existing `pwd`, `ls`, Git inspection, and test cards. Do not add duplicates with slightly different titles.
6. Add a short warning that commands typed after opening an interactive shell run inside the Linux sandbox, even when the host is Windows.

Acceptance condition: a user can clearly choose agent attach, interactive shell, or one-off execution without confusing those three modes.

### Task 5: Make clone-mode behavior and handoff explicit

Refine the partially implemented clone backlog and align it with current Docker workflow guidance.

#### 5.1 Explain direct mode versus clone mode

Add a short comparison near `Docker Sandbox model`:

- Direct mode: sandbox edits appear in the host working tree immediately; use the ordinary/local Git path.
- Clone mode (`--clone`): sandbox edits stay in a private clone; use the sandbox remote or let the agent push an authorized feature branch.

Also explain that `/run/sandbox/source` is a read-only view of the host repository in clone mode. Do not imply that it is the writable clone.

#### 5.2 Make branch creation inside the clone explicit

The guide must explain that `--clone` starts from the host’s checked-out ref and does not create a feature branch automatically. Before editing, either the user or agent should run inside the sandbox clone:

```text
git status
git branch --show-current
git switch -c {featureBranch}
```

If the feature branch already exists, use `git switch {featureBranch}` instead.

#### 5.3 Add a complete manual handoff path

The preferred manual flow should be:

1. Inside the sandbox, inspect the diff, stage selectively, test, and commit on `{featureBranch}`.
2. Keep the sandbox running.
3. On the host, run `git fetch sandbox-{sandboxName}`.
4. Inspect before integrating:
   - `git log --oneline sandbox-{sandboxName}/{featureBranch}`
   - `git diff {defaultBranch}..sandbox-{sandboxName}/{featureBranch}`
5. If the host feature branch does not yet exist, create it from the sandbox remote branch.
6. If it already exists, switch to it and merge the matching sandbox feature branch after inspection.
7. Push the resulting host feature branch to `origin`.
8. Continue to the existing PR and merge steps in Daily Dev `III. Finish Clean`.

Use the sandbox feature branch as the primary example. Retain the sandbox default-branch candidate only as a clearly labeled fallback for older work that was accidentally committed there.

#### 5.4 Add a complete agent-assisted path

Add a typed prompt card, for example:

```text
Inside this Docker Sandbox clone, inspect the current Git state. Create or switch to {featureBranch}, review the changes, run the relevant tests, and make one or more clean commits. Do not push or open a pull request unless I explicitly authorize it. When finished, tell me the branch name, commit hashes, validation results, and the exact host commands to fetch and inspect sandbox-{sandboxName}/{featureBranch}.
```

Optionally explain the alternative in which an authenticated agent pushes the feature branch and opens the PR directly. Make the authorization and credential requirements explicit; do not silently encourage autonomous pushes.

#### 5.5 Correct lifecycle expectations

Add concise notes that:

- `git fetch sandbox-{sandboxName}` requires the sandbox to be running;
- `sbx stop` preserves the clone but makes its Git daemon unavailable;
- `sbx rm` deletes the clone and removes the host remote;
- wanted work must be fetched or pushed before removal.

Acceptance condition: a semi-technical user can identify where the files live, who creates/commits the branch, how the host reviews it, and when a push or PR occurs.

### Task 6: Add an optional local-versus-sandbox Streamlit runtime chapter

Create a new chapter with a choice group such as `streamlit-runtime-location`:

- `Run locally`
- `Run inside Docker Sandbox`

Only cards for the selected location should be visible.

#### 6.1 Local path

Add shell-specific cards that:

1. change into `{parentNative}\{projectName}` or `{parentPosix}/{projectName}`;
2. activate the appropriate virtual environment where relevant;
3. run:

```text
python -m streamlit run app/streamlit/app.py --server.address 127.0.0.1 --server.port 8502
```

Use the correct activation forms for PowerShell, cmd, and POSIX shells. Do not suggest that a Windows-created virtual environment can be activated as a Linux environment from WSL.

Show `http://127.0.0.1:8502/` in a note or URL card, not as a shell command. This ensures it does not display PowerShell/cmd/Bash tabs.

#### 6.2 Sandbox path

Add the sandbox start command with `{sandboxName}` and the project’s Streamlit entry point. The server must bind to `0.0.0.0` inside the sandbox:

```text
python3 -m streamlit run app/streamlit/app.py --server.address 0.0.0.0 --server.port 8501
```

Prefer an interactive foreground form for beginners so logs remain visible and `Ctrl+C` has an obvious effect. Tell the user to use a second host terminal for port commands. If detached execution is selected during implementation, redirect logs to a known file and add an explicit log-inspection command.

#### 6.3 Port publishing

Add separate command cards to:

1. publish the port:
   - `sbx ports {sandboxName} --publish 8501:8501`
2. list mappings:
   - `sbx ports {sandboxName}`
3. open or copy the browser address:
   - `http://127.0.0.1:8501/`
4. unpublish when finished:
   - `sbx ports {sandboxName} --unpublish 8501:8501`

Explain that the order is `HOST_PORT:SANDBOX_PORT`, the sandbox must be running, and publishing is separate from `sbx run`/`sbx create`.

#### 6.4 Process control

Add sandbox process cards in increasing order of impact:

1. list matching processes with a form that does not list the `grep` command itself;
2. stop one known process with `kill <PID>`;
3. stop all matching Streamlit processes with `pkill -f streamlit` only behind a warning.

State that the PID must be copied from the process list and that `pkill -f streamlit` may stop multiple apps. Do not label the broad kill as the default.

Acceptance condition: the user can start the app in either location, understand why the bind addresses differ, reach a sandboxed app from the host browser, inspect the process, and shut down both process and port mapping cleanly.

### Task 7: Expand file transfer and file inspection guidance

Build on the existing artifact chapter rather than replacing its robust sandbox-to-host workflow.

#### 7.1 Host-to-sandbox one-off copy

Add an ordered, verifiable flow:

1. Confirm the sandbox name with `sbx ls`.
2. Confirm the local source file exists using the selected host shell.
3. Create or confirm a destination directory in the sandbox, preferably under `/tmp` for an ephemeral debugging input.
4. Copy with the documented `sbx cp LOCAL_PATH {sandboxName}:SANDBOX_PATH` form.
5. Verify the destination with `ls -l` or an appropriate file command inside the sandbox.

Use generic file placeholders and quote paths that may contain spaces. Explain that one and only one side of `sbx cp` uses `sandbox:path` notation. Add a warning not to copy secrets, credentials, or private datasets merely to make them visible to the agent.

The cheatsheet’s “doesn’t work?!?” comment should become troubleshooting guidance rather than being copied into the checklist. Likely failure checks should include:

- wrong sandbox name;
- stopped or unavailable sandbox;
- local relative path evaluated from the wrong host folder;
- missing sandbox destination directory;
- shell quoting differences;
- attempting sandbox-to-sandbox copy, which is unsupported.

#### 7.2 Bug reproduction prompt

Add the Playwright reproduction instruction as a `prompt()` card, generalized to the copied sandbox path and `{sandboxName}` context. Preserve the useful requirements:

- inspect the supplied image;
- reproduce before editing;
- use Playwright;
- capture before and after evidence;
- use a 1440 × 900 viewport;
- store outputs under `artifacts/playwright-validation/`;
- report what was changed and how it was validated.

The prompt must show a “prompt” pill and no shell or provider switches.

#### 7.3 Open files inside the sandbox

Add two distinct cards:

- non-paginated output with `cat` for a reasonably sized text file;
- paginated output with `less`, using `-it` so the pager has an interactive terminal.

Use a generic `<path-to-file>` placeholder. Explain `q` to exit `less` and warn that `cat` is unsuitable for very large or binary files.

#### 7.4 Preserve and generalize sandbox-to-host artifact retrieval

Retain the current `find` → `tar` → `sbx cp` → verify → extract workflow. During editing:

- remove the observed real path and run identifier;
- keep the recommendation to package nested artifact folders with `tar`;
- keep the single-file direct-copy alternative;
- keep the warning about committing generated videos/traces;
- make the two directions of `sbx cp` visually obvious.

Acceptance condition: the user can copy in a debug input, verify it, ask the agent to use it, and retrieve outputs without relying on a real machine path.

### Task 8: Add a safe sandbox-clone refresh routine

The cheatsheet’s “Update sandbox Git branch from GitHub” routine should be represented explicitly.

Add a card sequence, likely under Docker Sandbox with a concise pointer from Daily Dev `I. Get Started`:

1. open the interactive shell or use one-off `sbx exec` commands;
2. run `git status`;
3. run `git branch --show-current` and `git branch -vv`;
4. run `git remote -v` and explain that `origin` is the Git hosting remote inside the clone, while `sandbox-{sandboxName}` is the host’s route back into the sandbox clone;
5. fetch `origin`;
6. pull only with `--ff-only` after confirming the active branch and clean working tree;
7. stop and inspect if the branch diverged, the working tree is dirty, or the expected upstream is absent.

Prefer an explicit branch command where the guide knows the intended branch:

```text
git pull --ff-only origin {featureBranch}
```

If a generic `git pull --ff-only` card is retained, explain that it relies on correct upstream tracking. Do not use reset/clean as the automatic answer to an update conflict.

Acceptance condition: a user reconnecting to an existing clone can tell whether it is behind `origin`, update it without an accidental merge commit, and recognize when not to continue.

### Task 9: Add destructive local synchronization as a recovery-only workflow

Do not put `git reset --hard` or `git clean -fd` in the normal Daily Dev startup flow. Add them under the Troubleshooting/Git Hygiene chapter with prominent warnings.

The safe order should be:

1. Inspect:
   - `git status`
   - `git branch --show-current`
   - `git diff`
2. Decide whether anything must be kept. Offer a separate stash/backup path before destruction.
3. Switch to `{defaultBranch}` and fetch `origin`.
4. Explain exactly what will be lost.
5. Reset tracked files only after confirmation:
   - `git reset --hard origin/{defaultBranch}`
6. List untracked files:
   - `git ls-files --others --exclude-standard`
7. Preview cleanup:
   - `git clean -nd`
8. Delete untracked files/directories only as the final, optional step:
   - `git clean -fd`
9. Verify the final state with `git status` and a compact log comparison.

Place the reset and clean operations in separate cards so the user cannot copy one large destructive block by accident. Explain that ignored files are not removed by `git clean -fd`; do not introduce `-x` unless there is a separately approved requirement.

Acceptance condition: the ordinary guide continues to recommend fetch/fast-forward updates, while exact-reset cleanup is available but unmistakably destructive and previewable.

### Task 10: Preserve and regression-test implemented backlog behavior

No new Spec Kit feature work is needed. Instead:

1. Confirm every `prompt()` card still renders without shell/provider mini-tabs.
2. Confirm every real `command()` card still gets only the shells/providers for which it has variants.
3. Ensure the new Playwright reproduction prompt and clone-agent prompt use `prompt()`, not `command()`.
4. Confirm choice-gated cards disappear and reappear correctly when location choices change.
5. Confirm the existing Daily Dev `daily-commit-location` selection continues to control the Docker handoff note in `daily-finish`.
6. Keep the complete Spec Kit sequence unchanged unless a concrete rendering/copy defect is found.

If new requirements need a card to depend on two independent choices, do not overload the existing single `choiceGroup` field silently. Either structure the chapter so one choice is sufficient or deliberately add and test a small multi-condition visibility model. Avoid expanding the rendering model unless the UX materially needs it.

Acceptance condition: already-completed backlog work does not regress while the new commands are added.

### Task 11: Validate the standalone artifact

Validation should be proportional to a 4,000+ line standalone HTML file with embedded JavaScript.

#### Static checks

1. Parse or compile the inline JavaScript to catch syntax errors.
2. Check for duplicate section IDs, duplicate DOM IDs generated from cards, and duplicate choice-group option values.
3. Assert that the distributable has zero case-insensitive matches for `projexcellent`, `rensm`, and `rmeer`.
4. Search for remaining concrete Windows/WSL user paths, personal project paths, dated run folders, and generated artifact identifiers.
5. Classify remaining absolute paths as Project-context-derived or intentionally environment-owned.
6. Search for every new command string and confirm it appears exactly where intended.
7. Verify no external scripts, stylesheets, fonts, or runtime assets were introduced.
8. Confirm `src/` and embedded downloads are unchanged, or prove they were synchronized if a source change became necessary.

#### Browser/manual checks

Open the HTML directly from disk and check at desktop and narrow widths:

1. Start-up, Extras, and Daily Dev books all render.
2. Navigation chapter letters and titles match their content.
3. Local/sandbox choices show only the intended cards.
4. Copy buttons substitute `{sandboxName}`, paths, branches, and project values correctly.
5. Prompt cards have no shell tabs and copy exactly the prompt text.
6. Command cards switch correctly among PowerShell, cmd, and Bash/WSL.
7. Browser URLs are presented as URLs/notes rather than fake shell commands.
8. Long `sbx exec ... bash -lc` commands wrap or scroll without breaking the card layout.
9. Progress state, skipped/finished state, chapter folding, unfinished navigation, and reset still work.
10. The file still functions when copied away from the repository and opened without `assets/` or network access.
11. Replace the Project folder, Repository name, and Docker Sandbox name with unrelated test values and confirm each copied path, remote URL, `sbx` command, and clone remote uses the correct field.
12. Read every chapter opening in sequence and confirm it explains purpose, applicability, trade-off/alternative, and outcome without requiring prior stack-selection knowledge.
13. Confirm optional chapters make it clear that skipping an unnecessary tool is a valid deliberate choice.

#### Command smoke checks

Where a disposable sandbox is available, test non-destructively:

1. interactive `sbx exec -it` shell;
2. one-off `pwd` and `git status`;
3. a temporary host-to-sandbox copy and verification under `/tmp`;
4. a temporary sandbox-to-host copy;
5. port publish/list/unpublish using a harmless temporary server;
6. process listing and single-PID termination.

Do not smoke-test `git reset --hard`, `git clean -fd`, broad `pkill`, or sandbox removal against a repository/sandbox containing wanted work.

## 7. Suggested Review and Commit Boundaries

Keep implementation reviewable with logical checkpoints:

1. **Genericize distributable defaults and examples**
   - machine/path and Projexcellent cleanup only;
   - verify Project folder, Repository name, and Docker Sandbox name substitution;
   - no new chapters yet.
2. **Add chapter rationale and stack-choice guidance**
   - expand the Chapter 0 mental model;
   - add the starter-profile decision guide;
   - add concise “why/when/alternative/outcome” orientation where the audit found gaps.
3. **Improve Docker shell and clone-mode guidance**
   - interactive shell;
   - direct-vs-clone explanation;
   - manual and agent handoff;
   - clone lifecycle notes.
4. **Add Streamlit runtime and port/process controls**
   - new location choice and chapter;
   - local/sandbox run paths;
   - port and process management.
5. **Add two-way file transfer and sandbox file viewing**
   - host-to-sandbox copy;
   - prompt card;
   - `cat`/`less`;
   - generalized existing artifact examples.
6. **Add Git refresh and destructive recovery guidance**
   - safe sandbox refresh;
   - guarded host reset/clean workflow.
7. **Regression and standalone validation**
   - prompt tabs;
   - choices;
   - copy substitution;
   - inline JavaScript;
   - direct-file portability.

The user may prefer one final commit, but these boundaries should still be used as review checkpoints even if the work is eventually squashed.

## 8. Final Acceptance Criteria

Implementation is complete when all of the following are true:

- Every useful cheatsheet topic is either represented in the standalone guide or explicitly excluded for a documented safety/portability reason.
- A user can distinguish agent attachment, interactive shell access, and one-off command execution.
- A user can run the Streamlit app locally or in the sandbox and reach the sandbox app through a published port.
- Process listing, single-process termination, broad termination, port unpublishing, and server shutdown are explained in increasing order of impact.
- One-off file transfer works in both directions with verification steps and generic paths.
- File viewing with `cat` and interactive `less` is copy-ready.
- Clone mode explains where files live, how branches and commits are created, how the host fetches/reviews them, and when an agent may push/open a PR.
- Existing Daily Dev local-versus-sandbox handoff remains functional and consistent with the expanded clone explanation.
- Safe fast-forward refresh is the normal update path; reset/clean appears only as warned recovery guidance.
- The Spec Kit workflow remains complete.
- Suggested agent prompts never show shell/provider tabs.
- Every chapter explains why it exists, when it applies, what simpler/different alternative exists, and what outcome it provides.
- A user who previously knew only one Python workflow can deliberately choose among base, standalone HTML, Streamlit POC, React MVP, deployment-oriented structure, local work, and sandbox work.
- The distributable contains no case-insensitive `projexcellent`, `rensm`, or `rmeer` occurrence and no real username, local project path, dated personal run path, or generated personal artifact identifier.
- Project paths use Project folder plus the relevant parent-path field, repository references use Repository name, and sandbox commands use Docker Sandbox name.
- The HTML remains a standalone, dependency-free file and works when opened directly from disk.
- Existing user edits to `backlog.txt` and `personal-cheatsheet.md` are preserved.

## 9. Known Risks and Mitigations

- **Risk: the Extras book becomes too long.** Mitigation: group by user intent, use location choices, and avoid duplicating existing cards.
- **Risk: users confuse host commands with sandbox commands.** Mitigation: name the execution location in every card title and explanation; use `sbx exec` wrappers where ambiguity remains.
- **Risk: destructive Git commands look like normal maintenance.** Mitigation: isolate them in Troubleshooting, add preview/backup steps, and split destructive commands into separate cards.
- **Risk: foreground app commands block the terminal.** Mitigation: explicitly instruct use of a second host terminal; if detached mode is chosen, provide log and shutdown commands.
- **Risk: `sbx` behavior changes.** Mitigation: cite official pages, check installed help output, and use placeholders rather than observed machine paths.
- **Risk: new prompt cards accidentally receive shell tabs.** Mitigation: construct them only with `prompt()` and include a rendering regression check.
- **Risk: chapter renumbering creates broken navigation or stale copy.** Mitigation: update section titles in one pass and validate every Extras navigation entry.
- **Risk: clone-mode guidance encourages premature pushing.** Mitigation: make host fetch/review the default and require explicit authorization for agent push/PR actions.
- **Risk: genericization substitutes the wrong context field.** Mitigation: classify each occurrence by meaning and test with deliberately different Project folder, Repository name, and Docker Sandbox name values.
- **Risk: chapter rationale makes the guide repetitive or patronizing.** Mitigation: keep one compact mental-model card per chapter, preserve command-level detail separately, and focus on trade-offs the target user cannot infer from syntax alone.

## 10. Post-Approval Implementation Plan

After the user approves this document, execute the work in the following order. Approval authorizes the checklist edits and validation described here; it does not authorize committing, pushing, opening a pull request, changing branding, or changing downstream starter-file policy.

### Phase 0: Freeze scope and establish a baseline

1. Re-read `AGENTS.md` and the approved version of this plan.
2. Inspect `git status` and preserve the user’s existing edits to `backlog.txt` and `personal-cheatsheet.md`.
3. Record a focused pre-change inventory of:
   - all section IDs/titles;
   - all Project context fields and their duplicate JavaScript defaults;
   - every case-insensitive Projexcellent/username occurrence in the distributable;
   - prompt rendering and choice visibility behavior;
   - embedded download checksums or exact source comparison where practical.
4. Re-verify current `sbx exec`, `sbx cp`, `sbx ports`, and clone-mode behavior from installed help and official documentation.

Deliverable: a known baseline and no ambiguity about which existing changes belong to the user.

### Phase 1: Make the distributable generic

1. Implement Task 2 as an isolated edit.
2. Replace Project context defaults and contextual Projexcellent uses.
3. Generalize artifact examples and classify every remaining absolute path.
4. Test with intentionally different values, for example:
   - Project folder: `sample-ui`;
   - Repository name: `sample-ui-repository`;
   - Docker Sandbox name: `sample-ui-sandbox`.
5. Confirm the three values do not leak into one another and that the distributable has zero `projexcellent`, `rensm`, or `rmeer` matches.

Deliverable: a portable standalone checklist before any content expansion.

### Phase 2: Add the conceptual “why” layer

1. Implement Task 3 across existing chapters.
2. Start with Chapter 0 and the starter-profile choice because they provide terminology reused later.
3. Add only targeted rationale cards identified in Section 3.4; preserve chapters already rated clear.
4. Read the Start-up book from beginning to end as a user who knows Python but not stack trade-offs.
5. Read Extras and Daily Dev independently so their rationales still make sense when users open those books directly.

Deliverable: users can choose a path intentionally before encountering its commands.

### Phase 3: Refine existing Docker and Daily Dev workflows

1. Implement Tasks 4 and 5:
   - interactive shell versus agent attach versus one-off execution;
   - direct versus clone mode;
   - feature-branch creation inside the clone;
   - manual and agent-assisted handoff;
   - sandbox lifecycle constraints.
2. Reconcile the expanded explanation with the existing `daily-commit-location` workflow.
3. Make the sandbox feature branch the primary path and the sandbox default branch a clearly labeled recovery/fallback case.
4. Avoid duplicating long handoff instructions between Extras and Daily Dev.

Deliverable: one internally consistent clone-mode model across both books.

### Phase 4: Add missing operational workflows

1. Implement Task 6: local/sandbox Streamlit runtime, port publishing, and process control.
2. Implement Task 7: two-way file transfer, bug-reproduction prompt, file viewing, and generalized artifact retrieval.
3. Implement Task 8: safe refresh of an existing sandbox clone from `origin`.
4. Implement Task 9: guarded host reset/clean recovery under Troubleshooting.
5. Renumber Extras chapters once, after the final chapter order is settled.

Deliverable: all useful cheatsheet operations have a safe, intent-based home.

### Phase 5: Regression and standalone validation

1. Implement Task 10’s prompt/choice regression checks.
2. Run every static, browser/manual, substitution, and safe smoke check in Task 11.
3. Copy the HTML to a temporary directory and open/test it without repository siblings or network access.
4. Compare `src/` with embedded downloads and confirm no synchronization was needed, or synchronize deliberately if scope changed.
5. Review the final diff by chapter and verify that unrelated styling, branding, starter policy, and user-owned files did not change.

Deliverable: evidence that the HTML is generic, understandable, behaviorally intact, and still standalone.

### Phase 6: Handoff for user review

Provide:

1. a concise summary of changed chapters and behaviors;
2. the final Projexcellent/personal-path scan result;
3. the Project context substitution test result;
4. JavaScript/static validation results;
5. manual browser and standalone portability results;
6. any command that could not be safely smoke-tested;
7. any remaining decision that would change branding, starter policy, or downstream files.

Stop after the handoff unless the user separately asks to commit, push, or publish the changes.
