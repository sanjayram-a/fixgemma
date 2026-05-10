// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual Hive adapter for AppMessage

import 'package:hive_flutter/hive_flutter.dart';
import 'chat_message.dart';

class AppMessageAdapter extends TypeAdapter<AppMessage> {
  @override
  final int typeId = 1;

  @override
  AppMessage read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppMessage(
      id: fields[0] as String,
      role: fields[1] as String,
      content: fields[2] as String,
      imagePaths: (fields[3] as List?)?.cast<String>(),
      audioPath: fields[4] as String?,
      timestamp: fields[5] as DateTime,
      isStreaming: fields[6] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, AppMessage obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.role)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.imagePaths)
      ..writeByte(4)
      ..write(obj.audioPath)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.isStreaming);
  }
}
