
# Flutter Chat App (MVVM + Local Ollama Integration)

This document outlines the **technical structure, architecture, and setup** for a Flutter chat application using a **local LLM (gemma3:4b via Ollama)** with **MVVM**, **Riverpod**, and a clean layered project layout.

---

## ✅ Project Architecture

### Folder Structure
```

lib/
├─ ui/
│   ├─ <feature_name>/
│   │   ├─ view/
│   │   ├─ viewmodel/
│   │   └─ widgets/
├─ domain/                (optional)
└─ data/
├─ repositories/
│   ├─ repositories.dart   // exports all repos as Riverpod providers
└─ services/
├─ services.dart       // exports all services as Riverpod providers


### MVVM Rules
- `ui/feature/view` → Widgets and screens
- `ui/feature/viewmodel` → State + logic
- `ui/feature/widgets` → Reusable UI components
- `data/repositories` → Single source of truth per data type
- `data/services` → External access (Ollama HTTP, storage, etc.)
- `domain/` → Optional (models, mappers, use cases)

---

## ✅ State Management (Riverpod)

### Core Principles
- Use **flutter_riverpod**
- `services.dart` exposes **all services** as providers
- `repositories.dart` exposes **all repositories** as providers
- Each ViewModel creates **its own provider**
- ViewModels use `ref` to access repositories
- UI manually instantiates and consumes ViewModels — **no DI in UI layer**

### Example Structure

```dart
// data/services/services.dart
final chatApiServiceProvider = Provider<ChatApiService>((ref) {
  return ChatApiService();
});

// data/repositories/repositories.dart
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  final api = ref.read(chatApiServiceProvider);
  return ChatRepository(api);
});

// ui/chat/viewmodel/chat_viewmodel.dart
final chatViewModelProvider = ChangeNotifierProvider((ref) {
  final repo = ref.read(chatRepositoryProvider);
  return ChatViewModel(repo, ref);
});
````

In the UI:

```dart
final viewModel = ref.watch(chatViewModelProvider);
```

---

## ✅ Local LLM Integration (Ollama)

### Model

* **gemma3:4b** (local)
* No API key required

### Setup

```
ollama pull gemma3:4b
ollama run gemma3:4b
```

### Endpoint

```
POST http://localhost:11434/api/generate
{
  "model": "gemma3:4b",
  "prompt": "<message>"
}
```

### Service Example

```dart
class ChatApiService {
  final _baseUrl = 'http://localhost:11434/api/generate';

  Future<Map<String, dynamic>> sendPrompt(String prompt) async {
    final start = DateTime.now();
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'gemma3:4b',
        'prompt': prompt,
      }),
    );
    final end = DateTime.now();
    final latency = end.difference(start).inMilliseconds;

    return {
      'data': jsonDecode(response.body),
      'latencyMs': latency,
    };
  }
}
```

---

## ✅ Repositories

Repositories wrap the services and are the **single source of truth**:

```dart
class ChatRepository {
  final ChatApiService _api;
  ChatRepository(this._api);

  Future<(String reply, int latencyMs)> sendMessage(String text) async {
    final result = await _api.sendPrompt(text);
    final reply = result['data']?['response'] ?? '';
    final latency = result['latencyMs'];
    return (reply, latency);
  }
}
```

---

## ✅ ViewModels

Each feature ViewModel:

* Defines its own provider
* Uses repositories via `ref.read`
* Exposes state to views

```dart
class ChatViewModel extends ChangeNotifier {
  final ChatRepository _repo;
  final Ref _ref;

  ChatViewModel(this._repo, this._ref);

  List<Message> messages = [];
  bool isLoading = false;

  Future<void> sendMessage(String text) async {
    isLoading = true;
    notifyListeners();

    final (reply, latency) = await _repo.sendMessage(text);
    messages.add(Message(text: text, role: 'user'));
    messages.add(Message(text: reply, role: 'assistant', latency: latency));

    isLoading = false;
    notifyListeners();
  }
}
```

