# Agent Task: Add Docker Sandbox Artifact Extraction Workflow To Personal Repo Init Guide

## Context

Repository to update:

https://github.com/Rens88/personal-repo-init-guide

This repository maintains a standalone HTML startup checklist for setting up new repositories in a human-readable, AI-friendly, user-in-control way. The main distributable file is:

`dist/HUMAN_READABLE_STARTUP_CHECKLIST.html`

The checklist already contains optional Docker Sandbox and Playwright sections. Add a reusable workflow for retrieving generated files from a Docker Sandbox, especially unversioned artifacts such as Playwright videos, screenshots, traces, logs, and validation reports.

## Goal

Add a practical checklist/cheatsheet section that teaches the user how to:

1. Locate generated artifacts inside a Docker Sandbox.
2. Package artifact folders into a single archive inside the sandbox.
3. Copy the archive or individual files from the sandbox to the Windows host.
4. Extract the archive locally.
5. Avoid committing large generated artifacts unless explicitly intended.

This should be written for a Windows user using `cmd` and the Docker Sandboxes `sbx` CLI.

## Important learned workflow

The user successfully used these patterns while retrieving Playwright validation artifacts from a sandbox named `projexcellent-codex`.

### Locate files inside the sandbox

```bat
sbx exec projexcellent-codex bash -lc "pwd"
sbx exec projexcellent-codex bash -lc "find artifacts/playwright-validation -type f"
sbx exec projexcellent-codex bash -lc "find / -name '*.webm' 2>/dev/null"
```

Observed useful paths included:

```text
/c/Users/rmeer/CodeLibrary/projexcellent-app/artifacts/playwright-validation/run-20260702-try-again/videos/page@cd8eb53229a8deb4edfcfb161f871e273.webm
```

### Prefer `tar`, because `zip` may not be installed

`zip` was not available in the sandbox:

```text
bash: line 1: zip: command not found
```

Use `tar` instead:

```bat
sbx exec projexcellent-codex bash -lc "cd /c/Users/rmeer/CodeLibrary/projexcellent-app && tar -czf /tmp/playwright-validation-run.tar.gz artifacts/playwright-validation/run-20260702-try-again"
```

### Copy the archive from sandbox to Windows host

```bat
sbx cp projexcellent-codex:/tmp/playwright-validation-run.tar.gz .
```

Even if `sbx cp` prints an extraction-related warning/error, verify with `dir`. In the observed case, the archive was still copied successfully.

```bat
dir playwright-validation-run.tar.gz
```

### Extract locally on Windows

```bat
tar -xzf playwright-validation-run.tar.gz
```

Then inspect:

```bat
dir artifacts\playwright-validation\run-20260702-try-again /s
```

### Copy one file directly if needed

If direct copy works for the CLI/environment, use:

```bat
sbx cp projexcellent-codex:/tmp/some-file.ext .
```

For deeply nested files, prefer creating a tarball first. This avoids issues with special characters like `@` in Playwright video filenames and avoids repeated long path copy attempts.

## Section to add

Add a new optional section near the existing Docker Sandbox / Playwright material. Suggested title:

`Optional: Retrieve Generated Artifacts From Docker Sandbox`

Suggested purpose text:

Use this when an agent generates files inside a Docker Sandbox that are not committed to Git, such as Playwright videos, screenshots, traces, reports, logs, exported data, or temporary analysis outputs.

## Required checklist content

Include these checklist steps, adapted to the style of the existing HTML guide:

### 1. Confirm the sandbox name

```bat
sbx ls
```

Explain that examples use:

```text
projexcellent-codex
```

but the user should replace it with their sandbox name.

### 2. Locate the generated files

```bat
sbx exec projexcellent-codex bash -lc "pwd"
sbx exec projexcellent-codex bash -lc "find artifacts -type f"
```

For Playwright videos specifically:

```bat
sbx exec projexcellent-codex bash -lc "find / -name '*.webm' 2>/dev/null"
```

Explain that Windows `find` is different from Linux `find`; therefore, Linux `find` must be run inside the sandbox through `sbx exec ... bash -lc "..."`.

### 3. Create a tar archive inside the sandbox

Template command:

```bat
sbx exec SANDBOX_NAME bash -lc "cd PROJECT_DIR && tar -czf /tmp/ARTIFACT_NAME.tar.gz RELATIVE_ARTIFACT_FOLDER"
```

Concrete example:

```bat
sbx exec projexcellent-codex bash -lc "cd /c/Users/rmeer/CodeLibrary/projexcellent-app && tar -czf /tmp/playwright-validation-run.tar.gz artifacts/playwright-validation/run-20260702-try-again"
```

Explain:

- `PROJECT_DIR` is the project root as seen inside the sandbox.
- `RELATIVE_ARTIFACT_FOLDER` is the folder to package.
- `/tmp/...tar.gz` is a simple temporary location that is easy to copy from.
- `tar` is preferred over `zip` because `zip` may not be installed.

### 4. Copy the archive to the Windows host

```bat
sbx cp projexcellent-codex:/tmp/playwright-validation-run.tar.gz .
```

Then verify locally:

```bat
dir playwright-validation-run.tar.gz
```

### 5. Extract locally

```bat
tar -xzf playwright-validation-run.tar.gz
```

Then inspect:

```bat
dir artifacts\playwright-validation /s
```

### 6. Open Playwright video locally

Example:

```bat
start artifacts\playwright-validation\run-20260702-try-again\videos\page@cd8eb53229a8deb4edfcfb161f871e273.webm
```

Also mention the user can open `.webm` files with Chrome, Edge, or VLC.

### 7. Decide whether artifacts should be committed

Explain:

- Generated validation artifacts are usually untracked and often ignored.
- Do not commit videos/traces by default because they can bloat the repository.
- Commit only lightweight reports if useful, or store videos outside Git.
- If a run should be preserved, explicitly decide what to keep.

Suggested command:

```bat
git status --ignored
```

## Add an agent prompt block

Add a copy-ready prompt that the user can give to Codex after a Playwright run:

```text
Please package the latest generated validation artifacts so I can copy them from this Docker Sandbox to my Windows host.

Do not modify application code.
Do not commit artifacts unless I explicitly ask.

1. Identify the latest artifact folder under artifacts/playwright-validation/.
2. Print the full file list, including videos, screenshots, traces, logs, and reports.
3. Create a tar.gz archive in /tmp using tar, not zip.
4. Print the exact sbx cp command I should run from my Windows host to copy the archive locally.
5. Print the local Windows commands to verify, extract, and open the video.
```

## Implementation requirements

- Keep the standalone HTML usable without a server.
- Preserve the current visual/checklist style.
- Use `cmd` examples by default because the user is currently using Windows cmd.
- If the HTML has shell tabs for PowerShell/cmd/Bash/WSL, add commands to the `cmd` tab first. Add PowerShell/Bash variants only if the existing pattern makes that straightforward.
- Do not remove or rewrite unrelated checklist content.
- Do not commit generated Playwright artifacts, videos, traces, screenshots, or local sandbox output.
- After editing, run whatever lightweight validation is appropriate for this repository, for example checking that the HTML still opens/builds or that changed files are limited to the intended guide files.

## Expected result

A small, practical addition to the standalone checklist that makes this repeatable:

- find files generated inside a Docker Sandbox,
- package them with `tar`,
- copy them with `sbx cp`,
- extract them locally,
- review Playwright videos/screenshots/traces,
- keep generated artifacts out of Git unless deliberately preserved.
