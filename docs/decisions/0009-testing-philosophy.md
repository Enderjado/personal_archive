# Testing philosophy

Date: 2026-02-15

Status: Accepted

## Context

Complex pipelines with external systems (OCR, LLM, storage) require strong testing discipline to ensure reliability and maintainability.

## Decision

- Domain layer is fully unit-testable with no external dependencies.
- Integration tests cover pipelines end-to-end with mocked external services.
- Infrastructure components (OCR, database, PDF parser) are tested independently.
- Performance and memory tests simulate realistic document loads.
- All tests must be reproducible and deterministic.

## Consequences

- + Bugs are caught early
- + Makes refactoring safe
- + Demonstrates professional engineering practices
- - Requires discipline and upfront work
