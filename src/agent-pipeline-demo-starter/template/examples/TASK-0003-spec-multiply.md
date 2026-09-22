---
id: TASK-0003
title: Implement multiplication from an approved specification
validation-profile: default
spec-path: specs/001-calculator/spec.md
spec-commit: REPLACE_WITH_FULL_COMMITTED_SPEC_HASH
---

# Preparation (human, before submission)

Commit the approved Spec Kit artifact first, then replace spec-commit with that
commit's full hash. Adapt spec-path to the actual file. The placeholder is deliberately
invalid so an unfrozen specification cannot accidentally be submitted.

# Goal and acceptance criteria

Implement multiply(left, right) with finite-number validation and focused unit tests.
Keep the demo dependency-free. npm test must pass, including multiply(6, 7) === 42.
Read the specification at the pinned commit for context. If it conflicts with these
instructions, report the conflict and follow this task. Do not execute Spec Kit's
implementation or convergence stages; this submission uses one builder and one reviewer.
