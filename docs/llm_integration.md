# Local LLM Integration (Qwen 2.5 via llama.cpp)

This document summarizes how the local Qwen 2.5 (0.5B) model is integrated into the application without exposing implementation details or code. It connects the internal integration plan from `.preparation/llm_integration.md` with the public architecture described in:

- `architecture.md`
- `pipeline.md`
- `intelligence_overview.md`
- ADRs `0003`, `0017–0020`

The goal is to explain how the LLM fits into the system from a **design and behavior** perspective rather than as a step‑by‑step build guide.

---

## High-Level Runtime Architecture

To keep the UI responsive and follow the Clean Architecture boundaries:

- **Inference runs in a dedicated isolate**:
  - Heavy work (model loading, token generation) happens in a background isolate.
  - Communication with the main isolate (UI layer) uses message passing (ports), which allows streaming partial results (e.g., tokens or text chunks) back to the UI.
- **LLM access is encapsulated behind domain/application interfaces**:
  - The domain defines contracts such as `LLMService` and higher-level services for summarization and extraction.
  - The concrete implementation in the infrastructure layer is responsible for:
    - Managing the native llama.cpp runtime.
    - Owning the model context and configuration.
    - Translating domain requests into low-level inference calls and back.

This ensures that:

- The UI never calls native code directly.
- The rest of the system remains testable with mocks and stubbed LLM implementations.

---

## Native Engine Integration (llama.cpp via FFI)

The project uses `llama.cpp` as the underlying inference engine:

- **Shared native library**:
  - On each supported platform (Windows, macOS), llama.cpp is built as a shared library and bundled with the application.
  - The shared library exposes a C API defined in `llama.h`.
- **Generated bindings**:
  - Dart FFI bindings are generated from the `llama.h` header using a binding generator (e.g., `ffigen`), producing a strongly typed Dart interface for the native functions.
  - These bindings are used only within the infrastructure layer.
- **Boundary responsibilities**:
  - The FFI boundary is thin and mechanical: it forwards calls like model initialization, tokenization, decoding, and sampling.
  - All higher-level logic (prompts, chunking, task orchestration) lives in Dart, above the FFI layer, and is described in `intelligence_overview.md` and the relevant ADRs.

From the perspective of the rest of the application, llama.cpp is simply a local engine that implements the `LLMService` contract.

---

## Model Distribution and Lifecycle

The Qwen 2.5 0.5B Instruct model is distributed as a **GGUF file**:

- **First-run model acquisition**:
  - On first use, the application ensures the configured GGUF model file is present in an application-specific directory (e.g., under `Application Support`).
  - If the file is missing, the application can download it from a configured location (for example, a public model hosting provider), honoring the project’s local-first principle by:
    - Making this download explicit to the user.
    - Allowing offline operation once the model is present.
- **Subsequent runs**:
  - Subsequent launches reuse the existing on-disk model file.
  - The model path and version are controlled via configuration, not hard-coded.

Model lifecycle management aligns with ADR `0019-llm-default-configuration-for-intelligence.md`:

- The runtime configures:
  - Context window (e.g., 4,096 tokens).
  - Quantization preset (e.g., a Q4‑class GGUF variant).
  - Default sampling parameters (temperature, top‑p, top‑k, repeat penalty, output limits).
- Intelligence services and pipelines use these defaults by default but may request task-specific overrides within the allowed limits.

---

## Inference Flow and Prompting (Conceptual)

At a high level, every LLM call follows the same conceptual cycle:

1. **Prompt construction**
   - The application formats input into the model’s expected chat or instruction format (e.g., a ChatML-style prompt for Qwen).
   - This includes both the **system-style instructions** (e.g., “you are a summarization model…”) and the **user content** (document text, chunk, or summary-of-summaries).
2. **Tokenization and context preparation**
   - Text is converted into token IDs understood by the model.
   - The pipeline respects the chunking and token budget rules from ADR `0018`, ensuring each request fits inside the configured context window.
3. **Decode–sample loop**
   - The engine repeatedly:
     - Processes the current tokens,
     - Produces logits (next-token probabilities),
     - Samples the next token based on configured sampling parameters.
   - Partial outputs can be streamed back to the UI or collected into a complete response.
4. **Post-processing**
   - The raw LLM output is interpreted according to the task:
     - Parsed as plain text for summaries.
     - Parsed into lists or structured fields for keywords and labels.
   - The domain layer then validates and persists results via repositories.

This process is applied consistently across summarization, keyword extraction, and future classification tasks, with only the prompts and expected output formats changing.

---

## Deployment Considerations (Windows and macOS)

The integration is designed to be **platform-aware but behaviorally identical** on Windows and macOS:

- The llama.cpp shared library is:
  - Bundled with the desktop application.
  - Loaded dynamically at runtime via FFI.
- Platform-specific packaging steps (e.g., build scripts, CMake configuration, or Xcode project settings) ensure that:
  - The shared library is present in the final application bundle.
  - Any required runtime permissions (such as network access for initial model download) are correctly configured.

These concerns are isolated to the build and deployment pipeline and do not affect domain or application logic.

---

## Performance and Resource Strategy

Performance and resource usage are managed in coordination with the Intelligence ADRs:

- **Context size and chunking**
  - Effective context window and chunk sizes are defined in ADR `0018-chunking-strategy-and-token-budget.md`.
  - The integration ensures that LLM calls honor these budgets to avoid excessive memory usage or degraded performance.
- **Quantization and model size**
  - Quantization choices (e.g., Q4 vs Q8) are guided by ADR `0019-llm-default-configuration-for-intelligence.md`, balancing:
    - Model quality,
    - RAM footprint,
    - Latency on typical local machines.
- **Concurrency and isolates**
  - Running inference in a dedicated isolate prevents UI freezes and allows controlled concurrency.
  - The system can limit the number of concurrent requests to avoid oversubscribing CPU and memory.

These strategies support the broader performance and observability goals described in `architecture.md` and `pipeline.md`.

---

## How This Fits with Other Documentation

Use this document together with:

- `intelligence_overview.md` for a functional view of what Intelligence does.
- `architecture.md` for layer boundaries and design principles.
- `pipeline.md` for the end-to-end document flow.
- ADRs `0003`, `0017–0020` for detailed design decisions about:
  - Local LLM choice and runtime,
  - Processed text storage,
  - Chunking and token budgets,
  - Default LLM configuration,
  - Pipeline behavior for partial results and re-runs.

Taken together, these documents explain **how** the local LLM is integrated and **why** it behaves the way it does, without exposing private implementation details.

