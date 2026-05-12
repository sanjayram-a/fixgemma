import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';

class ChatStorage {
  static const _boxName = 'chat_sessions';
  late Box<ChatSession> _box;
  static const _uuid = Uuid();

  Future<void> init() async {
    _box = await Hive.openBox<ChatSession>(_boxName);
    // Purge any abandoned empty sessions from previous runs
    await _purgeEmpty();
  }

  /// Delete all sessions that have no real user messages.
  Future<void> _purgeEmpty() async {
    final toDelete = _box.values
        .where((s) => !s.messages.any((m) => m.isUser))
        .map((s) => s.id)
        .toList();
    for (final id in toDelete) {
      await _box.delete(id);
    }
  }

  /// Get all sessions that have at least one real exchange, sorted newest first
  List<ChatSession> getAllSessions() {
    final sessions = _box.values
        .where((s) => s.messages.any((m) => m.isUser)) // only real sessions
        .toList();
    sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sessions;
  }

  /// Create a new empty session
  Future<ChatSession> createSession(String modelId) async {
    final session = ChatSession(
      id: _uuid.v4(),
      title: 'New Repair Session',
      modelId: modelId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
    );
    await _box.put(session.id, session);
    return session;
  }

  /// Save/update a session — only persists if it has real user messages.
  Future<void> saveSession(ChatSession session) async {
    // Don't save abandoned empty sessions
    if (!session.messages.any((m) => m.isUser)) return;

    session.updatedAt = DateTime.now();

    // Auto-title from first user message
    if (session.title == 'New Repair Session' &&
        session.messages.isNotEmpty) {
      final firstUser = session.messages
          .firstWhere((m) => m.isUser, orElse: () => session.messages.first);
      final t = firstUser.content;
      session.title = t.length > 40 ? '${t.substring(0, 40)}…' : t;
    }

    await _box.put(session.id, session);
  }

  /// Delete a session
  Future<void> deleteSession(String sessionId) async {
    await _box.delete(sessionId);
  }

  /// Clear all sessions
  Future<void> clearAll() async => await _box.clear();

  ChatSession? getSession(String id) => _box.get(id);
}
