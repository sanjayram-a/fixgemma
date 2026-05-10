import 'package:hive_flutter/hive_flutter.dart';
import '../core/constants/hf_models.dart';

enum ModelStatus {
  notDownloaded,
  downloading,
  paused,
  downloaded,
  loading,
  ready,
  error,
}

class AIModel extends HiveObject {
  final String id;
  ModelStatus status;
  int filesCompleted;
  int totalFiles;
  String? localDirPath;
  String? errorMessage;
  DateTime? downloadedAt;

  AIModel({
    required this.id,
    this.status = ModelStatus.notDownloaded,
    this.filesCompleted = 0,
    this.totalFiles = 0,
    this.localDirPath,
    this.errorMessage,
    this.downloadedAt,
  });

  HFModelDef? get def => modelById(id);

  bool get isReady => status == ModelStatus.ready;
  bool get isDownloaded =>
      status == ModelStatus.downloaded ||
      status == ModelStatus.ready ||
      status == ModelStatus.loading;
  bool get isDownloading => status == ModelStatus.downloading;
  bool get isPaused => status == ModelStatus.paused;
  bool get hasError => status == ModelStatus.error;

  double get downloadProgress =>
      totalFiles > 0 ? filesCompleted / totalFiles : 0.0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.index,
        'filesCompleted': filesCompleted,
        'totalFiles': totalFiles,
        'localDirPath': localDirPath,
        'errorMessage': errorMessage,
        'downloadedAt': downloadedAt?.millisecondsSinceEpoch,
      };

  factory AIModel.fromJson(Map<dynamic, dynamic> j) => AIModel(
        id: j['id'] as String,
        status: ModelStatus.values[j['status'] as int? ?? 0],
        filesCompleted: j['filesCompleted'] as int? ?? 0,
        totalFiles: j['totalFiles'] as int? ?? 0,
        localDirPath: j['localDirPath'] as String?,
        errorMessage: j['errorMessage'] as String?,
        downloadedAt: j['downloadedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(j['downloadedAt'] as int)
            : null,
      );
}

class AIModelAdapter extends TypeAdapter<AIModel> {
  @override
  final int typeId = 0;

  @override
  AIModel read(BinaryReader reader) {
    final map = Map<dynamic, dynamic>.from(reader.read() as Map);
    return AIModel.fromJson(map);
  }

  @override
  void write(BinaryWriter writer, AIModel obj) {
    writer.write(obj.toJson());
  }
}
