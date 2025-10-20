
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

