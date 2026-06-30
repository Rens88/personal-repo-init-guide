# AGENTS.md

This file is the stable operating manual for AI agents working in this repository.

## Core principle

Build from the current repo standard. Treat archived repositories as source material, not as architecture to preserve.

Old code may contain useful ideas, data examples, UI concepts, or domain logic, but it should not be copied blindly.

## Human-first structure

The folder structure exists so humans can quickly understand the project.

Expected structure:

```text
docs/                 Stable project knowledge: what is true
project-brain/        Evolving memory: how we got here
prototypes/           Disposable explorations and standalone prototypes
app/                  Application entry points and user-facing app shells
src/                  Reusable domain, service, data, and utility code
tests/                Unit, integration, and end-to-end tests
data/example/         Safe sample data that can be committed
data/private/         Local private data; must not be committed
assets/               Images, static files, design assets
scripts/              Developer and automation scripts
infra/                Docker, Azure, and pipeline files
skills/               Repo-owned AI skills or skill drafts
archive/              Old repositories or reference material
```

## Documentation authority

When documents conflict, trust the higher document in this order:

1. `docs/CONSTITUTION.md`
2. `docs/DECISIONS.md`
3. `docs/ARCHITECTURE.md`
4. `docs/USER-STORIES.md`
5. `docs/FEATURES.md`
6. `docs/ROADMAP.md`
7. `docs/RISKS.md`
8. `project-brain/MEMORY.md`
9. `project-brain/AI-NOTES.md`

Important rule:

- `MEMORY.md` is history.
- `DECISIONS.md` is truth.
- `CONSTITUTION.md` overrides everything.

## Document ownership

### Human-governed

`docs/CONSTITUTION.md`

Agents may propose changes, but must not edit it automatically without explicit approval.

### Agent-maintained, human-reviewed

- `docs/DECISIONS.md`
- `docs/ARCHITECTURE.md`
- `docs/USER-STORIES.md`
- `docs/FEATURES.md`
- `docs/ROADMAP.md`
- `docs/RISKS.md`
- `docs/migration-notes.md`

### Agent-maintained memory

- `project-brain/MEMORY.md`
- `project-brain/AI-NOTES.md`
- `project-brain/session-summaries/`

## Maturity levels

Use the lightest structure that fits the goal.

### Rapid prototype

Goal: show or discuss an idea quickly.

Typical folders:

```text
prototypes/html/
assets/
docs/
```

Rules:
- Prefer standalone HTML when speed matters.
- Generated files should go to `prototypes/html/build/`.
- Do not over-engineer.

### Proof of concept

Goal: let users interact with real logic, data, or workflows.

Typical folders:

```text
app/streamlit/
src/
data/example/
tests/unit/
```

Rules:
- Streamlit is the default POC app surface for Python/data work.
- Move reusable logic out of `app/streamlit/app.py` and into `src/`.
- Keep example data safe and small.

### MVP / PRD app

Goal: create a maintainable app with clearer separation and deployment potential.

Typical folders:

```text
app/frontend/
app/backend/
src/
tests/
infra/
```

Rules:
- Use clear frontend/backend boundaries.
- Add automated tests.
- Add Docker and CI/CD only when the app is ready for repeatable deployment.

## Working with archived repos

If `archive/` contains an older repo:

1. Inspect it.
2. Summarize useful concepts.
3. Identify risky or outdated patterns.
4. Propose a redesign plan.
5. Wait for approval before copying or rewriting major parts.
6. Rebuild into the new standard structure.

Do not mutate archived source material unless explicitly asked.

## Data handling

- `data/example/` may contain safe, small, fake, anonymized, or public sample data.
- `data/private/` may contain local private data and must never be committed.
- Never place credentials, tokens, or personal data in committed files.
- Use `.env.example` for variable names only.
- Use `.env` for local secrets; `.env` must remain ignored.

## Skills

Repo-owned skills live in:

```text
skills/
```

Tool-specific installations may mirror them elsewhere, for example:

```text
.claude/skills/
```

Before starting specialized work, inspect `skills/` for relevant repo-owned skills.

Do not put private data, secrets, or environment-specific credentials in skills.

## Agent workflow

Before implementing:

1. Read `docs/CONSTITUTION.md`.
2. Read `docs/DECISIONS.md`.
3. Read `docs/ARCHITECTURE.md`.
4. Read `docs/README.md`.
5. Read `AGENTS_INIT.md` if present.
6. Inspect the current file tree.
7. If archive material exists, inspect it as reference material.
8. Propose a short plan.
9. Ask for approval when the task affects architecture, data handling, deployment, or public behavior.

During implementation:

1. Keep changes small and reviewable.
2. Prefer simple code over clever code.
3. Keep app entry points thin.
4. Put reusable logic in `src/`.
5. Add or update tests when behavior changes.
6. Update docs when decisions change.
7. Update `project-brain/MEMORY.md` when project context changes.

Before finishing:

1. Run relevant tests or explain why they were not run.
2. Summarize changed files.
3. Note open risks or next steps.
4. Avoid claiming success without validation.

## Browser and UI validation

When the project has a browser UI, prefer Playwright for end-to-end validation.

Typical commands:

```bash
npm install -D @playwright/test
npx playwright install
npx playwright test
```

Use browser validation for:
- navigation
- forms
- visual regressions
- key user flows
- app startup checks

## Docker and Azure

Only add Docker or Azure deployment files when there is a real deployment need.

Preferred locations:

```text
infra/docker/
infra/azure/
infra/pipelines/
```

Keep deployment assumptions documented in `docs/ARCHITECTURE.md`.

## Coding style

- Favor boring, readable, maintainable code.
- Do not introduce heavy frameworks without a reason.
- Do not create large abstractions before the project needs them.
- Prefer explicit names and small modules.
- Keep generated files separate from source files.

## Safety rules

Do not:
- commit private data
- expose secrets
- overwrite existing work without explicit approval
- restructure the repo without explaining the plan
- copy archived code blindly
- add unnecessary dependencies
- edit `docs/CONSTITUTION.md` without explicit approval
