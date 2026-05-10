import 'package:hive_flutter/hive_flutter.dart';
import 'chat_message.dart';

class ChatSession extends HiveObject {
  final String id;
  String title;
  final String modelId;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<AppMessage> messages;

  ChatSession({
    required this.id,
    required this.title,
    required this.modelId,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  String get preview => messages.isEmpty
      ? 'Empty conversation'
      : messages.last.content.length > 80
          ? '${messages.last.content.substring(0, 80)}…'
          : messages.last.content;

  bool get isEmpty => messages.isEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'modelId': modelId,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<dynamic, dynamic> j) {
    final msgs = (j['messages'] as List? ?? [])
        .map((m) => AppMessage.fromJson(m as Map))
        .toList();
    return ChatSession(
      id: j['id'] as String,
      title: j['title'] as String? ?? 'Untitled',
      modelId: j['modelId'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(j['createdAt'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(j['updatedAt'] as int),
      messages: msgs,
    );
  }
}

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 2;

  @override
  ChatSession read(BinaryReader reader) {
    final map = Map<dynamic, dynamic>.from(reader.read() as Map);
    return ChatSession.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer.write(obj.toJson());
  }
}
