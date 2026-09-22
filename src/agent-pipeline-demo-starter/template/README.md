# Calculator agent-pipeline demo

This tiny zero-dependency Node.js project exists to exercise the agent workflow, not to showcase application architecture.

Run its tests with:

```powershell
npm test
```

Human instructions live in `builder-instructions/`. Builder output changes the app and tests. Reviewer output lives in `reviews/`, and any proposed next round in `followups/`.

See `../README.txt` for the generated folder layout and the starter package's top-level README for complete setup instructions.

Validation profiles are committed in `agent-pipeline.config.json`. Tasks can omit
`validation-profile` (defaults to `default`) or select `web-ui` after preparing a
browser project and Playwright in both agent environments. See the examples.
Optional `spec-path` and `spec-commit` must be supplied together; use a safe relative
path and full commit hash. Task instructions override conflicting referenced specs.

After review, pull with `git pull --ff-only` and inspect `reviews/TASK-xxxx.md`.
Every verdict requires a human decision. Preserve artifacts from builder/reviewer
before another run, which cleans their workspaces.

`PASS` ends the thread. `CHANGES_REQUESTED` and `DECISION_REQUIRED` leave a draft
next task in `followups/TASK-xxxx.draft.md`. To start another round:

```powershell
./automation/Promote-Followup.ps1 -TaskId TASK-0001 -Slug fix-operand-validation
# read and edit the generated builder-instructions/TASK-0002-fix-operand-validation.md
./automation/Submit-Task.ps1 -Path ./builder-instructions/TASK-0002-fix-operand-validation.md
```

That submit commit is the sign-off. Nothing reaches a builder without it.
`followups.maxRounds` in `agent-pipeline.config.json` caps how deep a thread can go.
