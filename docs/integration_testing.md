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
