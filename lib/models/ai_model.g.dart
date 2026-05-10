// GENERATED CODE - DO NOT MODIFY BY HAND
// Manual Hive adapter for AIModel

import 'package:hive_flutter/hive_flutter.dart';
import 'ai_model.dart';

class ModelStatusAdapter extends TypeAdapter<ModelStatus> {
  @override
  final int typeId = 10;

  @override
  ModelStatus read(BinaryReader reader) {
    return ModelStatus.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, ModelStatus obj) {
    writer.writeByte(obj.index);
  }
}

class AIModelAdapter extends TypeAdapter<AIModel> {
  @override
  final int typeId = 0;

  @override
  AIModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AIModel(
      id: fields[0] as String,
      status: fields[1] as ModelStatus,
      filesCompleted: fields[2] as int,
      totalFiles: fields[3] as int,
      localDirPath: fields[4] as String?,
      errorMessage: fields[5] as String?,
      downloadedAt: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, AIModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.status)
      ..writeByte(2)
      ..write(obj.filesCompleted)
      ..writeByte(3)
      ..write(obj.totalFiles)
      ..writeByte(4)
      ..write(obj.localDirPath)
      ..writeByte(5)
      ..write(obj.errorMessage)
      ..writeByte(6)
      ..write(obj.downloadedAt);
  }
}
