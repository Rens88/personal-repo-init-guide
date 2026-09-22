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

Implement only the assigned task. Add or update tests. Make exactly one commit and leave a clean working tree.

## Reviewer role

Do not alter implementation, tests, configuration, or instructions. Create only the requested Markdown report under `reviews/`, make exactly one commit, and leave a clean working tree.
