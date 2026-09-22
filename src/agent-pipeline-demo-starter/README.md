# Local builder/reviewer agent pipeline

Starter version: **1.1.0** (also recorded in `VERSION`).

This starter creates a deliberately small JavaScript project plus a local Git-backed agent pipeline:

- you commit a Markdown task from the `control` checkout;
- a Claude builder receives that exact instruction commit in its own checkout;
- Claude implements, tests, and commits the work;
- a Codex reviewer receives the exact implementation commit in a separate checkout;
- Codex reviews, tests, and commits only `reviews/TASK-xxxx.md`;
- the pipeline stops there. A failed review does **not** call the builder again.

The two agent workspaces are ordinary host-visible folders. Docker Sandbox isolates their runtime environments, while direct mounts keep source, test output, screenshots, and other artifacts easy to inspect.

## Resulting layout

Running the initializer creates:

```text
agent-pipeline-demo/
├── origin.git/   # local bare Git remote; only the host dispatcher writes here
├── control/      # your checkout and pipeline scripts
├── builder/      # direct-mounted into the Claude sandbox
├── reviewer/     # direct-mounted into the Codex sandbox
├── logs/         # complete agent transcripts
└── state/        # dispatcher progress, outside Git
```

The agents cannot reach `origin.git` from their direct-mounted workspaces. They commit locally; the host dispatcher validates each commit before pushing it to the bare remote.

## Prerequisites

- Windows PowerShell 5.1 or PowerShell 7
- Git
- Docker Desktop with Docker Sandboxes (`sbx`)
- access to Claude Code and Codex

Authenticate once on the host:

```powershell
sbx secret set anthropic
sbx secret set openai --oauth
```

Docker documents `sbx run claude <project>` and `sbx run codex <project>` as the supported launches. The starter uses Claude print mode and Codex `exec` mode so each job exits when it is done.

## 1. Create the demo

From the extracted starter directory:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
./Initialize-Demo.ps1 -Destination "$HOME/CodeLibrary/agent-pipeline-demo"
```

The destination must not already exist. The script creates the bare remote and all three checkouts, then makes and pushes the initial commit.

## 2. Start the dispatcher

Keep this running in one PowerShell window:

```powershell
cd "$HOME/CodeLibrary/agent-pipeline-demo/control"
./automation/Start-AgentPipeline.ps1
```

Stop it with `Ctrl+C`. Restarting is safe: processed commits are remembered in `../state/processed-commits.txt`.

## 3. Submit the example task

In a second PowerShell window:

```powershell
cd "$HOME/CodeLibrary/agent-pipeline-demo/control"
Copy-Item ./examples/TASK-0001-add-multiply.md ./builder-instructions/TASK-0001-add-multiply.md
./automation/Submit-Task.ps1 -Path ./builder-instructions/TASK-0001-add-multiply.md
```

That helper pulls the latest reviewed state, verifies that the task file is the only pending change, commits it with machine-readable trailers, and pushes it.

The dispatcher then performs:

```text
instruction commit
  -> Claude builder
  -> validated build-complete commit
  -> Codex reviewer
  -> validated review-complete commit
  -> stop / human decision
