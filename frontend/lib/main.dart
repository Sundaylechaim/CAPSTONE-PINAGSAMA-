import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/recognition_provider.dart';
import 'services/settings_service.dart';
import 'services/connectivity_service.dart';
import 'services/tts_service.dart';
import 'services/database_helper.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/speech_to_text_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService();
  await settingsService.init();

  final connectivityService = ConnectivityService();
  final ttsService = TtsService(settingsService);
  final databaseHelper = DatabaseHelper.instance;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        Provider<ConnectivityService>(
          create: (_) => connectivityService,
          dispose: (_, service) => service.dispose(),
        ),
        Provider<TtsService>(
          create: (_) => ttsService,
          dispose: (_, service) => unawaited(service.dispose()),
        ),
        Provider<DatabaseHelper>.value(value: databaseHelper),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(settingsService),
        ),
        ChangeNotifierProvider<RecognitionProvider>(
          create: (_) => RecognitionProvider(),
        ),
      ],
      child: const TinigSenyasApp(),
    ),
  );
}

class TinigSenyasApp extends StatelessWidget {
  const TinigSenyasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'TinigSenyas',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) {
            final textScale = context.watch<SettingsService>().textScaleFactor;
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            );
          },
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};

  Widget _screenForTab(int index) {
    if (!_visitedTabs.contains(index)) return const SizedBox.shrink();
    return switch (index) {
      0 => const HomeScreen(),
      1 => const HistoryScreen(),
      2 => const SpeechToTextScreen(),
      3 => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(4, _screenForTab),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() {
          _currentIndex = index;
          _visitedTabs.add(index);
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.mic), label: 'Speech'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
