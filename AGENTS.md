## Agent skills

### Issue tracker

Work is tracked in GitHub Issues for `vitherain/still-working`.
Before reading or publishing issues, read `docs/agents/issue-tracker.md`.

When merging a PR with deferred acceptance checks, verify that incomplete
issues are absent from `closingIssuesReferences`. Remove any automatic
closing link that remains after editing the description. Check the issue
states after merging.

### Native UI verification

- Reproduce the reported behavior and rerun the affected scenario after each
  fix. Use a short, bounded loop for intermittent failures. If only the test
  harness changes, rerun its affected scenario. Run the full XCTest suite on
  the final code.
- Use a test instance with isolated preferences. Read current window bounds
  before coordinate-based clicks and verify the field value after simulated
  typing. If verification stalls, report what passed and which check is stuck.

### Domain docs

Single-context layout: root `GLOSSARY.md` and `docs/adr/`.
Before exploring the project, read `docs/agents/domain.md`.
