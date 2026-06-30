#!/usr/bin/env python3
"""
bootstrap_repo.py

Create a clean AI-lab style repository shell for rapid prototypes,
proof-of-concept apps, or MVP/PRD-oriented apps.

Design philosophy:
- Start clean.
- Do not mutate old repositories by default.
- If continuing from old work, copy the old repo into archive/ and redesign from it.
- Existing files are not overwritten unless --force is used.
- The folder structure is for humans first, agents second.

Typical use:

  python bootstrap_repo.py --target my-new-project --profile streamlit-poc

  python bootstrap_repo.py --target my-new-project --profile react-mvp --with playwright --with azure-docker

  python bootstrap_repo.py --target my-new-project --profile streamlit-poc --from-archive C:\path\to\old-repo
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import shutil
from pathlib import Path
from typing import Iterable


BASE_DIRS = [
    "docs",
    "project-brain/session-summaries",
    "prototypes/html/build",
    "prototypes/notebooks",
    "app/streamlit",
    "app/frontend",
    "app/backend",
    "src/domain",
    "src/services",
    "src/data",
    "src/utils",
    "tests/unit",
    "tests/integration",
    "tests/e2e",
    "data/example",
    "data/private",
    "assets",
    "scripts",
    "infra/docker",
    "infra/azure",
    "infra/pipelines",
    "skills",
    "archive",
]

PROFILE_DIRS = {
    "base": [],
    "html-prototype": [
        "prototypes/html/build",
        "assets",
    ],
    "streamlit-poc": [
        "app/streamlit",
        "src/domain",
        "src/services",
        "src/data",
        "src/utils",
        "data/example",
        "tests/unit",
    ],
    "react-mvp": [
        "app/frontend",
        "app/backend",
        "src/domain",
        "src/services",
        "src/data",
        "src/utils",
        "tests/unit",
        "tests/integration",
        "tests/e2e",
    ],
    "azure-docker": [
        "infra/docker",
        "infra/azure",
        "infra/pipelines",
    ],
    "playwright": [
        "tests/e2e",
    ],
    "skills": [
        "skills",
    ],
}

BASE_FILES = {
    "README.md": """# Project Title

Briefly describe the project, user problem, and intended maturity level.

## Maturity level

- [ ] Rapid prototype
- [ ] Proof of concept
- [ ] MVP / PRD app

## Quick start

See `GETTING_STARTED.md`.

## Project knowledge

- Stable project docs: `docs/`
- Evolving project memory: `project-brain/`
- Agent operating rules: `AGENTS.md`
- Startup checklist for agents: `AGENTS_INIT.md`
""",
    "GETTING_STARTED.md": """# Getting Started

## 1. Create environment

```bash
python -m venv .venv
```

Windows:

```cmd
.venv\\Scripts\\activate
```

macOS/Linux:

```bash
source .venv/bin/activate
```

## 2. Install dependencies

```bash
pip install -r requirements.txt
```

## 3. Run the app

Streamlit example:

```bash
streamlit run app/streamlit/app.py
```

Standalone HTML prototype example:

```bash
python prototypes/html/generate.py
```

Then open:

```text
prototypes/html/build/index.html
```
""",
    ".env.example": """# Copy this file to .env and fill in local values.
# Never commit .env.

ENVIRONMENT=local
""",
    ".gitignore": """.venv/
__pycache__/
*.pyc
.env
data/private/
archive/**/.git/
archive/**/.codex/
archive/**/.agents/
archive/**/.claude/
archive/**/.cursor/
archive/**/.venv/
.DS_Store
node_modules/
dist/
build/
.playwright/
test-results/
playwright-report/
coverage/
""",
    ".codexignore": """.venv/
data/private/
archive/**/.git/
archive/**/.codex/
archive/**/.agents/
archive/**/.claude/
archive/**/.cursor/
archive/**/.venv/
node_modules/
dist/
build/
coverage/
""",
    "requirements.txt": """# Add project dependencies here.
