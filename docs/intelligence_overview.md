# Intelligence Overview

This document connects the core architecture (`architecture.md`), the document pipeline (`pipeline.md`), and the Intelligence-specific Architecture Decision Records for Phase 4. It explains how local LLM-based features fit into the system without breaking the existing design principles.

---

## Role of Intelligence in the Architecture

Intelligence features (summaries, keywords, place suggestions, and future classifiers) live primarily in:

- The **application layer**: orchestrating when and how Intelligence stages run in the pipeline.
- The **domain layer**: defining contracts like `LLMService`, `KeywordExtractor`, `PlaceClassifier`, and value objects for summaries, keywords, and predictions.
- The **infrastructure layer**: providing concrete implementations backed by SQLite, llama.cpp, and platform-native OCR.

This preserves the Clean Architecture boundaries defined in `architecture.md`: the UI only observes results and triggers pipeline actions; it never talks directly to the LLM or the database.

Key baseline decisions:

- **Local LLM via llama.cpp** – ADR `0003-use-llama-cpp-for-local-llm.md`
- **Pipeline-driven processing** – ADR `0006-pipeline-driven-processing.md`
- **SQLite FTS5 design** – ADR `0011-sqlite-fts5-design.md`

Phase 4 builds Intelligence on top of these, rather than introducing a separate “AI sidecar” architecture.

---

## Processed Text and Storage Strategy

Intelligence operates on **cleaned, per-page text**:

- `pages.processed_text` is the canonical source for cleaned text.
- Document-level text views are **derived** by concatenating `pages.processed_text` in `page_number` order when needed.
- The FTS table `documents_fts` continues to index aggregated text from pages, summaries, and keywords (see `storage_conventions.md` and ADR 0011).

This is captured in:

- **ADR `0017-processed-text-storage-for-intelligence.md`**

Implications:

- Intelligence stages that need “the document text” must depend on:
  - `pages.processed_text` as their input source, and
  - a helper that aggregates page text deterministically.
- We avoid duplicating big “processed document text” blobs in multiple places and retain per-page traceability for debugging and reprocessing.

---

## Chunking and Token Budget

To run reliably on a local Qwen 2.5 0.5B model, Phase 4 defines a conservative chunking strategy:

- Effective context window: **~4,096 tokens** (for the configured GGUF model).
- Reserved budget:
  - ~25% of the window is reserved for prompts and output.
  - ~3,000 tokens are available for document content per request.
- Chunk size:
  - Target **1,000–1,500 tokens of document text per chunk**.
  - Use semantic boundaries where possible (paragraphs, then sentences), with small overlaps between chunks for continuity.

This is captured in:

- **ADR `0018-chunking-strategy-and-token-budget.md`**

In the pipeline (`pipeline.md`):

- Text processing and LLM analysis stages operate **one chunk at a time**.
- Per-document Intelligence results (e.g., a single summary) are assembled from chunk-level outputs using deterministic application-layer logic.

---

## LLM Defaults and Runtime Configuration

Intelligence relies on a predictable, configurable local LLM runtime:

- Model: **Qwen 2.5 0.5B Instruct GGUF** via llama.cpp.
- Context window: configured for **4,096 tokens**.
- Quantization: a medium-aggressive preset (e.g., Q4-class) tuned for CPU-only environments.
- Sampling defaults:
  - Temperature: **0.3–0.5**
  - Top-p: **0.9**
  - Top-k: **40**
  - Repeat penalty: **1.1–1.2**
  - Output limits: ~512 tokens for summaries, ~256 for keyword/label outputs.

These defaults are defined in:

- **ADR `0019-llm-default-configuration-for-intelligence.md`**

Configuration principles (consistent with `architecture.md` and `storage_conventions.md`):

- Model path, quantization variant, and sampling parameters are **externalized configuration**, not hard-coded.
- Task-specific overrides (e.g., shorter outputs for classification) stay within the global context limit and are documented near their use.

---

## Pipeline Behavior, Partial Results, and Re-runs

Intelligence extends the pipeline principles in `pipeline.md` and ADR 0006:

- Each Intelligence stage (summary, keywords, place suggestion, embeddings, etc.) is a **separate, testable step**.
- Stages are allowed to succeed or fail **independently**.
- Partial results are **persisted** and remain visible even if other stages fail.

This behavior is formalized in:

- **ADR `0020-intelligence-pipeline-behavior-and-partial-results.md`**

Key policies:

- **Document status vs. per-stage status**
  - `documents.status` still tracks high-level progress (`imported`, `processing`, `completed`, `failed`).
  - Intelligence stages internally track their own success/failure; optional stages may fail without forcing the document out of `completed`, but failures are logged and visible.

- **Re-runs**
  - Re-running Intelligence is **stage-level idempotent by default**:
    - A re-run overwrites prior outputs for that stage (e.g., summary text or document-keyword relations), while preserving timestamps and model version metadata.
  - Re-runs can target:
    - Failed stages (automatic or manual retry).
    - Specific stages the user wants to regenerate (e.g., “re-run analysis” from the UI).

This aligns with the broader pipeline principles:

- Atomic, deterministic steps.
- Observable, traceable behavior.
- Replaceable components in both domain and infrastructure layers.

---

## How to Use This Document

When designing or reviewing Phase 4 features, use this document as the entry point:

- For **high-level architecture** and layer boundaries, read `architecture.md`.
- For **end-to-end flow**, read `pipeline.md`.
- For **Intelligence-specific behavior and defaults**, start here and then:
  - Follow links to ADRs `0003`, `0006`, `0011`, `0017–0020`.
  - Cross-check schema expectations in `data_model.md` and `storage_conventions.md`.

Together, these documents describe how local-first Intelligence is integrated into the system without compromising the original architectural goals.

