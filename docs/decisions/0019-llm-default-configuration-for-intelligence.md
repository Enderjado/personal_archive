# LLM default configuration for Intelligence (Qwen 2.5 0.5B via llama.cpp)

Date: 2026-02-25

Status: Accepted

## Context

ADR 0003 decided to use **Qwen 3.0 0.6B** running locally via **llama.cpp** as the Intelligence model for summarization, keyword extraction, place detection, and future classification tasks.

To keep behavior predictable and reproducible across environments, we need a **default configuration** for:

- Model variant (GGUF file),
- Context window,
- Quantization,
- Core sampling parameters.

These defaults should be:

- Safe for typical local hardware (CPU + RAM).
- Tunable via configuration without changing code.
- Stable enough that other docs and tests can assume them.

## Decision

- **Model variant**
  - Default to a **Qwen 3 0.6B Instruct GGUF** model suitable for CPU-only inference.
  - The concrete GGUF filename and download location are configured in the application configuration (not hard-coded in code).

- **Context window**
  - Configure llama.cpp with an **effective context window of 4,096 tokens** for Phase 4.
  - Intelligence services should treat this as the **maximum budget**, with chunking rules from ADR 0018 ensuring we do not exceed it.

- **Quantization**
  - Use a **medium-aggressive quantization** preset (e.g., `Q4_K`-class) that:
    - Fits comfortably in RAM on typical developer machines.
    - Keeps latency acceptable for interactive use.
  - The exact quantization level is specified in configuration (e.g., model filename), and can be overridden per environment.

- **Sampling parameters (defaults)**
  - Temperature: **0.3–0.5** (low to medium; favors determinism with slight variability).
  - Top-p: **0.9**.
  - Top-k: **40**.
  - Repeat penalty: **1.1–1.2** (to reduce repetition in long generations).
  - Maximum output tokens:
    - Summaries: **up to ~512 tokens**.
    - Keyword/label outputs: **up to ~256 tokens**.
  - These values are defined as **configurable defaults** in the LLM service; tasks may override them when justified (e.g., shorter outputs for classification).

## Consequences

- **Pros**
  - + Predictable behavior across environments and runs.
  - + Reasonable performance on local hardware without requiring a GPU.
  - + Shared defaults simplify pipeline configuration and testing.

- **Cons / Trade-offs**
  - - Conservative context and quantization choices may limit maximum quality compared to larger or less-quantized models.
  - - Some tasks might benefit from more diversity or higher temperature and will need explicit overrides.

- **Implications for future iterations**
  - Changes to the **default model size, quantization, or context window** should trigger:
    - Performance and quality benchmarking.
    - A follow-up ADR if the change is substantial (e.g., moving to a larger model or a very different quantization).
  - Task-specific overrides must remain within the global limits of the configured context window and sampling constraints and should be documented near the task-specific code and/or in future ADRs if they represent a broad policy shift.

