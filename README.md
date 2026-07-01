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
