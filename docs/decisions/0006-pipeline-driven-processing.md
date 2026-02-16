# Pipeline-driven processing

Date: 2026-02-15

Status: Accepted

## Context

Processing involves multiple stages: PDF import → OCR → text cleaning → summarization → keyword extraction → place detection → indexing. Without a pipeline, stages could become tangled and inconsistent.

## Decision

Implement a deterministic, orchestrated pipeline:

- Each stage is isolated
- Failures propagate explicitly
- Progress can be monitored
- Stages can be parallelized safely

## Consequences

- + Predictable, observable processing
- + Easier testing and retry logic
- + Scales with additional stages
- - Initial implementation overhead
