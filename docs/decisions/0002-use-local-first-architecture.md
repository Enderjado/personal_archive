# Local-first architecture

Date: 2026-02-15

Status: Accepted

## Context

The system needs to work entirely offline on Windows and macOS. Users may process sensitive documents, so relying on external cloud services is not acceptable.

## Decision

All data processing, storage, OCR, and LLM inference must happen locally. No network calls are assumed in core logic. Cloud or network integration is optional and must be explicitly layered.

## Consequences

- + Ensures user privacy and offline functionality
- + Simplifies system guarantees: deterministic processing and reproducibility
- - Limits access to remote compute resources for heavy models
