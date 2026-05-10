# Cactus Python SDK Reference

Platform: macOS, Linux (ARM / x86)
Source: `python/` directory in the main cactus repo
The Python SDK is a thin ctypes / FFI wrapper around the compiled `libcactus` shared library.

---

## Setup

```bash
# Clone and build the shared library
git clone https://github.com/cactus-compute/cactus && cd cactus
source ./setup          # sets up venv, compiles engine

# Build the Python-compatible shared lib
cactus build --python   # → build/libcactus.so (Linux) or build/libcactus.dylib (macOS)

# The Python module is inside python/ — import directly or add to your PYTHONPATH
# e.g.:
export PYTHONPATH="$PYTHONPATH:/path/to/cactus/python"
```

---

## Table of Contents

1. [Core Functions](#core-functions)
2. [Text Completion](#text-completion)
3. [Streaming](#streaming)
4. [Function Calling / Tools](#function-calling)
5. [Vision (VLM)](#vision)
6. [Speech-to-Text (STT)](#speech-to-text)
7. [Embeddings](#embeddings)
8. [RAG](#rag)
9. [Hybrid / Cloud Fallback](#hybrid)
10. [JSON Response Reference](#json-response-reference)

---

## Core Functions

```python
from cactus import (
    cactus_init,
    cactus_complete,
    cactus_transcribe,
    cactus_rag_query,
    cactus_reset,
    cactus_stop,
    cactus_destroy,
)
import json

# ── Init ────────────────────────────────────────────────────────
# Returns an opaque model handle (cactus_model_t / int ptr).
# weights_path: path to .cact weights folder
# context_size: token context window (default: 2048)
model = cactus_init(
    weights_path="weights/qwen3-0.6",
    context_size=2048,              # optional, default 2048
)

# ── Session management ───────────────────────────────────────────
cactus_reset(model)    # clear KV cache between conversations
cactus_stop(model)     # cancel a running generation
cactus_destroy(model)  # FREE MEMORY — always call when done
```

---

## Text Completion

```python
messages = json.dumps([
    {"role": "system", "content": "You are a helpful assistant."},
    {"role": "user",   "content": "What is the capital of France?"},
])

options = json.dumps({
    "max_tokens":      200,
    "temperature":     0.7,
    "top_p":           0.9,
    "stop_sequences":  ["<|im_end|>", "<end_of_turn>"],
})

raw = cactus_complete(
    model,          # model handle from cactus_init
    messages,       # JSON string — array of {role, content}
    options,        # JSON string — generation params (or None)
    tools=None,     # JSON string — tools array (or None)
    callback=None,  # streaming callback fn (or None)
)

result = json.loads(raw)
if result["success"]:
    print(result["response"])
    print(f"Tokens/s: {result['decode_tps']:.1f}")
    print(f"TTFT:     {result['time_to_first_token_ms']:.1f}ms")
else:
    print(f"Error: {result['error']}")
```

---

## Streaming

```python
import sys

def on_token(token: str) -> int:
    """Return 1 to continue, 0 to stop."""
    sys.stdout.write(token)
    sys.stdout.flush()
    return 1

raw = cactus_complete(
    model,
    messages,
    options,
    tools=None,
    callback=on_token,
)
print()  # newline after stream
result = json.loads(raw)
print(f"\nTotal time: {result['total_time_ms']:.0f}ms")
```

---

## Function Calling

```python
tools = json.dumps([
    {
        "type": "function",
        "function": {
            "name":        "get_weather",
            "description": "Get current weather for a location",
            "parameters": {
                "type": "object",
                "properties": {
                    "location": {
                        "type":        "string",
                        "description": "City name"
                    }
                },
                "required": ["location"]
            }
        }
    }
])

messages = json.dumps([
    {"role": "user", "content": "What's the weather in Chennai?"}
])

raw = cactus_complete(model, messages, options, tools=tools)
result = json.loads(raw)

if result["success"]:
    print(result["response"])
    for call in result.get("function_calls", []):
        print(f"Tool call: {call['name']}({call['arguments']})")
```

---

## Vision (VLM)

```python
# Use a vision-capable model (e.g. lfm2-vl-450m)
vlm = cactus_init("weights/lfm2-vl-450m", 2048)

messages = json.dumps([
    {"role": "system", "content": "You analyse images."},
    {
        "role":    "user",
        "content": "What do you see in this image?",
        "images":  ["/absolute/path/to/image.jpg"]  # list of paths
    }
])

raw = cactus_complete(vlm, messages, options)
result = json.loads(raw)
print(result["response"])

cactus_destroy(vlm)
```

---

## Speech-to-Text (STT)

```python
whisper = cactus_init("weights/whisper-small", 2048)

# Transcribe a WAV file (16-bit PCM, 16 kHz, mono)
prompt = "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"

raw = cactus_transcribe(
    whisper,              # model handle
    "audio.wav",          # audio file path (or None if using pcm_buffer)
    prompt=prompt,        # whisper prompt string
    options=None,         # JSON options string (or None)
    pcm_buffer=None,      # bytes-like object (16-bit PCM, min 32000 bytes)
)

result = json.loads(raw)
if result["success"]:
    print(result["response"])   # transcribed text
else:
    print(f"Error: {result['error']}")

cactus_destroy(whisper)
```

### STT from PCM buffer (microphone)

```python
import numpy as np

# pcm_buffer: int16 numpy array at 16kHz, mono
pcm_array  = np.frombuffer(raw_bytes, dtype=np.int16)
pcm_bytes  = pcm_array.tobytes()           # must be >= 32000 bytes

raw = cactus_transcribe(
    whisper,
    audio_path=None,
    prompt=prompt,
    pcm_buffer=pcm_bytes,
)
```

### Streaming Transcription

```python
def on_stt_token(token: str) -> int:
    sys.stdout.write(token)
    sys.stdout.flush()
    return 1

raw = cactus_transcribe(whisper, "audio.wav", prompt=prompt, callback=on_stt_token)
```

---

## Embeddings

```python
# Initialize with embedding support
embed_model = cactus_init("weights/qwen3-0.6", 2048)

text = "The quick brown fox jumps over the lazy dog"

raw = cactus_complete(
    embed_model,
    json.dumps([{"role": "user", "content": text}]),
    json.dumps({"task": "embed", "max_tokens": 1}),
)

result = json.loads(raw)
# result["embeddings"] → List[float]
print(f"Dimensions: {len(result['embeddings'])}")
```

---

## RAG

```python
# Init with a RAG corpus directory
rag_model = cactus_init(
    "weights/lfm2-rag",
    context_size=2048,
    corpus_dir="./documents"   # dir of .txt files for auto-indexing
)

# Query corpus
chunks_raw = cactus_rag_query(
    rag_model,
    "What is machine learning?",  # query text
    top_k=3                        # number of chunks to return
)

chunks = json.loads(chunks_raw)
for c in chunks:
    print(f"Score: {c['score']:.2f}  Source: {c['source']}")
    print(f"  {c['text'][:120]}...")

# Use retrieved chunks in a completion
context = "\n\n".join(c["text"] for c in chunks)
messages = json.dumps([
    {"role": "system", "content": f"Use this context:\n{context}"},
    {"role": "user",   "content": "What is machine learning?"},
])
raw = cactus_complete(rag_model, messages, options)
```

---

## Hybrid / Cloud Fallback

```python
options = json.dumps({
    "max_tokens":  200,
    "mode":        "localfirst",      # or: local | remotefirst | remote
    "cactus_token": "YOUR_API_TOKEN", # required for cloud fallback
})

raw = cactus_complete(model, messages, options)
result = json.loads(raw)

if result["cloud_handoff"]:
    print("⚡ Handled by cloud model")
else:
    print("📱 Handled on-device")
print(result["response"])
```

### Mode values

| `mode` | Behaviour |
|---|---|
| `"local"` | Strict on-device (default) |
| `"localfirst"` | On-device first, falls back to cloud |
| `"remotefirst"` | Cloud first, falls back to device |
| `"remote"` | Cloud only |

---

## JSON Response Reference

All `cactus_complete` / `cactus_transcribe` calls return a JSON string:

```python
{
  "success":               bool,    # True on success
  "error":                 str|None,
  "cloud_handoff":         bool,    # True if cloud model was used
  "response":              str,     # generated text / transcription
  "function_calls": [              # populated on tool use
    {
      "name":      str,
      "arguments": dict             # parsed JSON arguments
    }
  ],
  "embeddings":            list[float],   # only for embed tasks
  "confidence":            float,
  "time_to_first_token_ms": float,
  "total_time_ms":          float,
  "prefill_tps":            float,
  "decode_tps":             float,
  "ram_usage_mb":           float,
  "prefill_tokens":         int,
  "decode_tokens":          int,
  "total_tokens":           int
}
```

---

## Complete Working Example

```python
import json, sys
from cactus import cactus_init, cactus_complete, cactus_destroy, cactus_reset

# ── Init ────────────────────────────────────────────────────────
model = cactus_init("weights/qwen3-0.6", context_size=2048)

# ── Conversation loop ────────────────────────────────────────────
history = [{"role": "system", "content": "You are a helpful assistant."}]

def chat(user_input: str) -> str:
    history.append({"role": "user", "content": user_input})

    tokens = []
    def stream(t):
        tokens.append(t)
        sys.stdout.write(t); sys.stdout.flush()
        return 1

    raw = cactus_complete(
        model,
        json.dumps(history),
        json.dumps({"max_tokens": 300, "temperature": 0.7}),
        callback=stream,
    )
    print()

    result = json.loads(raw)
    response = result["response"]
    history.append({"role": "assistant", "content": response})
    return response

chat("What is on-device AI?")
chat("Name three use cases for it.")

# ── Clean up ────────────────────────────────────────────────────
cactus_destroy(model)
```
