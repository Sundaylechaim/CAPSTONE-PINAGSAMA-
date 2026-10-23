import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';
import '../widgets/connectivity_badge.dart';
import 'sign_to_text_screen.dart';
import 'speech_to_text_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _modelVersion = 'Not installed';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = context.read<SettingsService>();
    _modelVersion = settings.modelVersion;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final settingsService = context.watch<SettingsService>();
    final textScale = settingsService.textScaleFactor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TinigSenyas'),
        actions: [const ConnectivityBadge(), const SizedBox(width: 16)],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      Icons.back_hand,
                      size: 28,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TinigSenyas System',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    'FSL Translation Prototype',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Dark Mode Switch
            SwitchListTile(
              secondary: Icon(
                Icons.dark_mode,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Dark Mode'),
              value: isDarkMode,
              onChanged: (val) {
                context.read<ThemeProvider>().setThemeMode(
                  val ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
            const Divider(),
            // Text Size Scale
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Text Size Scale',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Slider(
                value: textScale,
                min: 0.8,
                max: 1.4,
                divisions: 6,
                label: '${(textScale * 100).toInt()}%',
                onChanged: (val) {
                  settingsService.setTextScaleFactor(val);
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.system_update,
                color: theme.colorScheme.primary,
              ),
              title: const Text('FSL Model Status'),
              subtitle: Text('Current: $_modelVersion'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
              ),
              title: const Text('About Project'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'TinigSenyas',
                  applicationVersion: '1.0.0',
                  applicationLegalese:
                      'Filipino Sign Language e-Learning & Translation System',
                );
              },
            ),
          ],
        ),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello!',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'How can we help you today?',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            // Sign to Text Card
            _FeatureCard(
              icon: Icons.back_hand,
              iconColor: theme.colorScheme.onPrimaryContainer,
              bgColor: theme.colorScheme.primaryContainer,
              contentColor: theme.colorScheme.onPrimaryContainer,
              title: 'SIGN TO TEXT',
              subtitle: 'FSL model is\nin training',
              actionText: 'Preview camera',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignToTextScreen()),
                );
              },
            ),
            const SizedBox(height: 16),

            // Speech to Text Card
            _FeatureCard(
              icon: Icons.mic,
              iconColor: theme.colorScheme.onSecondaryContainer,
              bgColor: theme.colorScheme.secondaryContainer,
              contentColor: theme.colorScheme.onSecondaryContainer,
              title: 'SPEECH TO TEXT',
              subtitle: 'Translate your\nVoice to Text',
              actionText: 'Tap here to start',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SpeechToTextScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color contentColor;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.contentColor,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: contentColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: contentColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        actionText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: contentColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 14, color: contentColor),
                    ],
                  ),
                ],
              ),
            ),
            Icon(icon, size: 60, color: iconColor.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}
