# Integration Testing

This document describes how to run and extend the integration tests for the Personal Archive application.

## Overview

The integration tests are located in `integration_test/`. They verify the correct behavior of the application's core pipelines and features by running in a real Flutter environment (simulated directly on the host desktop OS) but using isolated test resources.

## Running Tests

To run the integration tests on your desktop environment:

```bash
flutter test integration_test -d macos
# or -d windows / -d linux
```

## Test Environment Setup

The integration tests use a fully isolated environment to prevent side effects on the developer's actual data.

### 1. Temporary Storage

The file storage uses a temporary directory created for each test run.

- **Implementation**: `integration_test/helpers/test_storage.dart`
- **Behavior**: Creates a unique temp directory in the system temp location.
- **Cleanup**: The directory is recursively deleted in `tearDown`.
- **Note**: The `LocalDocumentFileStorage` is initialized with this temporary path.

### 2. In-Memory Database

The database layer uses an in-memory SQLite database (`sqlite3.openInMemory()`) to ensure speed and isolation.

- **Implementation**: `integration_test/helpers/test_database.dart`
- **Migrations**: Real SQL migration files from `assets/sql/migrations/` are loaded and applied using `MigrationRunner` via `rootBundle`. This ensures the test schema exactly matches the production schema.
- **FTS**: Full Text Search virtual tables are created and functional in the in-memory database.

## Test Assets

Integration tests require real files to test the pipeline (e.g., PDF parsing).

- **Location**: `integration_test/assets/`
- **Configuration**: These assets are included in `pubspec.yaml` under the `flutter: assets:` section.
- **Example**: `integration_test/assets/Example_PDF.pdf` (a small, valid PDF for happy-path testing).

## Platform OCR Integration Tests (Real Engine)

The test suites in `integration_test/tests/ocr_pipeline_real_macos_tests.dart`
and `integration_test/tests/ocr_pipeline_real_windows_tests.dart` exercise the
full pipeline with the **real** native OCR engine (Apple Vision on macOS, WinRT
`Windows.Media.Ocr` on Windows). They are skipped automatically when run on any
other platform, so they never block CI on Linux or in PR checks.

### When to run them

Run these tests manually before merging changes to the OCR adapters
(`lib/infrastructure/ocr/ocr_engine_macos.dart` or
`lib/infrastructure/ocr/ocr_engine_windows.dart`) or the PDF renderer.

### Running locally

On **macOS**:

```bash
flutter test integration_test -d macos
```

On **Windows** (PowerShell):

```powershell
flutter test integration_test -d windows
```

The platform guard (`integration_test/helpers/platform_guard.dart`) ensures
that only the tests for the current OS are executed; the other platform's group
is reported as skipped.

### Running in CI

A dedicated workflow at `.github/workflows/platform_ocr_integration.yml`
targets `macos-latest` and `windows-latest` runners and is triggered manually
via `workflow_dispatch`. It does not run on push or pull_request, so a failure
here never blocks merging on other platforms.

### What is asserted

Both tests verify the same contract against their respective engine:

1. The pipeline completes and the document reaches `DocumentStatus.completed`.
2. At least one page has non-empty `rawText`.
3. *(macOS only)* At least one page has a non-null `ocrConfidence` value —
   Apple Vision always returns a confidence score; Windows.Media.Ocr does not.

### Flakiness

OCR output on real documents can vary slightly across OS versions or language
pack configurations. If a test fails with an empty-text result on Windows,
confirm that at least one OCR language pack is installed
(`Settings → Time & Language → Language & Region`).
