---
name: tdd
description: Test-driven development. Use when the user wants to build features or fix bugs test-first, mentions "red-green-refactor", or wants integration tests.
---

# Test-Driven Development

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Test-blind production**: All non-test files are production code. Production code must be test-blind: no test-only parameters, branches, exports, environment checks, smoke modes, fixtures, mocks, or wiring that exists only to satisfy tests.

**Supported public contracts**: Valid test boundaries are interfaces that production callers already use, or that naturally belong in the production design: CLI commands, HTTP endpoints, package exports, service boundaries, adapters, UI flows, or documented module APIs. Private helpers, incidental internal files, and new test-only entry points are not valid boundaries.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it. A good test reads like a specification - "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (like querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

**Tautological tests** restate the implementation inside the assertion, so they pass by construction and give zero confidence. When the expected value is computed the way the code computes it — `expect(add(a, b)).toBe(a + b)`, snapshotting a figure you derived by hand the same way the code does, asserting a constant equals itself — the test can never disagree with the code: break the code wrong and the assertion breaks wrong with it. The expected value must come from an independent source of truth — a known-good literal, a worked example, the spec.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

When exploring the codebase, read `CONTEXT.md` (if it exists) so that test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

Before writing any code:

- [ ] List the real supported interfaces, or likely production-facing interfaces that are or should be available for testing
- [ ] Ensure that any production contract changes are needed for real callers; do not introduce interfaces solely for tests
- [ ] If the existing production contract is genuinely untestable, redesign the production boundary for real users, not for the test harness
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] Identify opportunities for deep modules (small interface, deep implementation) — run the `/codebase-design` skill for the vocabulary and the testability checks
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors matter most. Focus testing effort on critical paths and complex logic, not every possible edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails for the right reason
GREEN: Write production behavior without test-aware shortcuts → test passes
```

This is your tracer bullet - proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails for the right reason
GREEN: Minimal production behavior without test-aware shortcuts → passes
```

Rules:

- One test at a time
- Name the supported contract this test uses before writing the test
- If the test needs a new seam, first ask whether that seam would exist for production users without this test
- Edge cases should be driven through the same supported contract as normal cases
- The test must fail for the right reason without requiring production API shape changes that only tests need
- Only enough production behavior to pass the current test, without test-aware shortcuts
- Production-blind green: the code passes because behavior exists, not because production recognized the test context
- Before considering GREEN complete, inspect every non-test file changed and verify it contains no test-only logic or test-shaped API
- Don't anticipate future tests
- Keep tests focused on observable behavior

### 4. Refactor

After all tests pass, look for [refactor candidates](refactoring.md):

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Apply SOLID principles where natural
- [ ] Consider what new code reveals about existing code
- [ ] During refactor, inspect non-test files separately from test files
- [ ] Remove any test-aware production affordance before calling the work done, even if tests already pass
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

Before final response, run or mentally apply a test-awareness scan over production files.

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Expected values are independent literals, not recomputed from the code
[ ] Code is minimal for this test
[ ] No production code mentions or branches on tests, mocks, smoke mode, e2e mode, CI mode, or fixtures unless that is a real product feature
[ ] No speculative features added
```
