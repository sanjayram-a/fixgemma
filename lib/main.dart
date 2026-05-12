import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/ai_model.dart';
import 'models/chat_message.dart';
import 'models/chat_session.dart';
import 'providers/chat_provider.dart';
import 'services/chat_storage.dart';
import 'services/download_manager.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise the OS-level background downloader (FileDownloader).
  // Must be called before any download starts and before the widget tree.
  await DownloadManager.initialise();

  // Initialize Hive with manual adapters (no code-gen required)
  await Hive.initFlutter();
  Hive.registerAdapter(AIModelAdapter());
  Hive.registerAdapter(AppMessageAdapter());
  Hive.registerAdapter(ChatSessionAdapter());

  // Open Hive box eagerly so ChatStorage is ready before any widget uses it
  final chatStorage = ChatStorage();
  await chatStorage.init();

  runApp(
    ProviderScope(
      overrides: [
        chatStorageProvider.overrideWithValue(chatStorage),
      ],
      child: const FixGemmaApp(),
    ),
  );
}
