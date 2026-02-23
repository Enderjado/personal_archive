# Externalized configuration

Date: 2026-02-15

Status: Accepted

## Context

Hardcoding parameters makes the system brittle and difficult to tune. Settings like OCR options, LLM paths, chunk sizes, and logging levels need to be adjustable without code changes.

## Decision

- Use a central configuration system loaded from environment variables or config files.
- All parameters related to model paths, OCR settings, database locations, chunk sizes, and concurrency limits are configurable.
- Defaults exist but can be overridden per user or session.

### OCR Settings (`OcrConfig`)

The OCR pipeline is configured via the `OcrConfig` value object. The following keys are supported:

| Key | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `dpi` | `int` | `300` | Image resolution for PDF page rendering. Higher values improve OCR accuracy but use more memory. |
| `languageHints` | `List<String>` | `[]` | Optional BCP-47 language hints (e.g., `['en', 'de']`) to improve recognition accuracy. |
| `timeoutPerPage` | `Duration?` | `null` | Optional timeout per page. If null, no timeout is enforced by the configuration. |
| `tempDir` | `String?` | `null` | Optional override directory for rendered page images. If null, the system temporary directory is used. |

*Note: `languageHints` and `timeoutPerPage` are forward-declared for upcoming OCR engine adapters and may not be consumed by all implementations.*

## Consequences

- + Makes the system flexible and adaptable to different machines
- + Simplifies testing different setups
- + Avoids hardcoded values scattered in code
- - Requires validation of configuration inputs
