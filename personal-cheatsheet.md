# IMPORTANT COMMANDS

## Interact with sbx using bash
Access the bash-terminal from the sandbox environment, for example to use git.

`sbx exec -it projexcellent-codex bash`

## Run the app locally
Navigate to repo root

`cd C:\Users\rmeer\CodeLibrary\projexcellent-app`

Activate venv

`".venv/Scripts/activate.bat"`

Run app

`python -m streamlit run app/streamlit/app.py --server.address 127.0.0.1 --server.port 8502`

Open app in browser

`http://127.0.0.1:8502/`

## Run app in sandbox
Start app in sandbox:

`sbx exec projexcellent-codex bash -lc "python3 -m streamlit run app/streamlit/app.py --server.address 0.0.0.0 --server.port 8501"`

Access app from sandbox:

`http://127.0.0.1:8501/`

## Streamlit process control
List streamlit processes in sbx:

`sbx exec projexcellent-codex bash -lc "ps -ef | grep streamlit"`

Kill specific streamlit process in sbx:

`sbx exec projexcellent-codex bash -lc "kill 1234"`

Kill all streamlit processes in sbx:

`sbx exec projexcellent-codex bash -lc "pkill -f streamlit"`

## Port forwarding
Allow port-forwarding so I can access it:

`sbx ports projexcellent-codex --publish 8501:8501`

Remove port-forwarding

`sbx ports projexcellent-codex --unpublish 8501:8501`

## Transfer files to sandbox (one-off) DOESN'T WORK?!?
Copy a locally available file to inside the sandbox so the agent can access it:

`sbx cp artifacts\bug-reports\issue-001.png projexcellent-codex:/tmp/issue-001.png`

This can be combined with an agent-instruction to replicate the bug:

`Inspect /tmp/issue-001.png and fix the demonstrated issue. Run the Streamlit app, reproduce the bug with Playwright, capture a before screenshot, implement the fix, and capture an after screenshot. Use a 1440 x 900 viewport. Store validation artifacts under artifacts/playwright-validation/.`

Vervolgens kun je de artifacts ophalen:

`sbx cp projexcellent-codex:/path/to/clone/artifacts/playwright-validation .\artifacts\`

## Open files in sandbox
To open a text file without pagination:

`sbx exec projexcellent-codex bash -lc "cat specs/002-local-workflow-report-evolution/spec.md"`

To open a text file with pagination:

`sbx exec projexcellent-codex bash -lc "less specs/002-local-workflow-report-evolution/spec.md"`

## Update local branch
Download the latest commits from GitHub without changing your working tree:

`git fetch origin`

Make your local main point to the exact same commit as origin/main and DISCARD ALL modifications to tracked files.

`git reset --hard origin/main`

Check whether there are untracked files:

`git ls-files --others --exclude-standard`

or

`git status`

Remove untracked files and directories (optional, but useful if you want a completely clean checkout).

`git clean -fd`

## Update sandbox Git branch from GitHub

When reconnecting to a Docker Sandbox after making changes locally or merging PRs, first ensure the sandbox's Git clone is up to date.

### 1. Open a bash shell inside the sandbox

```bash
sbx exec -it projexcellent-codex bash
```

### 2. Verify the current Git state

Check that you are on the expected feature branch and whether there are local changes:

```bash
git status
```

Example output:

```text
On branch feature/002-local-workflow-report-evolution
Your branch is up to date with 'origin/feature/002-local-workflow-report-evolution'.

nothing to commit, working tree clean
```

### 3. (Optional) Inspect local branches

Shows all local branches and whether they are ahead/behind their upstream branches.

```bash
git branch -vv
```

Example:

```text
feature/spec-kit-workflow-plan-tracking     [origin/...: behind 2]
```

indicates that branch has not yet been updated from GitHub.

### 4. (Optional) Verify remotes

```bash
git remote -v
```

Expected remotes:

- `origin` → GitHub repository
- `sandbox-projexcellent-codex` → Git endpoint of the sandbox itself

When updating the sandbox, pull from **origin**, not from `sandbox-projexcellent-codex`.

### 5. Pull the latest changes from GitHub

```bash
git pull --ff-only
```

Using `--ff-only` guarantees that Git will only fast-forward the branch. If a merge would be required, Git stops instead of creating an unexpected merge commit.

Typical output:

```text
Updating c9ce3ff..8172b83
Fast-forward
...
```

If there are no updates:

```text
Already up to date.
```

### Recommended routine before starting work

```bash
git status
git pull --ff-only
```