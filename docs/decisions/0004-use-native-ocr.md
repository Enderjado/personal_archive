# Native OCR engines for cross-platform

Date: 2026-02-15

Status: Accepted

## Context

PDFs must be converted to text reliably. Cross-platform support is required. Using external OCR libraries may add dependencies or licensing constraints.

## Decision

- Windows: Use native Microsoft OCR API
- macOS: Use native Apple OCR framework
- Wrap OCR behind an interface (`OCREngine`) so infrastructure details are hidden from domain/application layers.

## Consequences

- + Reliable text extraction with minimal dependencies
- + Platform-specific optimizations leveraged
- - Must maintain two adapters
- - Slight overhead in interface abstraction
