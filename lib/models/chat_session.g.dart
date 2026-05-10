// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual Hive adapter for ChatSession

import 'package:hive_flutter/hive_flutter.dart';
import 'chat_session.dart';
import 'chat_message.dart';

class ChatSessionAdapter extends TypeAdapter<ChatSession> {
  @override
  final int typeId = 2;

  @override
  ChatSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatSession(
      id: fields[0] as String,
      title: fields[1] as String,
      modelId: fields[2] as String,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
      messages: (fields[5] as List).cast<AppMessage>(),
    );
  }

  @override
  void write(BinaryWriter writer, ChatSession obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.modelId)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt)
      ..writeByte(5)
      ..write(obj.messages);
  }
}
