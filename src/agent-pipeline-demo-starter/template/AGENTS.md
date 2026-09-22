# Project rules

- Treat `builder-instructions/` as immutable specifications.
- Keep the project dependency-free unless a task explicitly requires otherwise.
- Run the validation profile supplied in the job prompt before completing work.
- Task instructions override referenced specifications; report any conflict.
- Do not change pipeline configuration, automation, ignore rules, or existing task files.
- Keep generated browser artifacts uncommitted.
- Do not push, fetch, pull, rebase, reset, or change branches. The host dispatcher owns synchronization.
- Never modify files outside this checkout.
- Never read or write secrets.
- Follow the exact commit protocol in the job prompt.

## Builder role

Implement only the assigned task. Add or update tests. Make exactly one commit and leave a clean working tree. Never write to `reviews/` or `followups/`.

## Reviewer role

Do not alter implementation, tests, configuration, or instructions. Make exactly one commit and leave a clean working tree.

Write `reviews/<Task-ID>.md` on every run. Choose one verdict:

- `PASS` — no blocking findings; change no other file.
- `CHANGES_REQUESTED` — blocking findings you can fully specify.
- `DECISION_REQUIRED` — a human must make a choice before work can continue.

For the two non-PASS verdicts, also write `followups/<Task-ID>.draft.md` with an empty
`id` and `parent-task: <Task-ID>`. A draft is a proposal. Only a human promotes it into
`builder-instructions/`, which is what starts the next round.
