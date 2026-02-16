# Local LLM via llama.cpp

Date: 2026-02-15

Status: Accepted

## Context

We need a local LLM to summarize documents, extract keywords, and detect places. Options include remote API calls, larger models, or local models. Remote APIs violate the local-first principle.

## Decision

Use Qwen 2.5 0.5B running locally via llama.cpp using direct C++ FFI from Dart/Flutter.

## Consequences

- + Works fully offline
- + Lightweight enough for local machines
- + Full control over memory and runtime
- - Requires careful resource management and lifecycle handling
- - LLM output may be slower than cloud alternatives
