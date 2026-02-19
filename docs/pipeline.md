# Document Processing Pipeline

This document describes the full pipeline for processing documents in the system. The pipeline defines the sequence of steps that transform a raw PDF into structured, searchable knowledge. It builds on the architecture defined in `architecture.md` and relies on the core entities and interfaces described in `data_model.md`.

---

## Overview

Every document flows through a deterministic pipeline that ensures:

* Reproducibility: Processing the same document produces consistent results.
* Observability: Every step is logged, with metrics and error handling.
* Isolation: Each stage is independently testable and replaceable.

For Phase 2 PDF import implementation details (objectives, scope, storage, validation, interfaces, and cleanup semantics), see `pdf_import_pipeline.md`.

The pipeline follows this sequence:


![Import PDF → Page Extraction → OCR → Text Processing → LLM Analysis → Keyword Extraction → Place Classification → Storage → Indexing → Search Availability](assets/Pipeline%20Visualization.png)


---

## Pipeline Stages

### 1. Document Import

**Responsibility:**

* Accept PDF input from the user.
* Validate file type, size, and accessibility.
* Generate a unique document ID and metadata.
* Store file location in the database.

**Interfaces:**

* `DocumentRepository.insert(Document)`

**Outputs:**

* Document entity with status `imported`

**Notes:**

* At this stage, the document is known to the system but has not been processed.
* Public implementation detail for Phase 2 lives in `pdf_import_pipeline.md`.

---

### 2. Page Extraction

**Responsibility:**

* Split PDF into individual pages.
* Convert each page into a format compatible with OCR (image or bitmap).
* Assign page numbers and maintain order.

**Interfaces:**

* `DocumentRepository.insertPages(List<Page>)`

**Outputs:**

* Page entities with raw placeholders for text.

**Notes:**

* Pages must be immutable once created; text content is added in later stages.

---

### 3. OCR (Optical Character Recognition)

**Responsibility:**

* Extract raw text from each page using platform-native OCR:

  * Windows: Microsoft OCR API
  * macOS: Apple Vision OCR
* Generate confidence scores for each page.
* Handle errors gracefully and allow retry.

**Interfaces:**

* `OCREngine.extractText(Page)`

**Outputs:**

* Updated Page entities with `rawText` and `confidenceScore`.

**Notes:**

* OCR is encapsulated behind an interface to allow swapping engines or upgrading in the future.

---

### 4. Text Processing

**Responsibility:**

* Clean OCR output: remove noise, correct encoding issues, normalize whitespace.
* Detect language and split content into logical sections if necessary.
* Deduplicate repeated text segments.

**Interfaces:**

* `TextProcessor.clean(String rawText)`
* `TextProcessor.chunk(String cleanedText)`

**Outputs:**

* `processedText` stored in Page entities
* Ready-to-analyze text passed to LLM

**Notes:**

* All transformations are deterministic and logged for reproducibility.

---

### 5. LLM Analysis

**Responsibility:**

* Use the local LLM (Qwen 2.5 0.5B via llama.cpp) to:

  * Summarize document text
  * Generate semantic embeddings for future search
  * Extract initial candidate keywords

**Interfaces:**

* `LLMService.summarize(String text)`
* `LLMService.extractKeywords(String text)`
* `LLMService.generateEmbeddings(String text)`

**Outputs:**

* Summary entity linked to Document
* Preliminary keywords list
* Embeddings stored in database

**Notes:**

* LLM runtime is managed by `LLMRuntime` to ensure proper memory usage and concurrency.

---

### 6. Keyword Extraction & Refinement

**Responsibility:**

* Post-process LLM-generated keywords:

  * Filter irrelevant terms
  * Calculate weights and importance
* Associate keywords with Document

**Interfaces:**

* `KeywordExtractor.refine(List<String>)`

**Outputs:**

* Keywords table updated in the database

**Notes:**

* Keywords are used for search ranking and filtering.

---

### 7. Place Classification

**Responsibility:**

Place is predicted based on the summary and keywords.
Stored as placeId in the document entity.

**Outputs:**

* Place-Document relationships stored in database

**Notes:**

* This enables grouping and visualization of documents by location.

---

### 9. User Input

**Responsibility:**

* User reviews the Summary, Keywords and Place
* Can make manuall changes like different Place
* Has the option to repeat the LLM Analysis

**Outputs:**

1. Accepted the Summary, Keywords and Place
2. Chose Repeat-option -> Pipeline goes back to 5. LLM Analysis 

---

### 10. Storage & Indexing

**Responsibility:**

* Persist all processed data:

  * Pages, text, summaries, keywords, places, embeddings
* Update document status to `completed`

**Interfaces:**

* `DocumentRepository.update(Document)`
* `SearchIndex.add(Document)`

**Outputs:**

* Fully structured, searchable document
* Index ready for fast queries

**Notes:**

* All storage operations must be atomic; partially processed documents remain traceable for retries.

---

### 10. Search Availability

**Responsibility:**

* Make the document discoverable through:

  * Full-text search
  * Keyword search
  * Place-based queries
  * (Future) semantic search using embeddings

**Interfaces:**

* `SearchService.query(...)`

**Outputs:**

* Document appears in UI and query results

**Notes:**

* Search layer is decoupled from the pipeline. Queries do not affect document state.

---

## Pipeline Principles

1. **Atomic Steps:** Each stage is a discrete, testable module.
2. **Deterministic Output:** Same input produces same output consistently.
3. **Observable:** Logs, timing, confidence scores, and errors are recorded.
4. **Isolated Failures:** Failures in one stage do not corrupt other stages; retry is possible.
5. **Replaceable Components:** OCR, LLM, and text processors can be swapped without touching domain logic.

---

