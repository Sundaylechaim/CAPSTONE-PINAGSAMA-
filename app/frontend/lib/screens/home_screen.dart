import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';
import '../widgets/connectivity_badge.dart';
import 'sign_to_text_screen.dart';
import 'speech_to_text_screen.dart';
import 'settings_screen.dart';
import 'landing_page_screen.dart';

const Color _kAppBlue = Color(0xFF0138FF);
const Color _kAppYellow = Color(0xFFFFC801);

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

  void _openLandingPage(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LandingPageScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final settingsService = context.watch<SettingsService>();
    final textScale = settingsService.textScaleFactor;

    final bgColor = isDarkMode ? const Color(0xFF090E1A) : const Color(0xFFF1F5F9);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,

      // GLASSMORPHIC APP BAR
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF0C1220).withValues(alpha: 0.65)
                    : Colors.white.withValues(alpha: 0.70),
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'TinigSenyas',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _kAppYellow,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.explore_outlined),
            tooltip: 'Landing Page & Guide',
            onPressed: () => _openLandingPage(context),
          ),
          const ConnectivityBadge(),
          const SizedBox(width: 14),
        ],
      ),

      // GLASSMORPHIC DRAWER
      drawer: Drawer(
        backgroundColor: isDarkMode
            ? const Color(0xFF0E1626).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDarkMode
                        ? [_kAppBlue.withValues(alpha: 0.4), const Color(0xFF0C1220)]
                        : [_kAppBlue, const Color(0xFF002BB5)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'TinigSenyas System',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'FSL Translation Prototype',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),

              // Dark Mode Switch
              SwitchListTile(
                secondary: Icon(
                  Icons.dark_mode,
                  color: isDarkMode ? _kAppYellow : _kAppBlue,
                ),
                title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w700)),
                value: isDarkMode,
                onChanged: (val) {
                  context.read<ThemeProvider>().setThemeMode(
                    val ? ThemeMode.dark : ThemeMode.light,
                  );
                },
              ),
              const Divider(height: 1),

              // Text Size Scale
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    Icon(Icons.text_fields, color: isDarkMode ? _kAppYellow : _kAppBlue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Text Size Scale',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${(textScale * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Slider(
                  activeColor: _kAppBlue,
                  thumbColor: _kAppYellow,
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
              const Divider(height: 1),

              ListTile(
                leading: Icon(Icons.system_update, color: isDarkMode ? _kAppYellow : _kAppBlue),
                title: const Text('FSL Model Status', style: TextStyle(fontWeight: FontWeight.w600)),
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
                leading: Icon(Icons.explore_outlined, color: isDarkMode ? _kAppYellow : _kAppBlue),
                title: const Text('Welcome Guide & Landing', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Dual-mode overview & phrases'),
                onTap: () {
                  Navigator.pop(context);
                  _openLandingPage(context);
                },
              ),
              ListTile(
                leading: Icon(Icons.info_outline, color: isDarkMode ? _kAppYellow : _kAppBlue),
                title: const Text('About Project', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  showAboutDialog(
                    context: context,
                    applicationName: 'TinigSenyas',
                    applicationVersion: '1.0.0',
                    applicationLegalese: 'Filipino Sign Language e-Learning & Translation System',
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // BODY WITH AMBIENT GLOWING ORBS + FROSTED GLASS PANELS
      body: Stack(
        children: [
          // Ambient Orb 1 (Top-Right Blue Glow)
          Positioned(
            top: -50,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAppBlue.withValues(alpha: isDarkMode ? 0.35 : 0.25),
                      _kAppBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ambient Orb 2 (Center-Left Sun Yellow Glow)
          Positioned(
            top: 260,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAppYellow.withValues(alpha: isDarkMode ? 0.22 : 0.24),
                      _kAppYellow.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ambient Orb 3 (Bottom-Right Soft Blue Glow)
          Positioned(
            bottom: -60,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _kAppBlue.withValues(alpha: isDarkMode ? 0.25 : 0.18),
                      _kAppBlue.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Scrollable Glass Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Glass Greeting Header
                  _buildGlassGreeting(context, isDarkMode, textColor, subtextColor),
                  const SizedBox(height: 18),

                  // Card 1: SIGN TO TEXT (Frosted Glass with Blue Tint)
                  _GlassCard(
                    icon: Icons.back_hand,
                    accentColor: _kAppBlue,
                    title: 'SIGN TO TEXT',
                    subtitle: 'FSL model is\nin training',
                    actionText: 'Preview camera',
                    isDark: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignToTextScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Card 2: SPEECH TO TEXT (Frosted Glass with Yellow Tint)
                  _GlassCard(
                    icon: Icons.mic,
                    accentColor: _kAppYellow,
                    title: 'SPEECH TO TEXT',
                    subtitle: 'Translate your\nVoice to Text',
                    actionText: 'Tap here to start',
                    isDark: isDarkMode,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SpeechToTextScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Card 3: WELCOME & LANDING GUIDE (Frosted Glass with Neutral Glow)
                  _GlassCard(
                    icon: Icons.explore_rounded,
                    accentColor: isDarkMode ? const Color(0xFF38BDF8) : _kAppBlue,
                    title: 'WELCOME & LEARNING GUIDE',
                    subtitle: 'Revisit landing page, quick phrases\n& accessibility controls',
                    actionText: 'Go to landing page',
                    isDark: isDarkMode,
                    onTap: () => _openLandingPage(context),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Glass Greeting Card
  Widget _buildGlassGreeting(
    BuildContext context,
    bool isDarkMode,
    Color textColor,
    Color subtextColor,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.14)
                  : Colors.white.withValues(alpha: 0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.25)
                    : _kAppBlue.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kAppBlue.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(4),
                child: Image.asset(
                  'assets/images/logo.png',
                  fit: BoxFit.contain,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hello!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('👋', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'How can we help you today?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? _kAppBlue.withValues(alpha: 0.25)
                      : _kAppBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kAppBlue.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ready',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDarkMode ? Colors.white : _kAppBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// REUSABLE FROSTED GLASS FEATURE CARD
class _GlassCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final String actionText;
  final VoidCallback onTap;
  final bool isDark;

  const _GlassCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentColor = isDark ? Colors.white : const Color(0xFF0F172A);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.85),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : accentColor.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Small glass badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.6,
                                color: isDark
                                    ? (accentColor == _kAppYellow ? _kAppYellow : const Color(0xFF60A5FA))
                                    : (accentColor == _kAppYellow ? const Color(0xFFB45309) : _kAppBlue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: contentColor,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Glass action pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  actionText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: contentColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.arrow_forward_rounded, size: 14, color: contentColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Glass circular icon container
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentColor.withValues(alpha: 0.45),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          icon,
                          size: 34,
                          color: isDark
                              ? (accentColor == _kAppYellow ? _kAppYellow : const Color(0xFF60A5FA))
                              : (accentColor == _kAppYellow ? const Color(0xFFB45309) : _kAppBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
