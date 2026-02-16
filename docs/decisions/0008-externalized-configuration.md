# Externalized configuration

Date: 2026-02-15

Status: Accepted

## Context

Hardcoding parameters makes the system brittle and difficult to tune. Settings like OCR options, LLM paths, chunk sizes, and logging levels need to be adjustable without code changes.

## Decision

- Use a central configuration system loaded from environment variables or config files.
- All parameters related to model paths, OCR settings, database locations, chunk sizes, and concurrency limits are configurable.
- Defaults exist but can be overridden per user or session.

## Consequences

- + Makes the system flexible and adaptable to different machines
- + Simplifies testing different setups
- + Avoids hardcoded values scattered in code
- - Requires validation of configuration inputs
