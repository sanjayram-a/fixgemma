import 'package:hive_flutter/hive_flutter.dart';

class AppMessage extends HiveObject {
  final String id;
  final String role; // "user" | "assistant" | "system"
  String content;
  final List<String>? imagePaths;
  final String? audioPath;
  final DateTime timestamp;
  bool isStreaming;

  AppMessage({
    required this.id,
    required this.role,
    required this.content,
    this.imagePaths,
    this.audioPath,
    required this.timestamp,
    this.isStreaming = false,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  /// Convert to JSON for Cactus FFI messages array
  Map<String, dynamic> toCactusJson() {
    final map = <String, dynamic>{
      'role': role,
      'content': content,
    };
    if (imagePaths != null && imagePaths!.isNotEmpty) {
      map['images'] = imagePaths;
    }
    if (audioPath != null) {
      map['audio'] = [audioPath];
    }
    return map;
  }

  AppMessage copyWith({String? content, bool? isStreaming}) => AppMessage(
        id: id,
        role: role,
        content: content ?? this.content,
        imagePaths: imagePaths,
        audioPath: audioPath,
        timestamp: timestamp,
        isStreaming: isStreaming ?? this.isStreaming,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        'imagePaths': imagePaths,
        'audioPath': audioPath,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isStreaming': false,
      };

  factory AppMessage.fromJson(Map<dynamic, dynamic> j) => AppMessage(
        id: j['id'] as String,
        role: j['role'] as String,
        content: j['content'] as String? ?? '',
        imagePaths: (j['imagePaths'] as List?)?.cast<String>(),
        audioPath: j['audioPath'] as String?,
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['timestamp'] as int),
        isStreaming: false,
      );
}

class AppMessageAdapter extends TypeAdapter<AppMessage> {
  @override
  final int typeId = 1;

  @override
  AppMessage read(BinaryReader reader) {
    final map = Map<dynamic, dynamic>.from(reader.read() as Map);
    return AppMessage.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, AppMessage obj) {
    writer.write(obj.toJson());
  }
}