""",
    "docs/README.md": """# Documentation Map

The `docs/` folder contains stable project knowledge: what is true, what has been decided, and how the project is intended to work.

The `project-brain/` folder contains evolving memory: notes, session summaries, and historical context.

## Authority hierarchy

When documents conflict, use this order:

1. `docs/CONSTITUTION.md`
2. `docs/DECISIONS.md`
3. `docs/ARCHITECTURE.md`
4. `docs/USER-STORIES.md`
5. `docs/FEATURES.md`
6. `docs/ROADMAP.md`
7. `docs/RISKS.md`
8. `project-brain/MEMORY.md`
9. `project-brain/AI-NOTES.md`

## Ownership

### Human-governed

- `CONSTITUTION.md`

Agents may propose changes, but must not edit this automatically without explicit approval.

### Agent-maintained, human-reviewed

- `DECISIONS.md`
- `ARCHITECTURE.md`
- `USER-STORIES.md`
- `FEATURES.md`
- `ROADMAP.md`
- `RISKS.md`

### Agent-maintained memory

- `project-brain/MEMORY.md`
- `project-brain/AI-NOTES.md`
- `project-brain/session-summaries/`
""",
    "docs/CONSTITUTION.md": """# Constitution

Owner: Human  
Agent may propose changes: Yes  
Agent may modify automatically: No

This file contains the project laws: values, boundaries, defaults, and non-negotiables.

## Project laws

1. Private data is never committed.
2. `data/private/` is for local private data only.
3. Archived repositories are source material, not architecture to preserve.
4. Prefer the simplest maturity level that solves the current problem.
5. Keep app entry points thin; reusable logic belongs in `src/`.
6. Document important decisions in `docs/DECISIONS.md`.
7. Human approval is required before deployment, major restructuring, or large dependency additions.
""",
    "docs/DECISIONS.md": """# Decisions

Owner: Agent-maintained, human-reviewed

This file records authoritative project decisions.

## Decision log

| ID | Date | Decision | Rationale | Consequences |
|---|---|---|---|---|
| ADR-001 | YYYY-MM-DD | Use clean repo redesign instead of in-place migration | Safer and easier to review | Old repos go into `archive/` as source material |
""",
    "docs/ARCHITECTURE.md": """# Architecture

Owner: Agent-maintained, human-reviewed

## Current maturity level

Rapid prototype / Proof of concept / MVP

## App surfaces

## Data flow

## Important modules

## Deployment target

## Risks and trade-offs
""",
    "docs/USER-STORIES.md": """# User Stories

Owner: Agent-maintained, human-reviewed

## Primary users

## User stories

- As a ..., I want ..., so that ...

## Acceptance criteria
""",
    "docs/FEATURES.md": """# Features

Owner: Agent-maintained, human-reviewed

This file describes current or intended functionality.

## Current features

## Planned features

## Out of scope
""",
    "docs/ROADMAP.md": """# Roadmap

Owner: Agent-maintained, human-reviewed

## Now

## Next

## Later

## Maybe
""",
    "docs/RISKS.md": """# Risks

Owner: Agent-maintained, human-reviewed

## Product risks

## Technical risks

## Data and privacy risks

## Operational risks

## Mitigations
""",
    "docs/migration-notes.md": """# Migration / Redesign Notes

Owner: Agent-maintained, human-reviewed

Use this when the project is inspired by archived material.

## Source material

## Useful ideas to keep

## Code to avoid copying blindly

## Redesign decisions

## Validation checklist
""",
    "project-brain/MEMORY.md": """# Memory

Owner: Agent-maintained  
Purpose: chronological project history

Memory is not authoritative truth. If memory conflicts with `docs/DECISIONS.md`, decisions win.

## Log

### YYYY-MM-DD

