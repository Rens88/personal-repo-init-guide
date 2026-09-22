---
id: TASK-0001
title: Add multiplication
validation-profile: default
spec-path:
spec-commit:
---

# Goal

Add a `multiply(left, right)` operation to the calculator module.

# Requirements

- Export `multiply` from `src/calculator.js`.
- Validate both operands with the same finite-number rules used by the existing operations.
- Add focused tests for successful multiplication and invalid operands.
- Keep the project dependency-free.

# Acceptance criteria

- `npm test` passes.
- `multiply(6, 7)` returns `42`.
- A non-number, `NaN`, or infinite operand throws `TypeError`.
- Existing behavior remains unchanged.
