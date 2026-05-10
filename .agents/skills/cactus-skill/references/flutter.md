# Cactus Flutter SDK Reference

Package: `cactus` | pub.dev/packages/cactus | v1.3.0+
Platforms: iOS 12.0+, Android API 24+, macOS
Repo: github.com/cactus-compute/cactus-flutter
Install: `flutter pub add cactus`

---

## Table of Contents

1. [Configuration](#configuration)
2. [CactusLM — Language Model](#cactuslm)
3. [CactusSTT — Speech-to-Text](#cactusstt)
4. [CactusRAG — Retrieval-Augmented Generation](#cactusrag)
5. [Platform Setup](#platform-setup)
6. [Complete Data Class Reference](#data-classes)
7. [Performance Tips](#performance-tips)

---

## Configuration

```dart
import 'package:cactus/cactus.dart';

// Telemetry — enabled by default; disable for production if desired
CactusConfig.isTelemetryEnabled = false;

// Organisation telemetry token (optional)
CactusConfig.setTelemetryToken("your-token-here");

// NPU acceleration — requires Pro key (founders@cactuscompute.com)
CactusConfig.setProKey("your-pro-key-here");
```

---

## CactusLM

Primary class: text completions, streaming, function calling, vision, embeddings.

### Constructor

```dart
CactusLM({
  bool            enableToolFiltering = true,      // auto-select relevant tools
  ToolFilterConfig? toolFilterConfig,              // defaults to ToolFilterConfig.simple()
})
```

### Minimal Example

```dart
import 'package:cactus/cactus.dart';

Future<void> basicExample() async {
  final lm = CactusLM();
  try {
    // Download by slug — defaults to "qwen3-0.6" if omitted
    await lm.downloadModel(
      model: "qwen3-0.6",
      downloadProcessCallback: (progress, status, isError) {
        if (isError) {
          print("Error: $status");
        } else {
          print("$status ${progress != null ? '${(progress * 100).toInt()}%' : ''}");
        }
      },
    );

    await lm.initializeModel(); // uses the downloaded model

    final result = await lm.generateCompletion(
      messages: [ChatMessage(content: "Hello!", role: "user")],
    );

    if (result.success) {
      print(result.response);
      print("${result.tokensPerSecond} tok/s  "
            "TTFT: ${result.timeToFirstTokenMs}ms  "
            "Total: ${result.totalTimeMs}ms");
    }
  } finally {
    lm.unload(); // ALWAYS call — frees native memory
  }
}
```

### downloadModel

```dart
Future<void> downloadModel({
  String model = "qwen3-0.6",
  CactusProgressCallback? downloadProcessCallback,
})

// CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError)
// progress: 0.0–1.0 or null if unknown
```

### initializeModel

```dart
Future<void> initializeModel({CactusInitParams? params})

// CactusInitParams:
//   model:       String? — override slug (defaults to last downloaded)
//   contextSize: int?   — token context window (default: 2048)

await lm.initializeModel(
  params: CactusInitParams(model: "qwen3-0.6", contextSize: 1024),
);
```

### generateCompletion

```dart
Future<CactusCompletionResult> generateCompletion({
  required List<ChatMessage> messages,
  CactusCompletionParams? params,   // uses defaults if null
})
```

### generateCompletionStream

```dart
Future<CactusStreamedCompletionResult> generateCompletionStream({
  required List<ChatMessage> messages,
  CactusCompletionParams? params,
})

// Usage:
final streamed = await lm.generateCompletionStream(
  messages: [ChatMessage(content: "Tell me a story", role: "user")],
);

await for (final token in streamed.stream) {
  print(token);                         // each token as it arrives
}

final final_ = await streamed.result;   // CactusCompletionResult
print(final_.response);
```

### generateEmbedding

```dart
Future<CactusEmbeddingResult> generateEmbedding({
  required String text,
  String? modelName,
})

final emb = await lm.generateEmbedding(text: "some text");
// emb.success     : bool
// emb.dimension   : int (e.g. 1024)
// emb.embeddings  : List<double>
```

### getModels

```dart
Future<List<CactusModel>> getModels()   // results cached locally

final models = await lm.getModels();
final visionModels = models.where((m) => m.supportsVision).toList();
```

### Lifecycle

```dart
bool isLoaded()     // true if model is in memory
void reset()        // clear KV cache, keep model loaded (use between conversations)
void unload()       // free native model memory — call in finally blocks
```

---

### CactusCompletionParams

```dart
CactusCompletionParams({
  String?           model,
  double?           temperature,      // randomness: 0.0–2.0
  int?              topK,
  double?           topP,
  int               maxTokens    = 200,
  List<String>      stopSequences = const ["<|im_end|>", "<end_of_turn>"],
  List<CactusTool>? tools,
  bool?             forceTools,       // force tool call
  CompletionMode    completionMode = CompletionMode.local,
  String?           cactusToken,      // required for hybrid/remote modes
})
```

### CompletionMode enum

```dart
CompletionMode.local        // strict on-device (default)
CompletionMode.hybrid       // on-device first, falls back to cloud
```

---

### Streaming Chat App Pattern

```dart
class ChatState extends ChangeNotifier {
  final _lm = CactusLM();
  final messages = <ChatMessage>[];
  String streamingResponse = '';
  bool isStreaming = false;

  Future<void> init() async {
    await _lm.downloadModel(model: "qwen3-0.6");
    await _lm.initializeModel();
    notifyListeners();
  }

  Future<void> send(String text) async {
    messages.add(ChatMessage(content: text, role: "user"));
    isStreaming = true;
    streamingResponse = '';
    notifyListeners();

    final streamed = await _lm.generateCompletionStream(
      messages: List.of(messages),
    );

    await for (final token in streamed.stream) {
      streamingResponse += token;
      notifyListeners();
    }

    final result = await streamed.result;
    messages.add(ChatMessage(content: result.response, role: "assistant"));
    isStreaming = false;
    streamingResponse = '';
    notifyListeners();
  }

  void dispose() {
    _lm.unload();
    super.dispose();
  }
}
```

---

### Function Calling

```dart
final tools = [
  CactusTool(
    name: "get_weather",
    description: "Get current weather for a location",
    parameters: ToolParametersSchema(
      properties: {
        'location': ToolParameter(
          type: 'string',
          description: 'City name',
          required: true,
        ),
        'units': ToolParameter(
          type: 'string',
          description: 'celsius or fahrenheit',
          required: false,
        ),
      },
    ),
  ),
];

final result = await lm.generateCompletion(
  messages: [ChatMessage(content: "Weather in Chennai?", role: "user")],
  params: CactusCompletionParams(tools: tools),
);

for (final call in result.toolCalls) {
  // call.name       : String
  // call.arguments  : Map<String, String>
  print("${call.name}(${call.arguments})");
}
```

### Tool Filtering

```dart
import 'package:cactus/services/tool_filter.dart';

// Default (keyword, max 3 tools)
final lm = CactusLM(
  enableToolFiltering: true,
  toolFilterConfig: ToolFilterConfig.simple(maxTools: 3),
);

// Semantic (embedding-based, more accurate)
final lm = CactusLM(
  enableToolFiltering: true,
  toolFilterConfig: ToolFilterConfig(
    strategy:             ToolFilterStrategy.semantic,
    maxTools:             5,
    similarityThreshold:  0.4,
  ),
);

// Disable entirely
final lm = CactusLM(enableToolFiltering: false);
```

Debug output when filtering is active:
```
Tool filtering: 8 -> 2 tools
Filtered tools: get_weather, get_location
```

---

### Hybrid / Cloud Fallback

```dart
// No model download needed for pure-cloud mode
final result = await lm.generateCompletion(
  messages: [ChatMessage(content: "Hello", role: "user")],
  params: CactusCompletionParams(
    completionMode: CompletionMode.hybrid,
    cactusToken:    "YOUR_CACTUS_TOKEN",
    maxTokens:      300,
  ),
);
```

---

### Vision (Multimodal)

```dart
// Use a vision model (e.g. lfm2-vl-450m, lfm2.5-vl-1.6b)
await lm.initializeModel(params: CactusInitParams(model: 'lfm2-vl-450m'));

final streamed = await lm.generateCompletionStream(
  messages: [
    ChatMessage(content: 'You are a helpful assistant.', role: "system"),
    ChatMessage(
      content: 'What objects can you see in this image?',
      role:    "user",
      images:  ['/absolute/path/to/image.jpg'],  // List<String> file paths
    ),
  ],
  params: CactusCompletionParams(maxTokens: 300),
);

await for (final token in streamed.stream) { print(token); }
lm.unload();
```

---

## CactusSTT

Speech-to-text using Whisper / Parakeet models.

### Basic File Transcription

```dart
import 'package:cactus/cactus.dart';

Future<void> sttExample() async {
  final stt = CactusSTT();
  try {
    await stt.downloadModel(model: "whisper-tiny");
    await stt.initializeModel(params: CactusInitParams(model: "whisper-tiny"));

    final result = await stt.transcribe(
      audioFilePath: "/path/to/audio.wav",
    );

    if (result.success) {
      print(result.text);
      print("${result.tokensPerSecond} tok/s  total: ${result.totalTimeMs}ms");
    }
  } finally {
    stt.unload();
  }
}
```

### Streaming Transcription

```dart
final streamed = await stt.transcribeStream(
  audioFilePath: "/path/to/audio.wav",
);

await for (final token in streamed.stream) { print(token); }

final final_ = await streamed.result;
print(final_.text);
```

### Microphone Stream

```dart
// audioStream: Stream<Uint8List> — 16-bit PCM, 16kHz, mono, ≥32000 bytes
final result = await stt.transcribe(
  audioStream: microphoneStream,
  onChunk: (chunkResult) {
    print(chunkResult.text);   // partial result per chunk
  },
);
```

### Custom Parameters

```dart
final params = CactusTranscriptionParams(
  maxTokens: 4096,
  stopSequences: ["<|startoftranscript|>"],
);

final result = await stt.transcribe(
  audioFilePath: "/path/to/audio.wav",
  params: params,
  prompt: "<|startoftranscript|><|ta|><|transcribe|><|notimestamps|>",  // Tamil
);
```

### CactusSTT API Reference

```dart
CactusSTT()

Future<void> downloadModel({
  required String model,
  CactusProgressCallback? downloadProcessCallback,
})

Future<void> initializeModel({CactusInitParams? params})

// Provide EITHER audioFilePath OR audioStream (not both)
Future<CactusTranscriptionResult> transcribe({
  String? audioFilePath,
  Stream<Uint8List>? audioStream,
  Function(CactusTranscriptionResult)? onChunk,  // only with audioStream
  String prompt = whisperPrompt,
  CactusTranscriptionParams? params,
})

Future<CactusStreamedTranscriptionResult> transcribeStream({
  String? audioFilePath,
  Stream<Uint8List>? audioStream,
  String prompt = whisperPrompt,
  CactusTranscriptionParams? params,
})

Future<List<VoiceModel>> getVoiceModels()

bool isLoaded()
void reset()    // clear context, keep model in memory
void unload()
```

---

## CactusRAG

On-device vector database using ObjectBox + HNSW search.
**Distance metric:** squared Euclidean — **lower = more similar**.

### Full Example

```dart
import 'package:cactus/cactus.dart';

Future<void> ragExample() async {
  final lm  = CactusLM();
  final rag = CactusRAG();
  try {
    await lm.downloadModel(model: "qwen3-0.6");
    await lm.initializeModel();
    await rag.initialize();

    // Connect embeddings from LM to RAG
    rag.setEmbeddingGenerator((text) async {
      final r = await lm.generateEmbedding(text: text);
      return r.embeddings;   // List<double>
    });

    // Tune chunking (optional — defaults: 512 / 64)
    rag.setChunking(chunkSize: 1024, chunkOverlap: 128);

    // Store document (auto-chunks + embeds)
    final doc = await rag.storeDocument(
      fileName: "guide.txt",
      filePath: "/path/to/guide.txt",
      content:  "Cactus is a low-latency AI engine...",
      fileSize: null,
      fileHash: "sha256hex",   // optional, for versioning
    );
    print("Chunks: ${doc.chunks.length}");

    // Semantic search
    final results = await rag.search(
      text:  "How fast is Cactus on mobile?",
      limit: 5,
    );
    for (final r in results) {
      print("dist=${r.distance.toStringAsFixed(3)}  "
            "${r.chunk.content.substring(0, 80)}");
    }
  } finally {
    lm.unload();
    await rag.close();
  }
}
```

### CactusRAG API Reference

```dart
Future<void> initialize()
Future<void> close()

void setEmbeddingGenerator(EmbeddingGenerator generator)
// EmbeddingGenerator = Future<List<double>> Function(String text)

void setChunking({required int chunkSize, required int chunkOverlap})
int get chunkSize
int get chunkOverlap

// Manual chunk (useful for testing)
List<String> chunkContent(String content, {int? chunkSize, int? chunkOverlap})

Future<Document> storeDocument({
  required String fileName,
  required String filePath,
  required String content,
  int?    fileSize,
  String? fileHash,
})

Future<Document?>       getDocumentByFileName(String fileName)
Future<List<Document>>  getAllDocuments()
Future<void>            updateDocument(Document document)
Future<void>            deleteDocument(int id)

// limit: max chunks returned (default: 10)
Future<List<ChunkSearchResult>> search({String? text, int limit = 10})

Future<DatabaseStats> getStats()
```

---

## Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<!-- For CactusSTT microphone input -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used for speech-to-text transcription.</string>
```

### macOS — `macos/Runner/DebugProfile.entitlements` & `Release.entitlements`

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.device.microphone</key>
<true/>
```

---

## Data Classes

### ChatMessage

```dart
ChatMessage({
  required String content,
  required String role,          // "user" | "assistant" | "system"
  int?            timestamp,
  List<String>    images = const [],  // absolute paths (vision models only)
})
```

### CactusInitParams

```dart
CactusInitParams({
  String? model,          // model slug override
  int?    contextSize,    // default: 2048
})
```

### CactusCompletionResult

```dart
CactusCompletionResult({
  required bool   success,
  required String response,
  required double timeToFirstTokenMs,
  required double totalTimeMs,
  required double tokensPerSecond,
  required int    prefillTokens,
  required int    decodeTokens,
  required int    totalTokens,
  List<ToolCall>  toolCalls = const [],
})
```

### CactusStreamedCompletionResult

```dart
CactusStreamedCompletionResult({
  required Stream<String>                  stream,  // token-by-token
  required Future<CactusCompletionResult>  result,  // final result
})
```

### CactusEmbeddingResult

```dart
CactusEmbeddingResult({
  required bool          success,
  required List<double>  embeddings,
  required int           dimension,
  String?                errorMessage,
})
```

### CactusModel

```dart
CactusModel({
  required DateTime createdAt,
  required String   slug,
  required String   downloadUrl,
  required int      sizeMb,
  required bool     supportsToolCalling,
  required bool     supportsVision,
  required String   name,
  bool              isDownloaded = false,
  int               quantization = 8,
})
```

### CactusTool / ToolParametersSchema / ToolParameter / ToolCall

```dart
CactusTool({
  required String               name,
  required String               description,
  required ToolParametersSchema parameters,
})

ToolParametersSchema({
  String                              type = 'object',
  required Map<String, ToolParameter> properties,
  // required fields auto-extracted from ToolParameter.required = true
})

ToolParameter({
  required String type,          // 'string' | 'number' | 'boolean' | 'array' | 'object'
  required String description,
  bool            required = false,
})

ToolCall({
  required String              name,
  required Map<String, String> arguments,
})
```

### ToolFilterConfig

```dart
ToolFilterConfig({
  ToolFilterStrategy strategy             = ToolFilterStrategy.simple,
  int?               maxTools,
  double             similarityThreshold  = 0.3,
})

// Factory
ToolFilterConfig.simple({int maxTools = 3})

// ToolFilterStrategy enum
ToolFilterStrategy.simple    // fast keyword matching
ToolFilterStrategy.semantic  // embedding-based (more accurate, slower)
```

### STT Data Classes

```dart
CactusTranscriptionParams({
  int          maxTokens     = 2048,
  List<String> stopSequences = const ["<|startoftranscript|>"],
})

CactusTranscriptionResult({
  required bool   success,
  required String text,
  double          timeToFirstTokenMs = 0.0,
  double          totalTimeMs        = 0.0,
  double          tokensPerSecond    = 0.0,
  String?         errorMessage,
})

CactusStreamedTranscriptionResult({
  required Stream<String>                     stream,
  required Future<CactusTranscriptionResult>  result,
})

VoiceModel({
  required DateTime createdAt,
  required String   slug,
  required String   downloadUrl,
  required int      sizeMb,
  required String   fileName,
  bool              isDownloaded = false,
})
```

### RAG Data Classes

```dart
Document({
  int       id = 0,
  required String  fileName,
  required String  filePath,
  DateTime? createdAt,
  DateTime? updatedAt,
  int?      fileSize,
  String?   fileHash,
  // .content getter → all chunk text joined
})

DocumentChunk({
  int             id = 0,
  required String        content,
  required List<double>  embeddings,    // 1024-dim by default
})

ChunkSearchResult({
  required DocumentChunk chunk,
  required double        distance,      // squared Euclidean, lower = closer
})

DatabaseStats({
  required int totalDocuments,
  required int documentsWithEmbeddings,
  required int totalContentLength,
})

// Callback types
CactusProgressCallback = void Function(double? progress, String statusMessage, bool isError)
EmbeddingGenerator     = Future<List<double>> Function(String text)
```

---

## Performance Tips

1. Use `qwen3-0.6` or `gemma3-270m` for most mobile tasks (speed vs quality)
2. `contextSize: 1024` reduces RAM vs default 2048
3. Always call `unload()` in `finally` blocks
4. Call `reset()` between conversations to clear KV cache without re-loading
5. Use `Isolate.run(...)` for blocking init if you need to keep UI responsive
6. `getModels()` caches results — safe to call frequently
7. Pro key + NPU = massive throughput gain on Apple chips
