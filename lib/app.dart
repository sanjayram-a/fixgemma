import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/history/history_screen.dart';
import 'screens/settings/settings_screen.dart';

class FixGemmaApp extends StatelessWidget {
  const FixGemmaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FixGemma',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      initialRoute: '/',
      routes: {
        '/': (_) => const HomeScreen(),
        '/chat': (_) => const ChatScreen(),
        '/history': (_) => const HistoryScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
