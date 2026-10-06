## [Unreleased]

- Support minitest 6: run each test through `Runnable.run` when `Runnable.run_one_method` no longer exists, and leave plugin loading to the suite as minitest 6's own runner does
- Fix a crash in `finish` when minitest runs single-threaded (`MT_CPU=1` or a one-CPU runner) and so never creates a parallel executor; minitest 5.27 and 6 both skip creating it
- Fix a crash in `finish` when no test ran on minitest older than 5.22, which has no `Minitest.empty_run!`
- Declare the supported minitest range (`>= 5.16`, `< 7`); 5.16 is the first release with `Minitest.seed`, which the runner relies on
- **Breaking:** `required_ruby_version` is now `>= 2.7.0` (was `>= 2.6.0`); CI tests Ruby 2.7.8 through 4.0.7

## [0.1.5] - 2026-10-03

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