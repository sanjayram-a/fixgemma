---
name: cactus
description: >
  Complete authoritative reference skill for the Cactus AI inference engine
  (github.com/cactus-compute/cactus). ALWAYS load this skill before answering
  ANY question about Cactus syntax, APIs, usage, or code generation.
  Triggers include — but are not limited to — any of: CactusLM, CactusSTT,
  CactusRAG, CactusVLM, CactusAgentSession, CactusSTTSession, CactusVADSession,
  CactusTranscriptionStream, CactusIndex, cactus_init, cactus_complete,
  cactus_transcribe, cactus_rag_query, CactusGraph, CactusModel, CactusModelActor,
  flutter cactus package, kotlin cactus, swift-cactus, cactus-react-native,
  python cactus FFI, on-device LLM inference, edge AI mobile, local AI wearables,
  hybrid inference, tool calling on-device, RAG on mobile, NPU acceleration.
  Also triggers for: "how do I add AI to my Flutter/Swift/Kotlin/React Native app",
  "run LLM locally on Android/iOS", "on-device speech to text".
---

# Cactus — Complete Reference Skill

Cactus is a low-latency, energy-efficient AI inference engine for mobile devices
and wearables. It runs LLMs, VLMs, STT, embeddings, RAG, and VAD fully on-device,
with optional hybrid cloud fallback.

---

## 1 · Architecture

```
┌─────────────────┐
│  Cactus Engine  │  ←── OpenAI-compatible C API (chat, vision, STT, RAG, tools, cloud)
└────────┬────────┘
         │
┌────────▼────────┐
│  Cactus Graph   │  ←── Zero-copy computation graph (PyTorch for mobile)
└────────┬────────┘
         │
┌────────▼────────┐
│ Cactus Kernels  │  ←── ARM SIMD (Apple ANE, Snapdragon, Exynos NPUs)
└─────────────────┘
```

**Model format:** proprietary `.cact` (zero-copy memory-mapped, battery-optimised).
Pre-converted weights → huggingface.co/Cactus-Compute. Auto-downloaded by CLI.

---

## 2 · SDK Selection Guide

| Goal | Use | Reference |
|---|---|---|
| Flutter / Dart app (iOS + Android + macOS) | `cactus` pub package | `references/flutter.md` |
| Kotlin Multiplatform / Android-native | `com.cactuscompute:cactus` | `references/kotlin.md` |
| React Native app | `cactus-react-native` npm | `references/react_native.md` |
| Swift (iOS / macOS / tvOS / watchOS / Android) | `swift-cactus` SPM | `references/swift.md` |
| Python scripting / server / Mac/Linux | `python/` FFI + ctypes | `references/python.md` |
| Low-level C FFI or custom integration | `cactus.h` C API | Section 5 below |
| Custom neural-net ops | `CactusGraph` C++ API | Section 6 below |

**Rule:** Always read the relevant `references/<sdk>.md` before generating SDK code.

---

## 3 · CLI Reference (Dev Tool)

```bash
# ── One-time setup ────────────────────────────────────────────────
git clone https://github.com/cactus-compute/cactus && cd cactus
source ./setup              # builds venv, compiles cactus CLI, adds to PATH
# Ubuntu/Debian prereqs:
sudo apt-get install python3 python3-venv python3-pip cmake \
                     build-essential libcurl4-openssl-dev

# ── Auth ──────────────────────────────────────────────────────────
cactus auth                 # set/update Cloud API key
cactus auth --status        # show current key status
cactus auth --clear         # remove saved key

# ── Run interactive playground ────────────────────────────────────
cactus run <model>
cactus run <model> --precision INT4|INT8|FP16   # default: INT4
cactus run <model> --token <hf_token>           # gated HuggingFace models
cactus run <model> --reconvert                  # force re-conversion from source

# ── Speech transcription ──────────────────────────────────────────
cactus transcribe                               # live mic (default: parakeet-tdt-0.6b-v3)
cactus transcribe --file audio.wav              # from file
cactus transcribe <model> --precision INT4

# ── Model management ──────────────────────────────────────────────
cactus download <model>                         # downloads to ./weights/
cactus download <model> --precision INT4|INT8|FP16
cactus download <model> --token <hf_token>
cactus download <model> --reconvert

cactus convert <model> [output_dir]            # convert HF model → .cact
cactus convert <model> --lora <adapter_path>   # merge LoRA adapter first
cactus convert <model> --precision INT4

# ── Build SDKs ────────────────────────────────────────────────────
cactus build --apple        # iOS/macOS xcframework + static libs
cactus build --android      # Android JNILibs
cactus build --flutter      # Flutter (all platforms)
cactus build --python       # shared lib for Python FFI

# ── Testing ───────────────────────────────────────────────────────
cactus test
cactus test --model <slug> --benchmark
cactus test --llm | --stt | --performance
cactus test --ios           # run on connected iPhone
cactus test --android       # run on connected Android device
cactus test --precision INT4|INT8|FP16 --reconvert

cactus clean                # wipe all build artifacts
cactus --help
```

