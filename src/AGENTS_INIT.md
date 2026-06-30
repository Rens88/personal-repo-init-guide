# AGENTS_INIT.md

This file is the startup checklist for bootstrapping or redesigning this repository.

It may be deleted or moved to `archive/` after the project has a stable direction.

## Mission

Turn this repository into a clean, maintainable project using the standard structure.

The target may be one of:

- rapid prototype
- proof of concept
- MVP / PRD app

When uncertain, start smaller.

## First agent task

Before writing code, do this:

1. Inspect the repository tree.
2. Read `README.md`, `GETTING_STARTED.md`, and `AGENTS.md`.
3. Read `docs/README.md`.
4. Read `docs/CONSTITUTION.md`.
5. Read `docs/DECISIONS.md`.
6. Read `docs/ARCHITECTURE.md`.
7. Check whether `archive/` contains old source material.
8. Summarize what exists.
9. Propose the project maturity level.
10. Propose the first implementation plan.
11. Wait for user approval.

## If archive material exists

Treat archived material as inspiration, not as the new structure.

Analyze:

- What problem did the old repo solve?
- What parts are still useful?
- What should be redesigned?
- What can be copied safely?
- What should not be copied?
- What data assumptions are hidden in the old code?
- What dependencies or deployment assumptions are outdated?

Write findings to:

```text
docs/migration-notes.md
```

Then propose a redesign plan.

## Recommended first plan format

Use this format:

```markdown
# Proposed Plan

## Project maturity level

Rapid prototype / Proof of concept / MVP

## What I found

## What I recommend keeping from archive

## What I recommend redesigning

## Proposed target structure

## First implementation steps

## Validation plan

## Questions for the user
```

## Default implementation choices

Use these defaults unless the user says otherwise.

### Rapid prototype

- Put standalone HTML work in `prototypes/html/`.
- Generate output into `prototypes/html/build/`.
- Keep it simple and visual.
- Do not add backend infrastructure.

### Proof of concept

- Use Streamlit for Python/data interaction.
- Put the app entry point in `app/streamlit/app.py`.
- Put reusable logic in `src/`.
- Use `data/example/` for safe sample data.
- Use `data/private/` for local private data only.

### MVP / PRD app

- Use `app/frontend/` for frontend code.
- Use `app/backend/` for backend/API code.
- Put domain and reusable services in `src/`.
- Add tests before expanding features.
- Add Docker and Azure files only when deployment becomes relevant.

## Memory maintenance

When meaningful context changes:

1. Add a short entry to `project-brain/MEMORY.md`.
2. Put rough working notes in `project-brain/AI-NOTES.md`.
3. Promote actual decisions to `docs/DECISIONS.md`.
4. Update `docs/ARCHITECTURE.md` if the design changes.
5. Update `docs/RISKS.md` if a new risk appears.

Do not treat `MEMORY.md` as authoritative truth. Decisions belong in `docs/DECISIONS.md`.

## Validation checklist

Before presenting work as complete:

- App starts locally, or startup limitation is documented.
- Main user flow is tested manually or with Playwright.
- Unit tests pass, if present.
- No private data is committed.
- Docs reflect important decisions.
- Open issues are listed clearly.

## User approval gates

Ask before:

- editing `docs/CONSTITUTION.md`
- copying large chunks from `archive/`
- adding major dependencies
- introducing Docker/Azure infrastructure
- changing app framework
- restructuring existing project folders
- touching private data
- creating deployment or CI/CD files
