![presentation → application → domain → infrastructure](docs/assets/ReadmeHighlight.png)


# Local Document Intelligence Engine

A local-first system for turning raw PDFs into structured, searchable knowledge.

This project extracts text from documents, summarizes their content, organizes them into logical categories, and makes everything instantly searchable — entirely offline. The goal is to build a reliable knowledge engine that prioritizes clarity, reproducibility, and strong software architecture from the ground up.

This repository focuses not only on functionality, but on professional engineering practices: clear architecture, deterministic processing pipelines, strong data modeling, and maintainable system design.

---

## Vision

Modern document tools often rely on cloud services, opaque processing, and fragile workflows. This project explores a different approach:

* Everything runs locally.
* Processing is deterministic and observable.
* Documents are transformed into structured knowledge.
* Organization is semantic, not file-system driven.
* The system is designed to be understandable and maintainable.

The long-term goal is a personal knowledge infrastructure where documents are not just stored, but understood.

---

## Features

* Local PDF processing
* Native OCR on Windows and macOS
* Automatic text extraction and cleaning
* Document summarization using a local language model
* Automatic keyword extraction
* Logical document organization via categories (“Places”)
* SQLite-based storage
* Fast search across processed documents
* Fully offline operation
* Deterministic processing pipeline
* Replaceable system components

---

## System Overview

The system processes documents through a defined pipeline:

```
PDF → OCR → Text Processing → LLM Analysis → Keywords → Storage → Search
```

Documents are stored as structured entities with summaries, keywords, and metadata. Each document belongs to a logical category (“Place”), allowing semantic organization beyond traditional folders.

The architecture follows strict separation of concerns:

* **Presentation** — Flutter UI
* **Application** — Pipeline orchestration
* **Domain** — Core models and logic
* **Infrastructure** — OCR, database, and model runtime

This separation ensures the system is testable, extensible, and maintainable.

---

## Documentation

Detailed technical documentation lives in the `/docs` directory.

### Architecture

**[`docs/architecture.md`](docs/architecture.md)**
System structure, design principles, and layer boundaries.

### Processing Pipeline

**[`docs/pipeline.md`](docs/pipeline.md)**
How documents flow through the system from import to search.

### Data Model

**[`docs/data_model.md`](docs/data_model.md)**
Core entities, relationships, and database structure.

These documents describe the technical foundation of the project and should be read together.

---

## Tech Stack

* **Frontend:** Flutter (Dart)
* **OCR:** Native OS APIs (Windows / macOS)
* **Language Model:** Local model runtime via llama.cpp (Qwen2.5 0.5B)
* **Database:** SQLite
* **Storage:** Local file system
* **Execution:** Fully offline

All components are designed to be replaceable without affecting core business logic.

---

## Project Status

The project is currently in the foundational design phase. The focus is on:

* Architecture definition
* Data modeling
* Processing pipeline design
* System constraints and performance targets

Implementation follows after the technical foundation is fully defined.

---

## Design Principles

This project is guided by a few non-negotiable principles:

* Local-first execution
* Deterministic processing
* Clear system boundaries
* Replaceable infrastructure
* Strong observability
* Explicit resource management
* Professional engineering standards

The aim is not just to build a working system, but a well-engineered one.

---

## Why This Project Exists

Documents are one of humanity’s oldest information technologies. We store them, archive them, and lose them in chaotic folders. This project explores what happens when documents become structured knowledge objects instead of static files.

It’s an attempt to build a system where information is organized by meaning, not location.

---

## Testing

This project emphasizes reliability and maintainability through rigorous testing.

Please refer to the following documents for more details:
* [Integration Testing](docs/integration_testing.md) - How to run and extend end-to-end tests
* [Testing Philosophy](docs/decisions/0009-testing-philosophy.md) - The reasoning behind our testing approach

---

