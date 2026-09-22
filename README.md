# Personal Repo Init Guide

This repository maintains a standalone HTML startup checklist for setting up new repositories in a human-readable, AI-friendly, user-in-control way.

The main file for people to use is:

```text
dist/HUMAN_READABLE_STARTUP_CHECKLIST.html
```

Download or share that HTML file when you want the checklist to work on its own. It is designed to be opened directly in a browser without needing this repository, a local server, or any sibling asset files.

## What The Checklist Is For

The checklist helps semi-technical users start a new repository by guiding them through:

- choosing a working stack, platform, shell, and Git hosting service
- creating a local repo folder
- connecting a remote repository
- adding starter files
- making the first baseline commit
- starting work with an agent such as Codex or Docker Sandbox
- following a repeatable daily Git workflow after setup

It includes copy-ready commands, plain-language explanations, and embedded downloads for starter files.

## Repo Structure

- `dist/HUMAN_READABLE_STARTUP_CHECKLIST.html` is the distributable checklist. This is the file users should download for standalone use.
- `src/bootstrap_repo.py` is the source for the starter script embedded in the HTML.
- `src/AGENTS.md` and `src/AGENTS_INIT.md` are source templates embedded in the HTML for new repositories.
- `assets/` contains local branding and maintenance assets for this repo.
- `AGENTS.md` contains maintenance instructions for agents working on this repository.

## Maintaining The HTML

For checklist copy, layout, interaction behavior, and embedded downloads, edit:

```text
dist/HUMAN_READABLE_STARTUP_CHECKLIST.html
```

If you update `src/bootstrap_repo.py`, `src/AGENTS.md`, or `src/AGENTS_INIT.md`, also check whether the embedded download copies inside the HTML need to be refreshed.

## Optional supervised builder/reviewer starter

The checklist's Extras include an advanced local pipeline alongside the recommended
single interactive agent path. Its maintained files are:

- `src/agent-pipeline-demo-starter/`: canonical starter source, including its README,
  PowerShell initializer, dispatcher, prompts, task examples and calculator template.
- `scripts/build_agent_pipeline_zip.py`: standard-library deterministic packager.
- `dist/agent-pipeline-demo-starter.zip` and `.zip.sha256`: intentional versioned artifacts.
- `tmp/`: ignored input/scratch only, never a source of truth.

After **every** starter change, run from the repository root:

```sh
python3 scripts/build_agent_pipeline_zip.py --verify
python3 scripts/build_agent_pipeline_zip.py --check
```

On Windows, use `python` instead of `python3` if needed. `--verify` rebuilds, extracts
to a temporary directory and compares all distributable files byte-for-byte;
`--check` checks the existing archive and checksum without rebuilding. To demonstrate
reproducibility, run the build twice and compare its printed SHA-256 values.
The archive uses sorted paths, fixed timestamps, fixed permissions and stored entries
(no compression-version dependency). Source line endings are fixed through `.gitattributes`.
Runtime data, caches, credentials and generated workspaces are excluded. Filename
filtering is not a secret-content scanner: inspect new source for secrets before review.

Keep the HTML workflow aligned with the starter scripts and README. Distribute the
optional ZIP and checksum **alongside** the HTML in `dist/`; neither is embedded in
HTML. The interface and core startup guidance still work without them. GitHub main
fallback links become usable only once those artifacts are merged/pushed; rebuilding
does not publish anything. Review source, ZIP, checksum and HTML together.

Maintenance checks (no agent/dispatcher execution):

```sh
python3 scripts/test_build_agent_pipeline_zip.py
```

With PowerShell available, `pwsh -NoProfile -File scripts/test_agent_pipeline_metadata.ps1`
checks metadata rejection rules and parses every starter PowerShell script. Run
`npm test` in `src/agent-pipeline-demo-starter/template/` for the calculator tests.
The starter release number is recorded in its `VERSION`; update it intentionally
when releasing revised starter behavior.
