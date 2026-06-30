# AGENTS.md

This file governs maintenance of this repository itself.

## Purpose

This repo exists to maintain a personal standalone HTML startup checklist that can be shared with workshop students.

It is not itself a bootstrapped app repo. The files under `src/` are starter templates for other repositories.

## Repo map

- `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html`: the distributable standalone checklist and primary user-facing artifact.
- `src/bootstrap_repo.py`: source for the bootstrap script that gets downloaded into new repositories.
- `src/AGENTS.md` and `src/AGENTS_INIT.md`: source templates for agent guidance in newly initialized repositories.
- `assets/`: local branding and input assets used while maintaining this repo.
- `AGENTS.md`: operating rules for maintaining this repo.

## Source of truth

- For checklist UX, structure, copy, and interaction behavior, inspect and edit `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html`.
- For downstream starter-file content, treat `src/bootstrap_repo.py`, `src/AGENTS.md`, and `src/AGENTS_INIT.md` as canonical.
- If a change touches embedded downloads inside the checklist HTML, sync the embedded copies in `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html` with the matching files in `src/`.

## Working with `src/`

`src/` may be ignored for checklist-only UI/content edits.

Do not ignore `src/` when the change affects:

- embedded download content inside the checklist HTML
- files that users will download into other repositories
- behavior or wording that should stay aligned between the checklist and the starter files

## Standalone requirement

The distributed HTML in `dist/` must work as a standalone file.

Any dependency on sibling files such as `assets/` should be treated as a maintenance issue to fix or explicitly flag. If branding is kept, make the dependency intentional and visible.

## Workflow

1. Read this root `AGENTS.md`.
2. Inspect the relevant file in `dist/` and, if needed, the matching source file in `src/`.
3. Keep edits small and reviewable.
4. Avoid adding build systems, frameworks, or extra tooling unless explicitly requested.
5. Ask before changing downstream starter-file policy, workshop-sharing assumptions, or branding behavior.

## Safety rules

Do not:

- assume the generic repo-bootstrap rules from `src/AGENTS.md` apply to this maintenance repo
- edit `src/` and forget to update embedded downloads when the checklist ships those files
- make the distributed HTML less portable without calling it out clearly
