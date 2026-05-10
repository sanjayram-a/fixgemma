# Cactus React Native SDK Reference

Package: `cactus-react-native`
GitHub: github.com/cactus-compute/cactus-react-native
Platforms: iOS 12.0+, Android API 24+

---

## Table of Contents

1. [Installation](#installation)
2. [CactusLM — Imperative API](#cactuslm-imperative)
3. [useCactusLM — React Hook API](#usecactuslm-hook)
4. [CactusVLM — Vision](#cactusvlm)
5. [Streaming](#streaming)
6. [Embeddings](#embeddings)
7. [Function Calling & Agent Loops](#function-calling)
8. [Inference Modes / Cloud Fallback](#inference-modes)
9. [Type Reference](#type-reference)
10. [Legacy `.init()` API](#legacy-api)

---

## Installation

```bash
npm install cactus-react-native react-native-nitro-modules
# or
yarn add cactus-react-native react-native-nitro-modules

# iOS only
npx pod-install
```

---

## CactusLM — Imperative API

### Basic Completion

```typescript
import { CactusLM } from 'cactus-react-native';

const lm = new CactusLM();

// Download model by slug (default: "qwen3-0.6")
await lm.download({
  model:      "qwen3-0.6",
  onProgress: (progress: number) => {
    console.log(`Download: ${Math.round(progress * 100)}%`);
  }
});

const messages: Message[] = [
  { role: 'system',    content: 'You are a helpful assistant.' },
  { role: 'user',      content: 'What is on-device AI?' }
];

const result: CompletionResult = await lm.complete({ messages });
console.log(result.response);
console.log(`${result.timings?.predicted_per_second.toFixed(1)} tok/s`);

// Always free when done
await lm.destroy();
```

### CactusLM API

```typescript
class CactusLM {
  // Download model weights — slug or custom path
  download(options: {
    model?:      string;    // slug, default: "qwen3-0.6"
    onProgress?: (progress: number) => void;   // 0.0–1.0
  }): Promise<void>

  // Run a completion (optionally streaming via onToken)
  complete(options: CompleteOptions): Promise<CompletionResult>

  // Generate text embeddings
  embed(text: string, options?: EmbedOptions): Promise<EmbeddingResult>

  // Release native memory
  destroy(): Promise<void>
}
```

---

## useCactusLM — React Hook API

Manages model state, download progress, and live streaming automatically.
Designed for integration into React component trees.

```typescript
import { useCactusLM } from 'cactus-react-native';

const App = () => {
  const lm = useCactusLM();

  // Download on first launch
  useEffect(() => {
    if (!lm.isDownloaded && !lm.isDownloading) {
      lm.download({ model: "qwen3-0.6" });
    }
  }, []);

  const handleSend = () => {
    lm.complete({
      messages: [
        { role: 'system', content: 'You are concise.' },
        { role: 'user',   content: inputText }
      ],
      temperature: 0.7,
      n_predict:   200,
    });
  };

  // Download progress
  if (lm.isDownloading) {
    return <Text>Downloading… {Math.round(lm.downloadProgress * 100)}%</Text>;
  }

  return (
    <View>
      <TextInput value={inputText} onChangeText={setInputText} />
      <Button
        title={lm.isGenerating ? 'Generating…' : 'Send'}
        onPress={handleSend}
        disabled={lm.isGenerating || !lm.isDownloaded}
      />
      {/* completion updates live as tokens stream in */}
      <Text>{lm.completion}</Text>
    </View>
  );
};
```

### useCactusLM Properties & Methods

```typescript
// ── State (reactive) ─────────────────────────────────────────────
lm.isDownloaded:     boolean   // model is ready to use
lm.isDownloading:    boolean   // download in progress
lm.downloadProgress: number    // 0.0–1.0
lm.isGenerating:     boolean   // inference in progress
lm.completion:       string    // live-updated response text

// ── Methods ──────────────────────────────────────────────────────
lm.download(options?: {
  model?:      string;
  onProgress?: (p: number) => void;
}): Promise<void>

lm.complete(options: CompleteOptions): Promise<CompletionResult>

lm.destroy(): Promise<void>
```

---

## CactusVLM — Vision

For models that support image input (e.g. `lfm2-vl-450m`, `lfm2.5-vl-1.6b`).

```typescript
import { CactusLM } from 'cactus-react-native';

// Use a vision-capable model
const lm = new CactusLM();
await lm.download({ model: "lfm2-vl-450m" });

const result = await lm.complete({
  messages: [
    { role: 'system', content: 'You analyse images.' },
    {
      role:    'user',
      content: 'Describe what you see.',
      images:  ['/absolute/path/to/image.jpg']   // List<string> of file paths
    }
  ],
  n_predict:   300,
  temperature: 0.3,
});

console.log(result.response);
await lm.destroy();
```

---

## Streaming

Pass `onToken` to receive each token as it is generated.

```typescript
const result = await lm.complete({
  messages: [{ role: 'user', content: 'Write me a poem.' }],
  onToken:  (token: string) => {
    process.stdout.write(token);
  }
});

console.log('\n--- Done ---');
console.log(`Total tokens: ${result.timings?.predicted_n}`);
```

Streaming also works with `useCactusLM` — the `lm.completion` property updates
automatically with each token so the UI re-renders in real time.

---

## Embeddings

```typescript
const result: EmbeddingResult = await lm.embed(
  'The quick brown fox jumps over the lazy dog',
  { normalize: true }
);

console.log(`Dimension: ${result.embedding.length}`);
console.log(`First 5:  ${result.embedding.slice(0, 5)}`);
```

---

## Function Calling & Agent Loops

### Single Tool Call

```typescript
const tools: Tool[] = [
  {
    type: 'function',
    function: {
      name:        'get_weather',
      description: 'Get current weather for a location',
      parameters: {
        type: 'object',
        properties: {
          location: {
            type:        'string',
            description: 'City name'
          }
        },
        required: ['location']
      }
    }
  }
];

const result = await lm.complete({
  messages: [{ role: 'user', content: "What's the weather in Chennai?" }],
  tools,
});

if (result.tool_calls?.length) {
  for (const call of result.tool_calls) {
    console.log(`Call: ${call.name}  Args:`, call.arguments);
    // Execute tool, feed result back in next turn
  }
} else {
  console.log(result.response);
}
```

### Agent Loop

```typescript
const messages: Message[] = [
  { role: 'user', content: "Get the weather in Tokyo then London." }
];

while (true) {
  const result = await lm.complete({ messages, tools });

  if (!result.tool_calls?.length) {
    console.log('Final:', result.response);
    break;
  }

  messages.push({ role: 'assistant', content: result.response });

  for (const call of result.tool_calls) {
    const output = await executeToolCall(call.name, call.arguments);
    messages.push({
      role:    'tool',
      content: JSON.stringify({ tool: call.name, result: output }),
    });
  }
}
```

---

## Inference Modes / Cloud Fallback

```typescript
// Pass mode string in options
const result = await lm.complete({
  messages:     [{ role: 'user', content: 'Hello!' }],
  mode:         'localfirst',          // see table below
  cactus_token: 'your_api_token',      // required for cloud fallback
});
```

| `mode` string | Behaviour |
|---|---|
| `"local"` | Strict on-device **(default)** |
| `"localfirst"` | Device first, falls back to cloud |
| `"remotefirst"` | Cloud first, falls back to device |
| `"remote"` | Cloud only — needs `cactus_token` |

---

## Type Reference

```typescript
// ── Messages ──────────────────────────────────────────────────────
type Message = {
  role:    'user' | 'assistant' | 'system' | 'tool';
  content: string;
  images?: string[];    // absolute file paths (vision models)
}

// ── Completion ────────────────────────────────────────────────────
type CompleteOptions = {
  messages:      Message[];
  onToken?:      (token: string) => void;
  tools?:        Tool[];
  n_predict?:    number;            // max tokens to generate
  temperature?:  number;            // 0.0–2.0
  top_k?:        number;
  top_p?:        number;
  stop?:         string[];          // stop sequences
  mode?:         'local' | 'localfirst' | 'remotefirst' | 'remote';
  cactus_token?: string;            // required for cloud modes
}

type CompletionResult = {
  response:     string;
  tool_calls?:  ToolCall[];
  timings?: {
    predicted_per_second: number;   // decode tokens/sec
    prompt_n:             number;   // prefill tokens
    predicted_n:          number;   // decode tokens
  }
}

// ── Embeddings ────────────────────────────────────────────────────
type EmbedOptions = {
  normalize?: boolean;   // L2 normalise output (default: true)
}

type EmbeddingResult = {
  embedding: number[];
}

// ── Tools ─────────────────────────────────────────────────────────
type Tool = {
  type:     'function';
  function: {
    name:        string;
    description: string;
    parameters: {
      type:        'object';
      properties:  Record<string, {
        type:        string;
        description: string;
        enum?:       string[];
      }>;
      required?:   string[];
    }
  }
}

type ToolCall = {
  name:      string;
  arguments: Record<string, unknown>;
}
```

---

## Legacy API

Older versions of the SDK used a static `.init()` pattern. Still valid when
working with local GGUF files:

```typescript
import { CactusLM, CactusVLM } from 'cactus-react-native';

// LLM from local path
const { lm, error } = await CactusLM.init({
  model: '/path/to/model.gguf',
  n_ctx: 2048,
});
if (error) throw error;

const messages = [{ role: 'user', content: 'Hello!' }];
const params   = { n_predict: 200, temperature: 0.7 };
const response = await lm.completion(messages, params);
lm.release();

// VLM from local path
const { vlm, error: vlmError } = await CactusVLM.init({
  model:   '/path/to/vision-model.gguf',
  mmproj:  '/path/to/mmproj.gguf',
});
if (vlmError) throw vlmError;

const vlmResponse = await vlm.completion(
  [{ role: 'user', content: 'Describe this.' }],
  {
    images:      ['/path/to/image.jpg'],
    n_predict:   300,
    temperature: 0.3,
  }
);

// Embeddings (legacy)
const { lm: embedLM } = await CactusLM.init({
  model:     '/path/to/model.gguf',
  n_ctx:     2048,
  embedding: true,           // must be true to use embedding()
});
const { embedding } = await embedLM.embedding('Some text', { normalize: true });
embedLM.release();
```