---

## ✅ Latency Handling

Latency is tracked per message:

* Capture `DateTime.now()` before and after the request
* Store it in ViewModel or message model
* Can display or log locally

---

## ✅ Local Ticket Logic (Optional)

If ticket creation is needed:

* Implement locally in ViewModel
* Example: `T-${DateTime.now().millisecondsSinceEpoch}`

---

## ✅ UI Layer

* Instantiates the ViewModel using provider
* Calls ViewModel methods
* Listens to state changes
* **No dependency injection on UI level**

Example:

```dart
final viewModel = ref.watch(chatViewModelProvider);

...
onPressed: () {
  viewModel.sendMessage(inputController.text);
}
```

---

## ✅ Summary

* ✅ No backend — local Ollama only
* ✅ MVVM with proper folder structure
* ✅ Riverpod for all layers
* ✅ Services + Repositories as providers
* ✅ Each ViewModel has its own provider
* ✅ No DI in UI
* ✅ gemma3:4b via `http://localhost:11434/api/generate`
* ✅ Latency handled locally

---

## 🔄 Trade-offs

### What Was Cut to Meet Time Constraints

#### 1. **Backend HTTP API Layer**
- **Missing:** Dedicated backend server that brokers LLM requests
- **Current:** Direct local Ollama calls from Flutter app
- **Impact:** No provider key security, no request validation, no rate limiting
- **Why Cut:** Local development focus, 2-hour time constraint
- **Next Steps:** Add Express.js/Node.js backend with proper API endpoints

#### 2. **Comprehensive Error Handling & Retry UI**
- **Missing:** Error state indicators, retry buttons, auto-retry logic
- **Current:** Basic error handling, no user-facing retry mechanism
- **Impact:** Poor UX when requests fail, no recovery options
- **Why Cut:** Focus on core chat functionality first
- **Next Steps:** Add error states, retry buttons, exponential backoff

#### 3. **Session Management System**
- **Missing:** `sessionId` generation, session-based conversation tracking
- **Current:** Simple message persistence without session concept
- **Impact:** No conversation isolation, no session-based features
- **Why Cut:** MVP focus on basic chat functionality
- **Next Steps:** Add session UUIDs, session-based persistence

#### 4. **Structured Support Ticket Flow**
- **Missing:** Robust field collection, confirmation steps, ticket ID generation
- **Current:** Basic context tracking with simple heuristics
- **Impact:** Limited ticket creation workflow, no structured data extraction
- **Why Cut:** Complex LLM prompt engineering and state management
- **Next Steps:** Implement proper field extraction, confirmation UI, ticket generation

#### 5. **Accessibility & Dark Mode**
- **Missing:** Dark mode support, comprehensive accessibility labels
- **Current:** Basic accessibility, light mode only
- **Impact:** Limited accessibility, no theme support
- **Why Cut:** UI polish deprioritized for core functionality
- **Next Steps:** Add theme switching, comprehensive accessibility

#### 6. **Input Validation & Security**
- **Missing:** Prompt length limits, input sanitization, request timeouts
- **Current:** No validation layer, basic error handling
- **Impact:** Potential security issues, no input constraints
- **Why Cut:** Local development environment, time constraints
- **Next Steps:** Add input validation, sanitization, security headers

#### 7. **Performance Optimizations**
- **Missing:** Advanced cancellation logic, request queuing, performance monitoring
- **Current:** Basic cancellation, streaming support
- **Impact:** Suboptimal performance under load, limited monitoring
- **Why Cut:** Focus on core functionality over optimization
- **Next Steps:** Add request queuing, performance metrics, advanced cancellation

### What Would Be Improved Next If we had enough time

1. **Backend API Layer** - Add Node.js server with proper endpoints
2. **Error Recovery** - Comprehensive retry logic and error states
3. **Session Management** - UUID-based session tracking
4. **Structured Tickets** - Proper field extraction and confirmation flow
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

