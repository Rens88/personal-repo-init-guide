---
id: TASK-0002
title: Validate the calculator web UI
validation-profile: web-ui
spec-path:
spec-commit:
---

# Prerequisite

Adapt this example only after a browser UI, a committed @playwright/test dependency,
Playwright configuration (including webServer or baseURL), and browser binaries exist
in both agent environments. This is not runnable in the default calculator demo.

# Goal

Add a browser test for the existing calculator's multiplication flow.

# Requirements and acceptance criteria

- Use the actual application's selectors and documented startup command.
- Verify that entering 6 and 7 and choosing multiply visibly returns 42.
- Run npm test and npx playwright test independently in both agent environments.
- Preserve useful traces/screenshots in test-results/ and reports in playwright-report/.
- Report commands, outcomes and artifact paths; do not commit generated artifacts.