---

## 4 · Model Catalogue

| Slug | Features | Notes |
|---|---|---|
| `gemma3-270m` | completion | smallest, fastest |
| `functiongemma-270m` | completion, tools | function-call specialist |
| `qwen3-0.6` | completion, tools, embed | default model |
| `qwen3-1.7b` | completion, tools, embed | |
| `qwen3-embedding-0.6b` | embed only | |
| `lfm2-350m` | completion, tools, embed | |
| `lfm2-700m` | completion, tools, embed | |
| `lfm2-2.6b` | completion, tools, embed | |
| `lfm2-vl-450m` | vision, txt+img embed | Apple NPU |
| `lfm2.5-vl-1.6b` | vision, txt+img embed | Apple NPU |
| `lfm2.5-1.2b` | completion, tools, embed | |
| `lfm2.5-1.2b-thinking` | completion, tools, embed | thinking/reasoning |
| `whisper-tiny` | STT | Apple NPU |
| `whisper-base` | STT | Apple NPU |
| `whisper-small` | STT | Apple NPU |
| `whisper-medium` | STT | Apple NPU |
| `parakeet-ctc-0.6b` | STT | Apple NPU |
| `parakeet-ctc-1.1b` | STT | Apple NPU |
| `parakeet-tdt-0.6b-v3` | STT | Apple NPU |
| `moonshine-base` | STT | FP16 only |
| `silero-vad` | VAD | voice activity detection |
| `nomic-embed-text-v2-moe` | embed only | |

---

## 5 · C Engine API (`cactus.h`) — Core Layer

All SDKs are wrappers around this C FFI.

### Setup & Init

```c
#include "cactus.h"

// Optionally enable NPU acceleration (Pro key from founders@cactuscompute.com)
cactus_set_pro_key("your_pro_key");

// Initialize model — returns opaque handle
// context_size: token context window (typical: 2048)
cactus_model_t model = cactus_init(
    "path/to/weight/folder",   // .cact weights directory
    2048                        // context size (int)
);
// Older signature also accepts: cactus_init(path, corpus_dir, use_mmap)
```

### Chat Completion

```c
const char* messages = "["
    "{\"role\":\"system\",\"content\":\"You are helpful.\"},"
    "{\"role\":\"user\",\"content\":\"Hello!\"}"
"]";

const char* options = "{"
    "\"max_tokens\":200,"
    "\"stop_sequences\":[\"<|im_end|>\"],"
    "\"temperature\":0.7"
"}";

char response[4096];
int result = cactus_complete(
    model,               // cactus_model_t handle
    messages,            // JSON array of {role, content}
    response,            // output buffer (caller-allocated)
    sizeof(response),    // buffer size in bytes
    options,             // generation options JSON (or NULL)
    NULL,                // tools JSON array (or NULL)
    NULL,                // streaming callback fn ptr (or NULL)
    NULL                 // user_data for callback
);
// result: bytes written (>0) on success, negative on error
```

### Transcription (STT)

```c
cactus_model_t whisper = cactus_init("weights/whisper-small", 2048);

const char* prompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>";
char response[4096];

int result = cactus_transcribe(
    whisper,              // model handle
    "audio.wav",          // audio file path (16-bit PCM WAV)
    response,             // output buffer
    sizeof(response),     // buffer size
    prompt,               // whisper prompt (or NULL for default)
    NULL,                 // options JSON (or NULL)
    NULL,                 // PCM buffer (if not using file)
    0                     // PCM buffer size
);
```

### RAG Query

```c
// Model must be initialized with a corpus_dir
cactus_model_t rag_model = cactus_init(
    "weights/lfm2-rag",
    2048
);

// Query returns JSON array of chunk objects
// top_k: max chunks to return
const char* chunks_json = cactus_rag_query(
    rag_model,
    "What is machine learning?",  // query text
    3                              // top_k
);
// Each chunk: {"score": 0.92, "text": "...", "source": "..."}
```

### Session Management

```c
cactus_reset(model);     // clear KV cache — call between conversations
cactus_stop(model);      // cancel ongoing generation (streaming)
cactus_destroy(model);   // free all memory — ALWAYS call when done
```

### Response JSON Structure

```json
{
  "success":              true,
  "error":                null,
  "cloud_handoff":        false,
  "response":             "Hello! How can I help?",
  "function_calls":       [],
  "confidence":           0.82,
  "time_to_first_token_ms": 45.2,
  "total_time_ms":        163.7,
  "prefill_tps":          1621.9,
  "decode_tps":           168.4,
  "ram_usage_mb":         245.7,
  "prefill_tokens":       28,
  "decode_tokens":        50,
  "total_tokens":         78
}
```

### Streaming Callback Signature

```c
// callback receives one token at a time; return 0 to stop, 1 to continue
typedef int (*cactus_token_callback)(const char* token, void* user_data);

int my_callback(const char* token, void* user_data) {
    printf("%s", token);
    return 1;  // continue
}
cactus_complete(model, messages, response, sizeof(response),
                options, NULL, my_callback, NULL);
```

