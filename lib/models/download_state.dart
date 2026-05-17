enum DownloadStatus { idle, queued, downloading, extracting, paused, completed, failed }

class DownloadProgress {
  final DownloadStatus status;
  final int filesCompleted;
  final int totalFiles;
  final int bytesReceived;
  final int totalBytes;
  /// Pre-computed smooth 0.0–1.0 progress (based on bytes, not file count)
  final double overallProgress;
  final double extractProgress;  // 0.0–1.0 during extraction
  final double speedBps;
  final Duration? eta;
  final String? errorMessage;
  /// Current retry attempt (1-based). 0 means first try (no retry yet).
  final int retryAttempt;
  /// Maximum retries allowed before giving up.
  final int maxRetries;

  const DownloadProgress({
    this.status = DownloadStatus.idle,
    this.filesCompleted = 0,
    this.totalFiles = 0,
    this.bytesReceived = 0,
    this.totalBytes = 0,
    this.overallProgress = 0,
    this.extractProgress = 0,
    this.speedBps = 0,
    this.eta,
    this.errorMessage,
    this.retryAttempt = 0,
    this.maxRetries = 3,
  });

  /// Byte-based progress if available, else file-count based.
  double get progress => totalBytes > 0
      ? overallProgress
      : (totalFiles > 0 ? filesCompleted / totalFiles : 0.0);

  bool get isActive  => status == DownloadStatus.downloading;
  bool get isPaused  => status == DownloadStatus.paused;
  bool get isDone    => status == DownloadStatus.completed;
  bool get hasFailed => status == DownloadStatus.failed;
  bool get isRetrying => retryAttempt > 0 && status == DownloadStatus.downloading;

  DownloadProgress copyWith({
    DownloadStatus? status,
    int? filesCompleted,
    int? totalFiles,
    int? bytesReceived,
    int? totalBytes,
    double? overallProgress,
    double? extractProgress,
    double? speedBps,
    Duration? eta,
    String? errorMessage,
    int? retryAttempt,
    int? maxRetries,
  }) =>
      DownloadProgress(
        status: status ?? this.status,
        filesCompleted: filesCompleted ?? this.filesCompleted,
        totalFiles: totalFiles ?? this.totalFiles,
        bytesReceived: bytesReceived ?? this.bytesReceived,
        totalBytes: totalBytes ?? this.totalBytes,
        overallProgress: overallProgress ?? this.overallProgress,
        extractProgress: extractProgress ?? this.extractProgress,
        speedBps: speedBps ?? this.speedBps,
        eta: eta ?? this.eta,
        errorMessage: errorMessage ?? this.errorMessage,
        retryAttempt: retryAttempt ?? this.retryAttempt,
        maxRetries: maxRetries ?? this.maxRetries,
      );
}
