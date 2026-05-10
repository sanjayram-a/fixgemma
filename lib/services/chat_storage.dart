import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';

class ChatStorage {
  static const _boxName = 'chat_sessions';
  late Box<ChatSession> _box;
  static const _uuid = Uuid();

  Future<void> init() async {
    _box = await Hive.openBox<ChatSession>(_boxName);
  }

  /// Get all sessions sorted by updatedAt desc
  List<ChatSession> getAllSessions() {
    final sessions = _box.values.toList();
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

  /// Save/update a session
  Future<void> saveSession(ChatSession session) async {
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
