# Chunking strategy and token budget for Intelligence

Date: 2026-02-25

Status: Accepted

## Context

Phase 4 Intelligence features (summarization, keyword extraction, place detection, future classifiers) run on a local Qwen 2.5 0.5B model via llama.cpp (see ADR 0003).

We need a **chunking strategy and token budget** that:

- Fits comfortably within the model’s context window.
- Balances quality (enough surrounding context) and performance (latency, CPU, memory).
- Works consistently across different Intelligence tasks and large documents.

This ADR defines **how we split text into LLM chunks** and how much of the context window we reserve for prompts vs. document content.

## Decision

- **Target context usage**
  - Assume a conservative **effective context window of ~4,096 tokens** for Qwen 2.5 0.5B in our local configuration.
  - Reserve **~25% of the window for system/user prompts and model output**, leaving **~3,000 tokens** for document content per request.

- **Chunk size**
  - Target **1,000–1,500 tokens of document text per chunk**.
  - This leaves headroom for:
    - Prompt scaffolding (instructions, examples).
    - Model output (summaries, keyword lists, classifications).

- **Chunk boundaries**
  - Chunking operates on **processed text** derived from `pages.processed_text` (see ADR 0017).
  - Prefer **semantic boundaries** in this order:
    1. Explicit paragraph breaks (double newlines or similar markers).
    2. Sentence boundaries (when paragraph sizes are uneven or too large).
    3. As a fallback, fixed token windows with small overlaps.
  - Allow **small overlaps** (e.g., 5–10% of chunk size) between neighboring chunks to preserve continuity, especially for summarization.

- **Pipeline integration**
  - Each Intelligence stage that works on “document text” processes **one chunk at a time**.
  - Per-document results (e.g., a single summary) are derived by **combining per-chunk outputs** according to stage-specific rules (e.g., summarize-each-chunk then summarize-the-summaries).

## Consequences

- **Pros**
  - + Keeps each request safely within the context window for the chosen local model.
  - + Reasonable latency and memory footprint on typical local machines.
  - + Works uniformly across Intelligence features and large documents.

- **Cons / Trade-offs**
  - - Summaries and keyword sets are influenced by chunk boundaries; global context is approximated via multi-step aggregation.
  - - Very large documents require multiple passes (more API calls, more total compute).

- **Implications for future tuning**
  - The numeric thresholds (4,096 effective context, 1,000–1,500 token chunk size, overlap percentage) are **configuration defaults**, not hard-coded magic numbers:
    - They should be exposed via configuration for tuning per environment.
    - Any change to default chunk sizes or reserved prompt budget should be validated against performance and quality benchmarks and, if significant, recorded as an update to this ADR or a superseding ADR.