---

## 6 · C++ Graph API (`CactusGraph`)

For implementing custom neural-net operations at a low level.

```cpp
#include "cactus.h"

CactusGraph graph;

// Declare typed inputs
auto a = graph.input({2, 3}, Precision::FP16);   // shape, precision
auto b = graph.input({3, 4}, Precision::INT8);

// Build ops (lazy — not executed yet)
auto x1     = graph.matmul(a, b, false);           // (a @ b)
auto x2     = graph.transpose(x1);
auto result = graph.matmul(b, x2, true);           // (b @ x2.T)

// Feed data
float a_data[6]  = {1.1f, 2.3f, 3.4f, 4.2f, 5.7f, 6.8f};
float b_data[12] = {1,2,3,4,5,6,7,8,9,10,11,12};
graph.set_input(a, a_data, Precision::FP16);
graph.set_input(b, b_data, Precision::INT8);

// Execute graph
graph.execute();
void* out = graph.get_output(result);

// Reset (free intermediates, keep graph structure for reuse)
graph.hard_reset();
```

**Precision enum:** `FP32` · `FP16` · `INT8` · `INT4`
**Supported ops:** `matmul`, `transpose`, `attention`, layer-norm, RMS-norm,
`softmax`, `relu`, `gelu`, `silu`, embedding lookups, and more.

---

## 7 · Cross-SDK Concepts

### Inference / Completion Modes

| String (Python/Flutter) | Enum (Kotlin/Swift) | Behaviour |
|---|---|---|
| `"local"` | `LOCAL` | Strict on-device only **(default)** |
| `"localfirst"` | `LOCAL_FIRST` | On-device first, falls back to cloud |
| `"remotefirst"` | `REMOTE_FIRST` | Cloud first, falls back to device |
| `"remote"` | `REMOTE` | Strict cloud only — needs `cactusToken` |

### Tool Filtering (Flutter & Kotlin)

When many tools are provided, `ToolFilterService` automatically selects the most
relevant ones before sending to the model. **Enabled by default.**

| Strategy | Speed | Accuracy |
|---|---|---|
| `SIMPLE` | Fast — keyword matching | Good for most cases |
| `SEMANTIC` | Slower — embedding-based | Better for ambiguous queries |

Config: `ToolFilterConfig(strategy, maxTools, similarityThreshold=0.3)`

### Whisper STT Prompt Tokens

```
<|startoftranscript|>  — required first token
<|en|>                 — language (change for other langs)
<|transcribe|>         — transcription mode (vs <|translate|>)
<|notimestamps|>       — omit timestamps
```

Full default prompt: `"<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"`

### Audio Buffer Requirements (all SDKs)

- Format: **16-bit PCM**, signed, little-endian
- Sample rate: **16 kHz**
- Channels: **Mono (1)**
- Minimum size: **32 000 bytes** (≈ 1 second)

### Common Mistakes

| Mistake | Fix |
|---|---|
| Calling `generateCompletion` before `initializeModel` | Call `downloadModel` → `initializeModel` first |
| Missing `CactusContextInitializer.initialize(this)` on Android | Add to `Activity.onCreate()` |
| Passing `images` to a non-vision model | Check `model.supportsVision` first |
| Moonshine model at INT4/INT8 | Moonshine requires `--precision FP16` |
| Audio buffer < 32 000 bytes | Buffer ≥ 32 000 bytes required |
| Not calling `unload()` / `cactus_destroy()` | Always free memory when done |

---

## 8 · Fine-tuning & LoRA Deployment

```bash
# 1. Train with Unsloth (standard Unsloth workflow)
# 2. Convert + merge LoRA adapter with Cactus
cactus convert Qwen/Qwen3-0.6B ./output_weights --lora ./my-lora-adapter
# or from HuggingFace Hub:
cactus convert Qwen/Qwen3-0.6B ./output_weights --lora username/my-adapter

# 3. Test on Mac before deploying
cactus test --model ./output_weights

# 4. Deploy to iOS
cactus build --apple
# Link cactus-ios.xcframework in Xcode, then use as normal model
```

Supported base models for LoRA: Qwen3, LFM2, Gemma3 (check repo for updates).

---

## 9 · Performance Tips (All SDKs)

1. **Smaller models first** — `gemma3-270m` or `qwen3-0.6` for most mobile tasks
2. **INT4 quantisation** — ~50% RAM reduction, minimal quality loss
3. **Reduce context** — `contextSize=1024` instead of 2048 saves RAM
4. **Always call `unload()`** — GPU/NPU memory is a limited resource
5. **Reuse initialized models** — initialisation is expensive; don't re-init per request
6. **`reset()`** between conversations — clears KV cache without re-loading weights
7. **NPU acceleration** — requires Pro key; massive speedup on Apple/Qualcomm chips
8. **Isolate / background thread** — heavy inference should not run on the UI thread
9. **INT8 for quality-critical tasks** — better than INT4 at +~50% RAM cost
10. **`generateEmbeddings: true`** in init — required before calling embedding methods (Flutter legacy API)
