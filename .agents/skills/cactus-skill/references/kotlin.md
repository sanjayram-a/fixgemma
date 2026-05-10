# Cactus Kotlin Multiplatform SDK Reference

Library: `com.cactuscompute:cactus` | Maven Central | v1.4.1-beta+
Platforms: Android API 24+, iOS 12.0+ (via KMP)
Repo: github.com/cactus-compute/cactus-kotlin

---

## Table of Contents

1. [Setup](#setup)
2. [CactusLM — Language Model](#cactuslm)
3. [CactusSTT — Speech-to-Text](#cactusstt)
4. [CactusModelManager — File Management](#cactusmodelmanager)
5. [Tool Filtering](#tool-filtering)
6. [Vision](#vision)
7. [Inference Modes](#inference-modes)
8. [Data Class Reference](#data-class-reference)

---

## Setup

### build.gradle.kts (KMP)

```kotlin
kotlin {
    sourceSets {
        commonMain {
            dependencies {
                implementation("com.cactuscompute:cactus:1.4.1-beta")
            }
        }
    }
}
```

### settings.gradle.kts

```kotlin
dependencyResolutionManagement {
    repositories { mavenCentral() }
}
```

### AndroidManifest.xml

```xml
<!-- Model downloads -->
<uses-permission android:name="android.permission.INTERNET" />
<!-- STT microphone input -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

### Android Activity (REQUIRED — must be first in onCreate)

```kotlin
import com.cactus.CactusContextInitializer

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CactusContextInitializer.initialize(this)  // ← MUST be called first
        setContent { MyApp() }
    }
}
```

### Optional Global Config

```kotlin
import com.cactus.services.CactusTelemetry
import com.cactus.CactusConfig

// Telemetry (enabled by default, opt-out)
CactusTelemetry.isTelemetryEnabled = false
CactusTelemetry.setTelemetryToken("your_org_token")

// NPU acceleration (founders@cactuscompute.com for key)
CactusConfig.setProKey("your_pro_key")
```

---

## CactusLM

### Constructor

```kotlin
CactusLM(
    enableToolFiltering: Boolean = true,
    toolFilterConfig: ToolFilterConfig? = null   // defaults to ToolFilterConfig.simple()
)
```

### Minimal Example

```kotlin
import com.cactus.CactusLM
import com.cactus.CactusInitParams
import com.cactus.ChatMessage
import com.cactus.CactusCompletionParams
import kotlinx.coroutines.runBlocking

runBlocking {
    val lm = CactusLM()
    try {
        lm.downloadModel("qwen3-0.6")             // throws on failure
        lm.initializeModel(CactusInitParams(model = "qwen3-0.6", contextSize = 2048))

        val result = lm.generateCompletion(
            messages = listOf(ChatMessage(content = "Hello!", role = "user"))
        )

        result?.let {
            if (it.success) {
                println("Response: ${it.response}")
                println("${it.tokensPerSecond} tok/s  "
                      + "TTFT: ${it.timeToFirstTokenMs}ms  "
                      + "Total: ${it.totalTimeMs}ms")
            }
        }
    } finally {
        lm.unload()   // ALWAYS free memory
    }
}
```

### downloadModel

```kotlin
// Throws exception on network/IO failure — wrap in try/catch
suspend fun downloadModel(model: String = "qwen3-0.6")

// With progress (implement DownloadProgressCallback)
suspend fun downloadModel(
    model: String,
    progressCallback: DownloadProgressCallback? = null
)
// DownloadProgressCallback: interface { fun onProgress(progress: Double?, status: String, isError: Boolean) }
```

### initializeModel

```kotlin
suspend fun initializeModel(params: CactusInitParams)

// CactusInitParams:
//   model:       String?  — slug override (defaults to last downloaded)
//   contextSize: Int?     — token context window (default: 2048)
```

### generateCompletion

```kotlin
// onToken: optional streaming callback (called per token on background thread)
suspend fun generateCompletion(
    messages: List<ChatMessage>,
    params: CactusCompletionParams = CactusCompletionParams(),
    onToken: CactusStreamingCallback? = null
): CactusCompletionResult?

// CactusStreamingCallback = (token: String, tokenId: Int) -> Unit

// Streaming example:
val result = lm.generateCompletion(
    messages = listOf(ChatMessage("Tell me a story", "user")),
    onToken  = { token, _ ->
        print(token)   // write each token as it arrives
    }
)
```

### generateEmbedding

```kotlin
suspend fun generateEmbedding(
    text: String,
    modelName: String? = null
): CactusEmbeddingResult?

val emb = lm.generateEmbedding("Some text to embed")
emb?.let {
    println("Dims: ${it.dimension}  Success: ${it.success}")
    println("First 5: ${it.embeddings.take(5)}")
}
```

### getModels

```kotlin
suspend fun getModels(): List<CactusModel>

val models = lm.getModels()
models.filter { it.supports_vision }.forEach { m ->
    println("${m.slug}  ${m.size_mb}MB  downloaded=${m.isDownloaded}")
}
```

### Lifecycle

```kotlin
fun isLoaded(): Boolean
fun reset()     // clear KV cache, keep model loaded (use between conversations)
fun unload()    // free native memory
```

---

### CactusCompletionParams

```kotlin
data class CactusCompletionParams(
    val model:          String?       = null,
    val temperature:    Double?       = null,      // 0.0–2.0
    val topK:           Int?          = null,
    val topP:           Double?       = null,
    val maxTokens:      Int           = 200,
    val stopSequences:  List<String>  = listOf("<|im_end|>", "<end_of_turn>"),
    val tools:          List<CactusTool> = emptyList(),
    val forceTools:     Boolean?      = null,      // force a tool call
    val mode:           InferenceMode = InferenceMode.LOCAL,
    val cactusToken:    String?       = null       // required for REMOTE / LOCAL_FIRST / REMOTE_FIRST
)
```

---

### Function Calling

```kotlin
import com.cactus.models.CactusTool
import com.cactus.models.ToolParameter
import com.cactus.models.createTool

val tools = listOf(
    createTool(
        name        = "get_weather",
        description = "Get current weather for a location",
        parameters  = mapOf(
            "location" to ToolParameter(
                type        = "string",
                description = "City name",
                required    = true
            ),
            "units" to ToolParameter(
                type        = "string",
                description = "celsius or fahrenheit",
                required    = false
            )
        )
    )
)

val result = lm.generateCompletion(
    messages = listOf(ChatMessage("Weather in Chennai?", "user")),
    params   = CactusCompletionParams(tools = tools)
)

result?.toolCalls?.forEach { call ->
    println("Tool: ${call.name}  Args: ${call.arguments}")
    // call.name       : String
    // call.arguments  : Map<String, String>
}
```

### Agent Loop Pattern (Kotlin)

```kotlin
val messages = mutableListOf(
    ChatMessage("You are a weather assistant.", "system"),
    ChatMessage("What is the weather in Tokyo?", "user")
)

while (true) {
    val result = lm.generateCompletion(
        messages = messages,
        params   = CactusCompletionParams(tools = tools)
    ) ?: break

    if (result.toolCalls.isNullOrEmpty()) {
        println("Final: ${result.response}")
        break
    }

    messages.add(ChatMessage(result.response ?: "", "assistant"))

    for (call in result.toolCalls!!) {
        val toolResult = executeToolCall(call.name, call.arguments)
        messages.add(ChatMessage(
            content = "{\"tool\": \"${call.name}\", \"result\": \"$toolResult\"}",
            role    = "tool"
        ))
    }
}
```

---

## CactusSTT

```kotlin
import com.cactus.CactusSTT
import com.cactus.CactusTranscriptionParams
import com.cactus.TranscriptionMode

val stt = CactusSTT()
try {
    stt.downloadModel("whisper-tiny")
    stt.initializeModel(CactusInitParams(model = "whisper-tiny"))

    // From file
    val result = stt.transcribe(
        filePath = "/path/to/audio.wav",
        params   = CactusTranscriptionParams()
    )
    result?.let { if (it.success) println(it.text) }

    // Streaming
    val streamed = stt.transcribe(
        filePath = "/path/to/audio.wav",
        onToken  = { token, _ -> print(token) }
    )

    // From PCM buffer (microphone — 16-bit PCM, 16kHz, mono, ≥32000 bytes)
    val pcmResult = stt.transcribe(
        audioBuffer = pcmByteArray,
        params      = CactusTranscriptionParams()
    )
} finally {
    stt.unload()
}
```

### Cloud / Hybrid Transcription (Wispr)

```kotlin
val result = stt.transcribe(
    filePath = "/path/to/audio.wav",
    mode     = TranscriptionMode.LOCAL_FIRST,
    apiKey   = "your_wispr_api_key"
)
// Pre-warm the remote endpoint for lower latency:
stt.warmUpWispr("your_wispr_api_key")
```

### TranscriptionMode enum

```kotlin
TranscriptionMode.LOCAL          // on-device only (default)
TranscriptionMode.REMOTE         // cloud via Wispr (needs apiKey)
TranscriptionMode.LOCAL_FIRST    // device first, falls back to cloud
TranscriptionMode.REMOTE_FIRST   // cloud first, falls back to device
```

### CactusSTT API Reference

```kotlin
suspend fun downloadModel(model: String = "whisper-tiny")
suspend fun initializeModel(params: CactusInitParams)

suspend fun transcribe(
    filePath:     String?               = null,
    audioBuffer:  ByteArray?            = null,   // 16-bit PCM 16kHz mono ≥32000 bytes
    prompt:       String                = WHISPER_DEFAULT_PROMPT,
    params:       CactusTranscriptionParams = CactusTranscriptionParams(),
    onToken:      CactusStreamingCallback? = null,
    mode:         TranscriptionMode     = TranscriptionMode.LOCAL,
    apiKey:       String?               = null
): CactusTranscriptionResult?

suspend fun warmUpWispr(apiKey: String)          // pre-warm remote endpoint
suspend fun getVoiceModels(): List<VoiceModel>
suspend fun isModelDownloaded(modelName: String = "whisper-tiny"): Boolean

fun isReady(): Boolean
fun reset()
fun unload()
```

---

## CactusModelManager

Singleton — manages downloaded models without an active LM/STT instance.
Operates directly on the filesystem; no model needs to be loaded.

```kotlin
import com.cactus.CactusModelManager

// List all downloaded model slugs
val downloaded: List<String> = CactusModelManager.getDownloadedModels()
println("Downloaded: $downloaded")   // ["qwen3-0.6", "whisper-tiny"]

// Check a specific model
val exists: Boolean = CactusModelManager.isModelDownloaded("qwen3-0.6")

// Delete a model to free storage
val deleted: Boolean = CactusModelManager.deleteModel("old-slug")
if (deleted) println("Deleted.") else println("Model not found.")

// Get storage directory path (useful for debugging)
val path: String = CactusModelManager.getModelsDirectory()
// Android: /data/data/your.app.package/files/models
// iOS:     /var/mobile/Containers/Data/Application/.../Documents/models
```

### API

```kotlin
object CactusModelManager {
    fun getDownloadedModels(): List<String>
    fun isModelDownloaded(modelSlug: String): Boolean
    fun deleteModel(modelSlug: String): Boolean          // true = deleted, false = not found
    fun getModelsDirectory(): String
}
```

---

## Tool Filtering

```kotlin
import com.cactus.services.ToolFilterConfig
import com.cactus.services.ToolFilterStrategy

// Default: keyword-based, max 3 tools
val lm = CactusLM(
    enableToolFiltering = true,
    toolFilterConfig    = ToolFilterConfig.simple(maxTools = 3)
)

// Semantic: embedding-based (more accurate, slightly slower)
val lm = CactusLM(
    enableToolFiltering = true,
    toolFilterConfig    = ToolFilterConfig(
        strategy            = ToolFilterStrategy.SEMANTIC,
        maxTools            = 5,
        similarityThreshold = 0.4
    )
)

// Disable entirely
val lm = CactusLM(enableToolFiltering = false)
```

Filtering happens automatically before every `generateCompletion` call that
includes tools. The filtered subset is used; your original list is unchanged.

---

## Vision

```kotlin
// Get a vision-capable model
val models      = lm.getModels()
val visionModel = models.first { it.supports_vision }

lm.downloadModel(visionModel.slug)
lm.initializeModel(CactusInitParams(model = visionModel.slug))

val result = lm.generateCompletion(
    messages = listOf(
        ChatMessage("You are a helpful assistant.", "system"),
        ChatMessage(
            content = "Describe this image in detail.",
            role    = "user",
            images  = listOf("/absolute/path/to/image.jpg")  // List<String>
        )
    ),
    params  = CactusCompletionParams(maxTokens = 400),
    onToken = { token, _ -> print(token) }
)
println("\n${result?.response}")
```

---

## Inference Modes

```kotlin
// InferenceMode enum
InferenceMode.LOCAL          // on-device only — default
InferenceMode.REMOTE         // cloud only — needs cactusToken
InferenceMode.LOCAL_FIRST    // device first, falls back to cloud
InferenceMode.REMOTE_FIRST   // cloud first, falls back to device

// Usage:
val result = lm.generateCompletion(
    messages = listOf(ChatMessage("Hello!", "user")),
    params   = CactusCompletionParams(
        mode        = InferenceMode.LOCAL_FIRST,
        cactusToken = "your_api_token"
    )
)
```

---

## Data Class Reference

```kotlin
// ── Shared ─────────────────────────────────────────────────────
data class CactusInitParams(
    val model:       String? = null,
    val contextSize: Int?    = null      // default: 2048
)

data class ChatMessage(
    val content:   String,
    val role:      String,               // "user" | "assistant" | "system" | "tool"
    val timestamp: Long?          = null,
    val images:    List<String>   = emptyList()   // absolute file paths
)

// ── LLM ─────────────────────────────────────────────────────────
data class CactusCompletionResult(
    val success:            Boolean,
    val response:           String?      = null,
    val timeToFirstTokenMs: Double?      = null,
    val totalTimeMs:        Double?      = null,
    val tokensPerSecond:    Double?      = null,
    val prefillTokens:      Int?         = null,
    val decodeTokens:       Int?         = null,
    val totalTokens:        Int?         = null,
    val toolCalls:          List<ToolCall>? = emptyList()
)

data class CactusEmbeddingResult(
    val success:      Boolean,
    val embeddings:   List<Double> = emptyList(),
    val dimension:    Int?         = null,
    val errorMessage: String?      = null
)

data class CactusModel(
    val created_at:            String,
    val slug:                  String,
    val download_url:          String,
    val size_mb:               Int,
    val supports_tool_calling: Boolean,
    val supports_vision:       Boolean,
    val name:                  String,
    val isDownloaded:          Boolean = false,
    val quantization:          Int     = 8
)

// ── Tools ────────────────────────────────────────────────────────
data class ToolCall(
    val name:      String,
    val arguments: Map<String, String>
)

data class CactusTool(
    val type:     String = "function",
    val function: CactusFunction
)

data class CactusFunction(
    val name:        String,
    val description: String,
    val parameters:  ToolParametersSchema
)

data class ToolParametersSchema(
    val type:       String = "object",
    val properties: Map<String, ToolParameter>,
    val required:   List<String>             // auto-derived from ToolParameter.required
)

data class ToolParameter(
    val type:        String,                 // "string" | "number" | "boolean" | "array" | "object"
    val description: String,
    val required:    Boolean = false
)

// Helper function
fun createTool(
    name:        String,
    description: String,
    parameters:  Map<String, ToolParameter>
): CactusTool

// ── STT ──────────────────────────────────────────────────────────
data class CactusTranscriptionParams(
    val model:         String?       = null,
    val maxTokens:     Int           = 512,
    val stopSequences: List<String>  = listOf("<|im_end|>", "<end_of_turn>")
)

data class CactusTranscriptionResult(
    val success:    Boolean,
    val text:       String? = null,
    val totalTimeMs: Double? = null
)

data class VoiceModel(
    val created_at:   String,
    val slug:         String,
    val download_url: String,
    val size_mb:      Int,
    val quantization: Int,
    val isDownloaded: Boolean = false
)

// ── Callbacks ─────────────────────────────────────────────────────
// CactusStreamingCallback = (token: String, tokenId: Int) -> Unit
```
