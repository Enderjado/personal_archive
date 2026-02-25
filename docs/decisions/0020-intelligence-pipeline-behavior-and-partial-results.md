# Intelligence pipeline behavior: partial results and re-runs

Date: 2026-02-25

Status: Accepted

## Context

ADR 0006 established a **pipeline-driven processing** model for import, OCR, and downstream tasks.

Phase 4 extends this with Intelligence stages such as:

- Summarization,
- Keyword extraction,
- Place suggestion/detection,
- Future classification/annotation stages.

We need clear rules for:

- How the pipeline behaves when some Intelligence stages succeed and others fail.
- How **partial results** are stored and surfaced.
- How **re-runs** work (idempotency, overwriting vs. appending).

These rules must keep the system observable and predictable without locking us into brittle all-or-nothing behavior.

## Decision

- **Stage-level independence with explicit status**
  - Intelligence stages are modeled as **independent steps** within the overall pipeline (continuing the spirit of ADR 0006).
  - Each stage has its own success/failure semantics and can complete even if others fail.
  - The document’s overall `status` remains aligned with the existing enum:
    - `completed` means: all **required** Intelligence stages have either:
      - succeeded, or
      - been explicitly skipped/disabled by configuration.
    - Non-required/optional stages may fail without forcing the document out of `completed`, but their failure is still logged and visible.

- **Partial results policy**
  - If a stage produces output (e.g., summary, keywords) and reports success:
    - The output is **persisted** (e.g., in `summaries`, `document_keywords`, or a stage-specific table).
    - Other failing stages do **not** invalidate already stored results.
  - UI and APIs must be able to indicate **which Intelligence stages have data** and which failed or are pending.

- **Re-run semantics**
  - Re-running Intelligence for a document is **idempotent at the stage level**:
    - By default, a re-run of a stage **overwrites** its previous outputs for that document (e.g., new summary replaces old summary, keyword relations are recalculated).
    - Historical results and logs (e.g., timestamps, model versions) are preserved as metadata where stored (e.g., `model_version`, `created_at` columns) to maintain auditability.
  - Re-runs may be triggered:
    - Automatically for failed stages (retry policies).
    - Manually, via user actions (e.g., “re-run Intelligence” on a document).
  - The re-run policy is **per stage**:
    - A stage can be selectively re-run without forcing all stages to re-execute.

## Consequences

- **Pros**
  - + Robust to intermittent failures: successful stages do not get rolled back unnecessarily.
  - + Clear user-facing behavior: partial results are visible and explainable.
  - + Supports iterative improvements: re-running Intelligence after model, prompt, or configuration changes is straightforward.

- **Cons / Trade-offs**
  - - Overwriting stage outputs on re-run means we do not keep multiple historical versions of summaries/keywords by default (beyond timestamps and model version metadata).
  - - UI and API layers must handle and display per-stage status, which is more complex than a single “done/not-done” flag.

- **Implications for future work**
  - Any new Intelligence stage must:
    - Fit into this **stage-level independent** model.
    - Define what counts as “required” vs “optional” for document `completed` status.
    - Persist outputs in a way that supports overwrite-on-re-run with clear metadata (timestamps, model version, source).
  - If future requirements demand full version history of Intelligence outputs, a dedicated versioning/mutation log can be introduced in a separate ADR, building on these baseline semantics.