```

## 4. Inspect the result

After the reviewer finishes:

```powershell
cd "$HOME/CodeLibrary/agent-pipeline-demo/control"
git pull --ff-only
Get-Content ./reviews/TASK-0001.md
git log --format=full -5
```

Agent transcripts are in the top-level `logs` directory. The builder and reviewer folders remain ordinary visible checkouts, so any generated artifacts are directly accessible.

## Writing another task

Copy the example, give it a new ID, and make the requirements and acceptance criteria concrete. Keep the instruction immutable after submission; create a new task if requirements materially change.

Each task filename must begin with a unique ID such as `TASK-0002` and live under `builder-instructions/`.

```powershell
Copy-Item ./examples/TASK-0001-add-multiply.md ./builder-instructions/TASK-0002-something.md
# Edit the new file, including its front-matter id.
./automation/Submit-Task.ps1 -Path ./builder-instructions/TASK-0002-something.md
```

Submit only one task at a time in this first version. Wait for its review commit, then pull before submitting the next task.

## Protocol

The dispatcher routes commits by Git trailers:

| Event | Required trailers | Action |
|---|---|---|
| `instruction` | `Task-ID`, `Task-File` | Run builder |
| `build-complete` | `Task-ID`, `Task-File`, `Instruction-Commit` | Run reviewer |
| `review-complete` | `Task-ID`, `Instruction-Commit`, `Implementation-Commit`, `Verdict` | Record only; never re-run builder |

The builder must make exactly one clean commit and cannot change task instructions, reviews, agent rules, or pipeline automation. The reviewer must also make exactly one clean commit, and its diff may contain only `reviews/<Task-ID>.md`. The host reads job prompts from the separate control checkout. Violations stop the dispatcher before the commit is published.

## Deliberate limitations

This is a local learning scaffold, not a production queue:

- one dispatcher and one task at a time;
- a local bare remote rather than GitHub/GitLab;
- no automatic retry or review-to-builder loop;
- no notification service;
- agents run with broad permissions inside Docker Sandbox, but only against their dedicated direct-mounted checkout.

These constraints keep the failure modes visible. Once the protocol feels trustworthy, the natural next step is replacing the local poller with CI or a small durable queue.

## Validation profiles and frozen specifications

`template/agent-pipeline.config.json` is copied into the generated project. Humans
review and commit profile changes before submitting a task. The dispatcher reads
configuration and task metadata from the instruction commit, never from task-provided
shell commands or an uncommitted configuration. The reviewer resolves the same snapshot.
Agents execute the selected checks in their separate checkouts; the host only routes
jobs and validates Git results. Builders cannot modify the pipeline configuration.

Tasks use simple single-line, unquoted front-matter values:

```yaml
validation-profile: default
spec-path:
spec-commit:
```

Omitting `validation-profile` selects `default` (`npm test`), preserving old task files.
`web-ui` selects `npm test` and `npx playwright test`. Before using it, prepare a real
web project with a committed Playwright development dependency and configuration,
including application startup, and install browser binaries in **both** environments.
The calculator demo intentionally has no Playwright dependency. Generated reports,
traces and screenshots belong in ignored `test-results/` or `playwright-report/`.
Inspect them in each agent workspace before the next run: synchronization cleans
ignored files. The reviewer records commands, outcomes and artifact paths. Required
checks that fail or cannot run prevent PASS; human action is required.

The `examples/` directory contains default, web-ui and spec-reference tasks. Supply
both spec fields or leave both empty. Use a repository-relative forward-slash path
with letters, digits, dots, underscores and hyphens, and a full Git commit hash, not
a branch name. Traversal, absolute paths, symlinks, directories and missing files
are rejected. The spec commit must be an ancestor of the instruction snapshot. Commit the spec on
main before submission so both clones receive it.
Agents read `git show <spec-commit>:<spec-path>`, not a potentially changed working
copy. The committed task remains the routing and authority document: report any
spec conflict and follow the task instruction.

## Optional Context7

Context7 supplies current framework documentation to agents; it is not an application
dependency. Each sandbox has its own agent home, authentication and MCP configuration.
Host configuration alone does not prove availability inside either sandbox.

For a manual OAuth setup, run these in the respective agent environments, outside
an active pipeline job:

```sh
# Claude environment; authenticate using /mcp in an interactive Claude session.
claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp/oauth
# Codex environment
codex mcp add context7 --url https://mcp.context7.com/mcp/oauth
codex mcp login context7
```

If using an API key instead, keep it in a secret store/environment, never in Git or
task Markdown. For Codex, a user-level `~/.codex/config.toml` entry can reference it:

```toml
[mcp_servers.context7]
url = "https://mcp.context7.com/mcp"
bearer_token_env_var = "CONTEXT7_API_KEY"
```

In each interactive agent session, inspect `/mcp` and request a small documentation
lookup, for example “use Context7 to find documentation for the framework version in
this repository.” Confirm tools such as `resolve-library-id` and `query-docs` actually
work; registration alone is not a connection test. Context7 failure alone must not
determine a review verdict. Repository contents and deterministic tests remain
authoritative. The dispatcher never installs Context7 or writes private configuration.

Sources (checked 2026-09-22): [Context7 MCP clients](https://context7.com/docs/resources/all-clients),
[Claude Code guidance](https://context7.com/docs/clients/claude-code), and
[OpenAI MCP configuration](https://developers.openai.com/codex/mcp).

## Optional Spec Kit upstream workflow

Use Spec Kit for larger or ambiguous features; a small exact task needs no extra
planning tool. With Python 3.11+ and uv installed, the current official PyPI route is:

```powershell
uv tool install specify-cli
specify version
```

For reproducible installations, choose a published version and pin it (or use the
release-tag source install described in the [official installation guide](https://github.github.io/spec-kit/installation.html)).
Initialize only when ready to review the files it adds to your existing project:

```powershell
# In control, with a clean working tree and the dispatcher stopped:
specify init --here --integration claude --script ps
```

Review any merge prompt and generated files; keep credentials and personal agent
settings outside Git. Run these skills in the planning agent's chat, one at a time,
reviewing each output (invocation syntax may vary by agent integration):

```text
/speckit-constitution
/speckit-specify
/speckit-plan
/speckit-tasks
```

This creates the upstream flow **constitution → specify → plan → tasks → pipeline
submission**. Commit the approved specification artifacts in control and push to the
local origin before creating the task. Record the full hash with `git rev-parse HEAD`.
Copy `examples/TASK-0003-spec-multiply.md`, replace its placeholder `spec-commit` and
`spec-path`, and write concrete acceptance criteria. Submit it with `Submit-Task.ps1`.

For these submissions, the local builder/reviewer pipeline replaces
`/speckit-implement` and `/speckit-converge`; do not run an automatic implementation or
convergence loop alongside it. The dispatcher never invokes Spec Kit. After either
PASS or CHANGES_REQUESTED, a human inspects the report and decides whether to accept
or submit a new immutable task. See the [official workflow](https://github.com/github/spec-kit).

## Troubleshooting and human gates

- **Execution policy:** if local policy permits, use `Set-ExecutionPolicy -Scope Process Bypass`
  in each PowerShell window; it expires with that process. It cannot override organization policy.
- **Wrong directory:** initialize from the extracted starter; start/submit from `control`.
  `origin.git` is a local bare remote, not your GitHub repository.
- **Existing sandbox name:** the dispatcher reuses named sandboxes. Confirm an existing
  sandbox belongs to these exact workspaces, or choose fresh names with
  `-BuilderSandbox my-demo-builder -ReviewerSandbox my-demo-reviewer`.
- **Authentication:** configure Claude/Codex access via the sandbox secret mechanism;
  inspect `../logs/` if a noninteractive job cannot authenticate. Never commit credentials.
- **Failure/retry:** the dispatcher exits and does not mark a failing event processed.
  Inspect logs and preserve useful uncommitted agent files before restarting: checkout
  synchronization resets and cleans the dedicated workspace. Fix the cause, then restart.
  Already published matching events prevent duplicate jobs. Keep
  `../state/processed-commits.txt`; do not routinely delete it to request a retry.
- **Human decision:** pull the review into control and inspect the code, tests and report
  after PASS as well as CHANGES_REQUESTED. PASS is evidence, not automatic acceptance
  or external publication. Create a new task ID for follow-up; never edit submitted instructions.
