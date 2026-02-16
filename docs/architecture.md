# Technical Foundation – Phase 0

Before writing a single line of code, I wanted to define the rules of this project. This isn’t just a document scanner — it’s a local-first knowledge engine, a system that extracts, organizes, and makes information searchable, entirely offline. To build something robust and maintainable, I knew the foundation had to be solid. Phase 0 is about defining that foundation.

---

## Guiding Principles

This project follows a few core principles:

* **Local-first:** Everything runs offline. The system doesn’t rely on the internet.
* **Pipeline-driven:** Documents flow through defined stages — import, OCR, processing, summarization, keyword extraction, place classification, and indexing. Each step is deterministic and observable.
* **Replaceable:** Components like OCR engines, the LLM, and storage can be swapped without touching business logic.
* **Observable:** Every step is logged, measured, and traceable.
* **Resource-aware:** Memory, CPU, and model lifecycles are managed explicitly to prevent instability.

These principles guide every design decision. If a choice violates one of these, it doesn’t make it in.

---

## Architecture Overview

I adopted **Clean Architecture** with strict layer boundaries:

![presentation → application → domain → infrastructure](assets/Architecture%20Visualization.png)

* **Presentation layer:** Flutter UI. It observes application state but contains no business logic.
* **Application layer:** Orchestrates the workflow. It knows *what happens*, not *how*. This is where the document pipeline lives.
* **Domain layer:** Pure logic. It defines the core concepts — Document, Page, Summary, Keyword, PlacePrediction — and interfaces for repositories and services. It contains no platform-specific code or side effects.
* **Infrastructure layer:** Interfaces with reality. This includes SQLite, PDF parsing, native OCR on Windows/macOS, and the local LLM via llama.cpp.


This separation ensures clarity, testability, and replaceability. The UI never talks directly to the LLM or the database, and the domain layer doesn’t care if OCR is Microsoft’s API or Apple’s framework.

---

## Core Models

The system revolves around a few core entities:

* **Document:** Tracks metadata, status, and confidence scores.
* **Page:** Holds raw and processed text per page.
* **Summary:** Generated from document text.
* **Keyword:** Extracted automatically with weight scores.
* **PlacePrediction:** Assigns likely locations mentioned in the document with confidence.

These are designed to be immutable wherever possible. Any change to data is a controlled event, not random mutation.

---

## Interfaces & Contracts

I defined interfaces for every external service from the start:

* `DocumentRepository`
* `OCREngine`
* `LLMService`
* `TextProcessor`
* `KeywordExtractor`
* `PlaceClassifier`
* `SearchIndex`

This ensures all components can be replaced, mocked, or upgraded independently.

---

## Error Handling & Observability

Errors are structured and typed:

* Validation errors
* Processing errors
* Model errors
* Storage errors
* Platform errors
* Timeout errors

Everything is logged with timestamps, component info, operation, duration, and result. Silent failures are not allowed. Observability is part of the design — I want to know what happens at every step.

---

## Performance & Resource Management

From the start, I defined measurable targets:

* OCR latency per page
* LLM summarization time
* Document processing memory usage
* Maximum concurrent processing jobs
* Cold model load time

The LLM is treated as a managed resource, with explicit lifecycle control. Concurrency, caching, and background processing are considered from day one to avoid bottlenecks or crashes.

---

## Testing & Reliability

Testing isn’t optional — it’s built into the architecture:

* Unit tests for domain logic
* Integration tests for pipelines
* Mocked tests for OCR and LLM modules
* Performance and memory tests

Every layer can be tested independently. External systems are always mockable.

---

## Configuration & Flexibility

All parameters are externalized:

* Model paths
* OCR settings
* Chunk sizes
* Processing limits
* Database locations

Hardcoding is avoided entirely, so the system can adapt and evolve.

---

## Documentation & Decisions

All major design choices are documented in Architecture Decision Records. Every step, every trade-off, every limitation is noted. This makes the system transparent and maintainable, and shows the reasoning behind every decision.

