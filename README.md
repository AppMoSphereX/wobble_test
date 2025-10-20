# Flutter Chatbot Assistant

A Flutter-based customer support chatbot application with local LLM integration using Ollama, built with MVVM architecture and Riverpod state management.

---

## 🏗️ Architecture Diagram

```
┌─────────────────┐
│  Flutter App    │
│  (UI Layer)     │
└────────┬────────┘
         │
         ├─ Riverpod State Management
         │
┌────────▼────────┐
│   ViewModels    │
│  (MVVM Logic)   │
└────────┬────────┘
         │
┌────────▼────────┐
│  Repositories   │
│ (Data Sources)  │
└────────┬────────┘
         │
┌────────▼────────┐
│    Services     │
│  (API Clients)  │
└────────┬────────┘
         │
         ├─────────────────┐
         │                 │
┌────────▼────────┐   ┌───▼────────┐
│ Local Ollama    │   │ Shared     │
│ gemma3:4b       │   │ Preferences│
│ localhost:11434 │   │ (Storage)  │
└─────────────────┘   └────────────┘
```

**Architecture Flow:**
- **UI Layer:** Flutter widgets consume ViewModels via Riverpod providers
- **ViewModel Layer:** Business logic and state management
- **Repository Layer:** Single source of truth for data operations
- **Service Layer:** External integrations (Ollama API, local storage)
- **LLM Provider:** Local Ollama instance running gemma3:4b model

---

## 🤖 LLM Provider Selection & Prompt Template

### Provider: Ollama (gemma3:4b)

**Why Ollama + gemma3:4b?**
- ✅ **No API keys required** - runs completely locally
- ✅ **Fast responses** - 4B parameter model optimized for speed
- ✅ **Privacy-first** - all data stays on local machine
- ✅ **Easy setup** - single command installation
- ✅ **Cost-effective** - free to use, no usage limits

### Prompt Template

The app uses a context-aware prompt system for support ticket scenarios:

```dart
// Context-aware system prompt for support assistant
final systemPrompt = """
You are a helpful customer support assistant. 
You help users with their support tickets and general inquiries.
Be concise, friendly, and professional.
When discussing support tickets, ask relevant questions to understand the issue.
""";

// User message format
final userPrompt = """
$systemPrompt

User: $userMessage
Assistant:
""";
```

For streaming responses, the app uses:
```
POST http://localhost:11434/api/generate
{
  "model": "gemma3:4b",
  "prompt": "<context + user_message>",
  "stream": true
}
```

---

## 🚀 Setup Instructions

### Prerequisites
- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Ollama CLI

### 0. Install Flutter (If Not Already Installed)