- Context:
- What changed:
- Why it mattered:
- Follow-up:
""",
    "project-brain/AI-NOTES.md": """# AI Notes

Owner: Agent-maintained  
Purpose: working notes, prompt traces, and reasoning summaries

This file may contain rough notes. Important conclusions should be promoted to:

- `docs/DECISIONS.md`
- `docs/ARCHITECTURE.md`
- `docs/FEATURES.md`
- `docs/RISKS.md`

## Notes
""",
    "prototypes/html/generate.py": """\"\"\"Generate standalone HTML prototypes.

Keep this script simple. Generated files should go into prototypes/html/build/.
\"\"\"

from pathlib import Path

BUILD_DIR = Path(__file__).parent / "build"
BUILD_DIR.mkdir(parents=True, exist_ok=True)

html = \"\"\"<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Prototype</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
  <h1>Prototype shell</h1>
  <p>Replace this with a clickable standalone prototype.</p>
</body>
</html>
\"\"\"

(BUILD_DIR / "index.html").write_text(html, encoding="utf-8")
print(f"Wrote {BUILD_DIR / 'index.html'}")
""",
    "app/streamlit/app.py": """import streamlit as st

st.set_page_config(page_title="POC App", layout="wide")

st.title("POC App")
st.write("Replace this shell with the first useful interaction.")
""",
    "src/__init__.py": "",
    "src/domain/__init__.py": "",
    "src/services/__init__.py": "",
    "src/data/__init__.py": "",
    "src/utils/__init__.py": "",
    "tests/unit/test_smoke.py": """def test_smoke():
    assert True
""",
    "skills/README.md": """# Skills

This folder contains repo-owned AI skills or skill drafts.

Use this as the portable source of truth for specialized agent behavior.

Tool-specific installations may mirror these skills elsewhere, for example:

```text
.claude/skills/
```

Do not put private data or secrets in skills.
""",
}

PROFILE_FILES = {
    "playwright": {
        "tests/e2e/README.md": """# End-to-end tests

Recommended setup for a Node/React app:

```bash
npm install -D @playwright/test
npx playwright install
npx playwright test
```

For quick browser recording:

```bash
npx playwright codegen http://localhost:3000
```
""",
    },
    "azure-docker": {
        "infra/docker/README.md": """# Docker

Place Dockerfiles and compose files here when the project is ready for containerized deployment.
""",
        "infra/azure/README.md": """# Azure

Place Azure deployment notes, Bicep/Terraform, or Azure CLI scripts here.
""",
        "infra/pipelines/README.md": """# Pipelines

Place Azure DevOps pipeline YAML files here.
""",
    },
}

ARCHIVE_EXCLUDED_NAMES = {
    ".git",
    ".codex",
    ".agents",
    ".claude",
    ".cursor",
    ".venv",
    "__pycache__",
    ".pytest_cache",
    ".mypy_cache",
    "node_modules",
    "dist",
    "build",
    ".env",
}

ARCHIVE_EXCLUDED_RELATIVE_PATHS = {
    "data/private",
}


def write_file(path: Path, content: str, force: bool = False) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return True


def make_dirs(target: Path, dirs: Iterable[str]) -> None:
    for directory in dirs:
        (target / directory).mkdir(parents=True, exist_ok=True)


def build_archive_ignore(source: Path):
    def _ignore(directory: str, names: list[str]) -> set[str]:
        current_dir = Path(directory)
        relative_dir = current_dir.relative_to(source)
        ignored: set[str] = set()

        for name in names:
            relative_path = (
                Path(name)
                if relative_dir == Path(".")
                else relative_dir / name
            )
            if name in ARCHIVE_EXCLUDED_NAMES:
                ignored.add(name)
                continue
            if relative_path.as_posix() in ARCHIVE_EXCLUDED_RELATIVE_PATHS:
                ignored.add(name)

        return ignored

    return _ignore


def copy_archive(source: Path, target: Path, force: bool = False) -> Path:
    archive_target = target / "archive" / source.name
    if archive_target.exists():
        if not force:
            raise FileExistsError(
                f"Archive target already exists: {archive_target}. "
                "Use --force to overwrite it."
            )
        shutil.rmtree(archive_target)
    shutil.copytree(source, archive_target, ignore=build_archive_ignore(source))
    return archive_target


def create_bootstrap_report(
    target: Path,
    profile: str,
    extra_profiles: list[str],
    archived_from: Path | None,
    created_files: list[str],
    skipped_files: list[str],
) -> None:
    now = dt.datetime.now().isoformat(timespec="seconds")
    content = f"""# Bootstrap Report

