# Calculator agent-pipeline demo

This tiny zero-dependency Node.js project exists to exercise the agent workflow, not to showcase application architecture.

Run its tests with:

```powershell
npm test
```

Human instructions live in `builder-instructions/`. Builder output changes the app and tests. Reviewer output lives in `reviews/`.

See `../README.txt` for the generated folder layout and the starter package's top-level README for complete setup instructions.

Validation profiles are committed in `agent-pipeline.config.json`. Tasks can omit
`validation-profile` (defaults to `default`) or select `web-ui` after preparing a
browser project and Playwright in both agent environments. See the examples.
Optional `spec-path` and `spec-commit` must be supplied together; use a safe relative
path and full commit hash. Task instructions override conflicting referenced specs.

After review, pull with `git pull --ff-only` and inspect `reviews/TASK-xxxx.md`.
Both PASS and CHANGES_REQUESTED require a human decision. Submit a new task for
follow-up; there is no automatic review-to-builder loop. Preserve artifacts from
builder/reviewer before another run, which cleans their workspaces.
