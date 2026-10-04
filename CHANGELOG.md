## [Unreleased]

- Removing a test case result (when the server retries a test) now matches on the test class as well as the method name, so two tests sharing a file and method name (a module included in two classes, nested describes with the same `it` text) no longer clear each other's failure and turn a failing run green

## [0.1.4] - 2026-09-29

- Trace each test (setup and teardown included) for test maps when the server asks; a pass-through otherwise and with cores older than 0.2.10
- Re-running a test case in the same process (auto-retry, manual rerun) now replaces its earlier record in every reporter instead of appending a duplicate, so JUnit-style reports carry one entry per test and tools keyed on test identity (e.g. Captain) can reconcile retries

## [0.1.3] - 2026-04-21

- Fix summary_reporter when minitest-reporters is active

## [0.1.2] - 2026-03-04

- Fix retry error in remove_test_case_result with digest-based test IDs

## [0.1.1] - 2025-12-09

- Fix exit status when there are no failures but some skipped tests