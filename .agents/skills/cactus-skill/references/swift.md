# Cactus Swift SDK Reference

Package: `swift-cactus` | github.com/mhayes853/swift-cactus | v2.2.1+
Supported Engine Version: 1.11
Platforms: iOS, macOS, tvOS, watchOS, visionOS, Android (via Swift Android SDK), Linux (ARM)

---

## Table of Contents

1. [Installation](#installation)
2. [Configuration](#configuration)
3. [CactusAgentSession — LLM & Chat](#cactusagentsession)
4. [Function Calling](#function-calling)
5. [Vision](#vision)
6. [CactusSTTSession — Speech-to-Text](#cactusstt)
7. [CactusVADSession — Voice Activity Detection](#cactusvad)
8. [Live Transcription](#live-transcription)
9. [Language Detection](#language-detection)
10. [Streaming](#streaming)
11. [Embeddings & Vector Index](#embeddings)
12. [Model Storage (CactusModelsDirectory)](#model-storage)
13. [NPU Acceleration](#npu-acceleration)
14. [Hybrid Inference](#hybrid-inference)
15. [Low-Level API (CactusModel / CactusModelActor)](#low-level-api)
16. [Logging & Telemetry](#logging-and-telemetry)
17. [SwiftUI Integration](#swiftui)
18. [JSON Schema Macro](#json-schema)

---

## Installation

### Xcode — Swift Package Manager

Add package URL in Xcode → File → Add Package Dependencies:
```
https://github.com/mhayes853/swift-cactus
```

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/mhayes853/swift-cactus", from: "2.0.0")
]
// Add to target:
.product(name: "Cactus", package: "swift-cactus")
```

### Package Products

| Product | Contents |
|---|---|
| `Cactus` | Main library + macros + `CactusCore` |
| `CactusCore` | Core without macros |
| `CXXCactusShims` | Direct C FFI export |

---

## Configuration

```swift
import Cactus

// Hybrid cloud inference (optional — for cloud fallback)
Cactus.cactusCloudAPIKey = "your-api-key"
// ⚠️ Never hardcode in publicly distributed apps

// Check supported engine version
print(Cactus.cactusEngineVersion)  // e.g. "1.11"
```

### Android Setup (Swift on Android)

```swift
import Cactus
import Android

// In your android_main entry point
Cactus.androidFilesDirectory = URL(
    fileURLWithPath: app.pointee.activity.pointee.internalDataPath
)
```

Or via JNI if using Swift through Java interop:

```swift
// Swift side (exposed via JNI module)
public func setAndroidFilesDirectory(_ path: String) {
    Cactus.androidFilesDirectory = URL(fileURLWithPath: path)
}
```

```kotlin
// Kotlin side (in Activity.onCreate)
MySwiftModule.setAndroidFilesDirectory(applicationContext.filesDir.absolutePath)
```

---

## CactusAgentSession

High-level session for multi-turn LLM conversations with optional function calling.
Conforms to `Observable` — usable directly in SwiftUI.

### Basic Completion

```swift
import Cactus

// Step 1: download model
let modelURL = try await CactusModelsDirectory.shared.modelURL(for: "qwen3-0.6")

// Step 2: create session with system prompt
let session = try CactusAgentSession(from: modelURL) {
    "You are a helpful assistant."
}

// Step 3: send a message
let message = CactusUserMessage {
    "What is on-device AI?"
}
let completion = try await session.respond(to: message)
print(completion.output)
```

### Multi-Turn Conversation

```swift
// CactusAgentSession automatically maintains transcript history
let session = try CactusAgentSession(from: modelURL) {
    "You are a knowledgeable assistant."
}

let reply1 = try await session.respond(to: CactusUserMessage { "Hello!" })
let reply2 = try await session.respond(to: CactusUserMessage { "Tell me more." })

// Access full transcript
for entry in session.transcript {
    print("\(entry.message.role): \(entry.message.content)")
}
```

### CactusAgentSession Init Signature

```swift
init(
    from modelURL: URL,
    functions: [any CactusFunction] = [],  // for tool calling
    @CactusSystemPromptBuilder systemPrompt: () -> String
) throws
```

---

## Function Calling

Implement `CactusFunction` protocol. Use `@JSONSchema` macro to auto-synthesise
the parameter schema from a `Codable` struct.

```swift
import Cactus

struct GetWeather: CactusFunction {
    @JSONSchema
    struct Input: Codable, Sendable {
        @JSONSchemaProperty(description: "The city to get weather for.")
        let city: String
    }

    let name        = "get_weather"
    let description = "Get the current weather for a city."

    func invoke(input: Input) async throws -> sending String {
        // Call your real API here
        let condition = try await fetchWeather(for: input.city)
        return "The weather in \(input.city) is: \(condition)"
    }
}

// Attach to session
let session = try CactusAgentSession(
    from: modelURL,
    functions: [GetWeather()]
) {
    "You are a weather assistant."
}

let completion = try await session.respond(to: CactusUserMessage {
    "What's the weather in San Francisco?"
})
print(completion.output)
```

**Notes:**
- `Input` must conform to `Decodable` and `Sendable`
- Multiple tool calls in one prompt are executed **in parallel** by default
- Tool results are passed back to the model in invocation order

---

## Vision

Pass images via `CactusPromptContent` inside a `CactusUserMessage`.

```swift
// Use a vision-capable model
let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .lfm2Vl_450m())

let session = try CactusAgentSession(from: modelURL) {
    "You describe images concisely."
}

let imageURL = Bundle.main.url(forResource: "photo", withExtension: "jpg")!

let message = CactusUserMessage {
    "Describe this image in one sentence."
    CactusPromptContent(images: [imageURL])  // pass URL(s) to image files
}

let completion = try await session.respond(to: message)
print(completion.output)
```

---

## CactusSTTSession

Speech-to-text. Supports WAV files, raw PCM bytes, and `AVAudioPCMBuffer`.

### Basic Transcription

```swift
import Cactus

let modelURL = try await CactusModelsDirectory.shared.audioModelURL(for: .whisperSmall())
let session  = try CactusSTTSession(from: modelURL)

// From WAV file
let request = CactusTranscription.Request(
    prompt:  .default,   // see Whisper Prompts below
    content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let transcription = try await session.transcribe(request: request)
print(transcription.content)
```

### From Raw PCM Bytes

```swift
let pcmBytes: [UInt8] = [...] // 16-bit PCM, 16kHz, mono, ≥32000 bytes

let request = CactusTranscription.Request(
    prompt:  .default,
    content: .pcm(pcmBytes)
)
let transcription = try await session.transcribe(request: request)
```

### From AVAudioPCMBuffer (Apple Platforms)

```swift
import AVFoundation

let buffer: AVAudioPCMBuffer = ...
let request = CactusTranscription.Request(
    prompt:  .default,
    content: try .pcm(buffer)
)
let transcription = try await session.transcribe(request: request)
```

### Whisper Prompts

```swift
// Default (English, no timestamps)
.default

// Custom whisper-style prompt
.whipser(language: .english, includeTimestamps: true)
.whipser(language: .french,  includeTimestamps: false)

// Raw string
CactusTranscription.Prompt("<|startoftranscript|><|en|><|transcribe|><|notimestamps|>")
```

---

## CactusVADSession

Voice Activity Detection — detects speech segments in audio.

```swift
let modelURL = try await CactusModelsDirectory.shared.modelURL(for: .sileroVad())
let session  = try CactusVADSession(from: modelURL)

// WAV file
let request = CactusVAD.Request(
    content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let vad = try await session.vad(request: request)
for segment in vad.segments {
    print("Speech: \(segment.start)s → \(segment.end)s")
}

// PCM buffer
let request2 = CactusVAD.Request(content: .pcm(pcmBytes))
let vad2 = try await session.vad(request: request2)

// AVAudioPCMBuffer (Apple only)
let request3 = CactusVAD.Request(content: try .pcm(avBuffer))
```

---

## Live Transcription

Stream audio chunks to a `CactusTranscriptionStream` for real-time results.

```swift
let modelURL = try await CactusModelsDirectory.shared.audioModelURL(for: .parakeetCtc_1_1b())
let stream   = try CactusTranscriptionStream(from: modelURL)

// Collect results asynchronously
let collectTask = Task {
    for try await chunk in stream {
        print(chunk)  // partial transcription text
    }
}

// Feed audio chunks (e.g., from microphone)
try await stream.process(buffer: chunk1)
try await stream.process(buffer: chunk2)
try await stream.process(buffer: chunk3)

// Signal end of audio
try await stream.finish()
_ = try await collectTask.value
```

---

## Language Detection

Only supported on Whisper models.

```swift
let modelURL = try await CactusModelsDirectory.shared.audioModelURL(for: .whisperSmall())
let session  = try CactusSTTSession(from: modelURL)

let request = CactusLanguageDetection.Request(
    content: .audio(.documentsDirectory.appending(path: "audio.wav"))
)
let detection = try await session.detectLanguage(request: request)
print(detection.language)  // e.g. "en", "fr", "ta"
```

---

## Streaming

Both `CactusAgentSession` and `CactusSTTSession` return an `CactusInferenceStream`.

```swift
// LLM streaming
let stream = try session.stream(to: CactusUserMessage { "Tell me a story." })

for await token in stream.tokens {
    print(token.stringValue, terminator: "")
    // token.tokenId          : Int
    // token.generationStreamId : UUID
}

let completion = try await stream.collectResponse()
print(completion.output)

// STT streaming
let sttStream = try sttSession.transcriptionStream(request: request)

for await token in sttStream.tokens {
    print(token.stringValue, terminator: "")
}

let transcription = try await sttStream.collectResponse()
print(transcription.content)
```

---

## Embeddings

### Via CactusModel (sync) / CactusModelActor (async)

```swift
let model = try CactusModel(from: modelURL)   // non-Copyable, non-Sendable

var embeddings = [Float](repeating: 0, count: 2048)
var span = embeddings.mutableSpan

// Text embeddings
try model.embeddings(for: "Some text to embed", buffer: &span)

// Image embeddings
try model.imageEmbeddings(for: imageURL, buffer: &span)

// Audio embeddings
try model.audioEmbeddings(for: audioFileURL, buffer: &span)

// Convenience — returns [Float] directly
let textEmbed  = try model.embeddings(for: "text")
let imageEmbed = try model.imageEmbeddings(for: imageURL)
let audioEmbed = try model.audioEmbeddings(for: audioURL)
```

### Async via CactusModelActor

```swift
let model = try CactusModelActor(from: modelURL)  // Sendable, runs on background actor

let embed = try await model.embeddings(for: "text")
```

### CactusIndex (Vector Search)

```swift
import Cactus

let model = try CactusModel(from: modelURL)
let index = try CactusIndex(
    from: .applicationSupportDirectory.appending(path: "my-index")
)

// Add documents
let embed = try model.embeddings(for: "Some text")
let doc   = CactusIndex.Document(id: 0, embeddings: embed, content: "Some text")
try index.add(document: doc)

// Query
let queryEmbed = try model.embeddings(for: "Similar text")
let query      = CactusIndex.Query(embeddings: queryEmbed)
let results    = try index.query(query)

for result in results {
    print("ID: \(result.documentId)  Score: \(result.score)")
}
```

---

## Model Storage

`CactusModelsDirectory` manages local model downloads and storage.

```swift
// Use shared instance (default location)
let directory = CactusModelsDirectory.shared

// Custom storage location
let directory = CactusModelsDirectory(
    baseURL: .applicationSupportDirectory.appending(path: "models")
)

// Download a model (cached — skips if already present)
let modelURL = try await directory.modelURL(for: "qwen3-0.6")

// Download with progress tracking
let task = try await directory.downloadTask(for: .whisperSmall())
task.onProgress = { progress in
    print("Download: \(Int(progress * 100))%")
}
// task conforms to Observable — use in SwiftUI with @State

// Audio models
let audioURL = try await directory.audioModelURL(for: .parakeetCtc_1_1b())

// Remove models
try directory.removeModel(with: .whisperSmall())
try directory.removeModels { $0.request == .whisperSmall() }
```

### Model Slug Constants (CactusModelsDirectory)

```swift
// LLM
.qwen3_0_6()
.qwen3_1_7b()
.lfm2_350m()
.lfm2_700m()
.lfm2_2_6b()
.lfm2_5_1_2b()
.lfm2_5_1_2bThinking()
.gemma3_270m()

// VLM
.lfm2Vl_450m()
.lfm2_5Vl_1_6b()

// STT
.whisperTiny()
.whisperBase()
.whisperSmall()
.whisperMedium()
.parakeetCtc_1_1b()
.parakeetCtc_0_6b()
.parakeetTdt_0_6bV3()
.moonshineBase()

// VAD
.sileroVad()

// Embed
.nomicEmbedTextV2Moe()
.qwen3Embedding_0_6b()
```

---

## NPU Acceleration

Pro models enable NPU acceleration on Apple (ANE) platforms.

```swift
// Apple NPU — requires Pro key from founders@cactuscompute.com
let modelURL = try await CactusModelsDirectory.shared.modelURL(
    for: .lfm2Vl_450m(pro: .apple)
)
let audioURL = try await CactusModelsDirectory.shared.audioModelURL(
    for: .moonshineBase(pro: .apple)
)
```

---

## Hybrid Inference

Set the cloud API key at app launch. The engine automatically routes to cloud
when local inference cannot handle the request.

```swift
Cactus.cactusCloudAPIKey = "your-api-key"
// After this, CactusAgentSession will auto-fallback to cloud when needed
```

---

## Low-Level API

### CactusModel (sync, non-Copyable, non-Sendable)

```swift
let model = try CactusModel(from: modelURL)

// Chat completion with optional streaming
let turn = try model.complete(
    messages: [
        .system("You are a helpful assistant."),
        .user("What is the meaning of life?")
    ]
) { token, tokenId in
    print(token, terminator: "")  // streaming callback
}
print(turn.response)

// Transcription
let transcription = try model.transcribe(
    audio: wavFileURL,
    prompt: "<|startoftranscript|><|en|><|transcribe|><|notimestamps|>"
) { token, tokenId in
    print(token, terminator: "")
}
print(transcription.response)
```

### CactusModelActor (async, Sendable)

```swift
let model = try CactusModelActor(from: modelURL)

let turn = try await model.complete(
    messages: [
        .system("You are helpful."),
        .user("Hello!")
    ]
) { token, tokenId in
    print(token, terminator: "")
}
print(turn.response)
```

---

## Logging and Telemetry

```swift
import Cactus

// Logging
CactusLogging.setLevel(.debug)   // .debug | .info | .warn | .error | .none
CactusLogging.setHandler { entry in
    print("[\(entry.level)] \(entry.message)")
}
CactusLogging.removeHandler()

// Telemetry
CactusTelemetry.setup()           // enable
await CactusTelemetry.disable()   // disable
CactusTelemetry.configure("your-dashboard-token")  // org token
CactusTelemetry.send(/* custom event */)
```

---

## SwiftUI Integration

`CactusAgentSession`, `CactusInferenceStream`, and `CactusModel.DownloadTask`
all conform to `Observable` — use them directly with SwiftUI's `@State` / `@Bindable`.

```swift
import SwiftUI
import Cactus

struct ChatView: View {
    @State private var session: CactusAgentSession?
    @State private var input   = ""

    var body: some View {
        VStack {
            if let session {
                ScrollView {
                    ForEach(session.transcript) { entry in
                        HStack {
                            Text(entry.message.role == "user" ? "You" : "AI")
                                .bold()
                            Text(entry.message.content)
                        }
                    }
                }
                if session.isResponding { ProgressView() }
            }
            HStack {
                TextField("Message", text: $input)
                Button("Send") { sendMessage() }
                    .disabled(session?.isResponding == true)
            }
        }
        .task { await loadModel() }
    }

    func loadModel() async {
        let url     = try! await CactusModelsDirectory.shared.modelURL(for: "qwen3-0.6")
        session = try! CactusAgentSession(from: url) { "You are helpful." }
    }

    func sendMessage() {
        guard !input.isEmpty, let session else { return }
        let msg = input; input = ""
        Task {
            _ = try await session.respond(to: CactusUserMessage { msg })
        }
    }
}
```

---

## JSON Schema Macro

Auto-synthesise `JSONSchema` from any `Codable` struct for use with function calling.

```swift
import Cactus

@JSONSchema
struct SearchParams: Codable, Sendable {
    @JSONSchemaProperty(.string(pattern: /[A-Za-z ]+/))
    var query: String

    @JSONSchemaProperty(.integer(minimum: 1, maximum: 50))
    var maxResults: Int

    @JSONSchemaProperty(description: "Filter by language code")
    var language: String?
}

// Validate a JSON value
let value = JSONSchema.Value.object(["query": "cactus", "maxResults": 5])
try JSONSchema.Validator.shared.validate(value: value, with: SearchParams.jsonSchema)

// Decode from JSON Schema value
let params = try JSONSchema.Value.Decoder().decode(SearchParams.self, from: value)

// Encode to JSON Schema value
let encoded: JSONSchema.Value = try JSONSchema.Value.Encoder().encode(params)
```