Generated: {now}

## Selected profile

Primary profile: `{profile}`

Extra profiles: {", ".join(f"`{p}`" for p in extra_profiles) if extra_profiles else "None"}

## Archive source

{str(archived_from) if archived_from else "None"}

## Created files

{chr(10).join(f"- `{f}`" for f in created_files) if created_files else "None"}

## Skipped existing files

{chr(10).join(f"- `{f}`" for f in skipped_files) if skipped_files else "None"}

## Next recommended step

Make a baseline commit:

```bash
git add .
git commit -m "Initialize repo standard"
```

Then ask an AI coding agent:

> Read AGENTS.md and AGENTS_INIT.md. Inspect the repository. If archive material exists, summarize what should be reused and what should be redesigned. Do not implement yet. First propose a plan.
"""
    write_file(target / "BOOTSTRAP_REPORT.md", content, force=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Create a clean AI-lab repo shell.")
    parser.add_argument("--target", default=".", help="Target repository directory.")
    parser.add_argument(
        "--profile",
        default="base",
        choices=sorted(PROFILE_DIRS.keys()),
        help="Primary repo profile.",
    )
    parser.add_argument(
        "--with",
        dest="extra_profiles",
        action="append",
        default=[],
        choices=sorted(PROFILE_DIRS.keys()),
        help="Optional extra profile. Can be used multiple times.",
    )
    parser.add_argument(
        "--from-archive",
        default=None,
        help="Path to an old repo/folder to copy into archive/ as source material.",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing generated files and archive target if needed.",
    )
    parser.add_argument(
        "--no-git",
        action="store_true",
        help="Do not initialize git.",
    )
    args = parser.parse_args()

    target = Path(args.target).resolve()
    target.mkdir(parents=True, exist_ok=True)

    all_profiles = [args.profile] + args.extra_profiles
    dirs = set(BASE_DIRS)
    for profile in all_profiles:
        dirs.update(PROFILE_DIRS[profile])

    make_dirs(target, sorted(dirs))

    created_files: list[str] = []
    skipped_files: list[str] = []

    files = dict(BASE_FILES)
    for profile in all_profiles:
        files.update(PROFILE_FILES.get(profile, {}))

    for rel_path, content in files.items():
        did_create = write_file(target / rel_path, content, force=args.force)
        if did_create:
            created_files.append(rel_path)
        else:
            skipped_files.append(rel_path)

    archived_path = None
    if args.from_archive:
        archived_path = copy_archive(Path(args.from_archive).resolve(), target, force=args.force)

    if not args.no_git and not (target / ".git").exists():
        os.system(f'git -C "{target}" init')

    create_bootstrap_report(
        target=target,
        profile=args.profile,
        extra_profiles=args.extra_profiles,
        archived_from=archived_path,
        created_files=created_files,
        skipped_files=skipped_files,
    )

    print(f"Bootstrapped repo at: {target}")
    print(f"Profile: {args.profile}")
    if args.extra_profiles:
        print(f"Extra profiles: {', '.join(args.extra_profiles)}")
    if archived_path:
        print(f"Archived source copied to: {archived_path}")
    print("See BOOTSTRAP_REPORT.md for details.")


if __name__ == "__main__":
    main()