📚 **For detailed installation instructions, visit the official Flutter documentation:**  
[Flutter - Get Started](https://docs.flutter.dev/get-started/install)

---

### 1. Install Ollama

**macOS/Linux:**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Windows:**
Download installer from [ollama.com](https://ollama.com/download)

### 2. Pull and Run the Model

```bash
# Pull the gemma3:4b model
ollama pull gemma3:4b

# Run Ollama server (runs on localhost:11434 by default)
ollama serve
```

**Verify Ollama is running:**
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gemma3:4b",
  "prompt": "Hello"
}'
```

### 3. Install Flutter Dependencies

```bash
cd wobble_test
flutter pub get
```

### 4. Run the Application

```bash
# Run on your preferred platform
flutter run

# Or specify platform
flutter run -d chrome      # Web
flutter run -d macos       # macOS
flutter run -d ios         # iOS
flutter run -d android     # Android
```

### Environment Variables

No environment variables required - the app connects to Ollama at `http://localhost:11434` by default.
If we wanted to connect to external APIs, we would get the API-key as an environment variable.
On a more secure approach, we would have backend-api for connecting to apis, so we didn't have to provide any API-key
to the app.

**Optional Configuration:**
You can modify the Ollama endpoint in `lib/data/services/chat_api_service.dart`:

```dart
static const String baseUrl = 'http://localhost:11434';
static const String model = 'gemma3:4b';
```

---

## ⚡ Latency Observations

### Response Time Metrics

```
Average first token response time: Around 1 to 2 seconds ( on local model )
Average full response time: Around 3 to 4 seconds
```

### Optimization Attempts

1. **Streaming Implementation**
   - Enabled streaming responses for real-time token display
   - Improves perceived latency by ~XX%
   - Implementation: `stream: true` in Ollama API calls

2. **Model Selection**
   - Chose gemma3:4b (4B parameters) over larger models
   - Trade-off: Speed vs capability

---

## ⚠️ Failure Modes & Error Handling

### 1. Network Errors

**Scenario:** Ollama server not running or unreachable

**Handling:**
```dart
try {
  final response = await _api.sendMessage(message);
  // Process response
} catch (e) {
  if (e is SocketException) {
    return Message.error(
      'Cannot connect to Ollama. Please ensure it is running.',
    );
  }
  return Message.error('Network error: ${e.toString()}');
}
```

**User Experience:**
- Display error message in chat
- Show troubleshooting tips
- Maintain conversation history

### 2. Request Timeouts

**Scenario:** LLM takes too long to respond

**Handling:**
```dart
final response = await _api.sendMessage(message)
    .timeout(Duration(seconds: 30));
```

**User Experience:**
- 30-second timeout for full responses
- User can cancel mid-response
- Partial streaming responses are preserved

### 3. User Cancellation

**Scenario:** User clicks stop button during LLM response

**Handling:**
```dart
// StreamController with cancellation support
_streamSubscription = responseStream.listen(
  (token) => _appendToken(token),
  onDone: () => _finishMessage(),
  onError: (e) => _handleError(e),
  cancelOnError: true,
);

// User cancels
void cancelResponse() {
  _streamSubscription?.cancel();
  _markMessageAsCancelled();
}
```

**User Experience:**
- Stop button appears during streaming
- Partial response is saved
- Clear indication that response was cancelled

### 4. Invalid Model Responses

**Scenario:** Ollama returns malformed or empty response

**Handling:**
```dart
if (responseData['response']?.isEmpty ?? true) {
  return Message.error(
    'Model returned empty response. Please try again.',
  );
}
```

**User Experience:**
- Friendly error message
- Option to retry
- Conversation context preserved

### 5. Rate Limiting / System Overload

**Scenario:** Too many concurrent requests to Ollama

**Handling:**
- Queue system for sequential processing
- Disable send button during active requests
- Visual loading indicators

**User Experience:**
- One message at a time
- Clear loading states
- Smooth UX even under load

---

## 🔄 Trade-offs

### What Was Cut to Meet Time Constraints

#### 1. **Backend HTTP API Layer**
- **Missing:** Dedicated backend server that brokers LLM requests
- **Current:** Direct local Ollama calls from Flutter app
- **Impact:** No provider key security, no request validation, no rate limiting
- **Why Cut:** Local development focus, 2-hour time constraint
- **Next Steps:** Add Express.js/Node.js backend with proper API endpoints

#### 2. **Input Validation & Security**
- **Missing:** Prompt length limits, input sanitization, request timeouts
- **Current:** No validation layer, basic error handling
- **Impact:** Potential security issues, no input constraints
- **Why Cut:** Local development environment, time constraints
- **Next Steps:** Add input validation, sanitization, security headers

#### 3. **Performance Optimizations**
- **Missing:** Advanced cancellation logic, request queuing, performance monitoring
- **Current:** Basic cancellation, streaming support
- **Impact:** Suboptimal performance under load, limited monitoring
- **Why Cut:** Focus on core functionality over optimization
- **Next Steps:** Add request queuing, performance metrics, advanced cancellation

### What Would Be Improved Next If we had enough time

1. **Backend API Layer** - Add Node.js server with proper endpoints
5. **Accessibility** - Dark mode and comprehensive a11y support
6. **Security** - Input validation and sanitization
7. **Performance** - Request optimization and monitoring
8. **Testing** - Unit and integration tests for all layers
9. **Documentation** - API documentation and deployment guides
10. **Monitoring** - Logging, metrics, and error tracking

### Architecture Decisions Made

- **Local Ollama:** Chosen for simplicity and no API key management
- **MVVM + Riverpod:** Clean separation of concerns with reactive state management
- **Streaming Responses:** Real-time token display for better UX
- **Persistent Storage:** SharedPreferences for simple local persistence
- **Cancellation Support:** User can stop LLM responses mid-stream
- **Context-Aware Chat:** Basic support ticket flow with context tracking

