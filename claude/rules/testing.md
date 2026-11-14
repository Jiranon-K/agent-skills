---
description: Testing standards for test files
paths:
  - "tests/**"
  - "**/*.test.*"
  - "**/*.spec.*"
---

# Testing

- Write tests that verify behavior, not implementation details.
- Each test should have one clear assertion. Name it after what it proves.
- Use `describe` blocks to group related tests. Use `it` or `test` for individual cases.
- Test the public API of modules, not internal functions.
- Prefer real dependencies over mocks. Only mock external services (APIs, databases).
- Every bug fix must include a regression test that fails without the fix.
- Run the full test suite before marking any task complete with the repository's own test command.
