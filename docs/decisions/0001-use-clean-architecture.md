# Adopt Clean Architecture as project structure

Date: 2026-02-15

Status: Accepted

## Context

The project involves multiple complex modules (OCR, LLM, PDF parsing, storage, UI). Without a clear separation of concerns, code quickly becomes entangled and unmaintainable. Previous experiences show that mixed UI/business logic layers and tight coupling make testing and replacing components difficult.

## Decision

Use Clean Architecture with strict layer boundaries:

- Presentation → Application → Domain → Infrastructure
- Domain layer contains entities, value objects, and interfaces only.
- Application layer orchestrates pipelines and use cases.
- Infrastructure layer implements the interfaces (OCR, LLM, storage, PDF parsing, etc.)
- Presentation layer (Flutter UI) observes application state, contains no business logic.

## Consequences

- + Easy to test domain and application layers independently
- + Components like OCR engine or LLM can be replaced without affecting business logic
- + Clear dependency direction simplifies onboarding and collaboration
- - Slight initial overhead in structuring the layers
