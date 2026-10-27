import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/settings_service.dart';
import '../widgets/connectivity_badge.dart';
import '../main.dart';
import 'sign_to_text_screen.dart';
import 'speech_to_text_screen.dart';

class DemoPhrase {
  final String tagalog;
  final String english;
  final String fsl;
  final IconData icon;

  const DemoPhrase({
    required this.tagalog,
    required this.english,
    required this.fsl,
    required this.icon,
  });
}

class LandingPageScreen extends StatefulWidget {
  const LandingPageScreen({super.key});

  @override
  State<LandingPageScreen> createState() => _LandingPageScreenState();
}

class _LandingPageScreenState extends State<LandingPageScreen> {
  bool _isTagalog = true;
  int _selectedDemoIndex = 0;

  final List<DemoPhrase> _samplePhrases = const [
    DemoPhrase(
      tagalog: 'Kamusta ka?',
      english: 'How are you?',
      fsl: 'Hawakan ang dibdib at itaas ang kamay na may ngiti.',
      icon: Icons.waving_hand_rounded,
    ),
    DemoPhrase(
      tagalog: 'Salamat!',
      english: 'Thank you!',
      fsl: 'Ipatong ang mga daliri sa labi at iunat pasulong.',
      icon: Icons.volunteer_activism_rounded,
    ),
    DemoPhrase(
      tagalog: 'Mahal kita',
      english: 'I love you',
      fsl: 'I-angat ang hinlalaki, hintuturo, at kalingkingan (ILY sign).',
      icon: Icons.favorite_rounded,
    ),
    DemoPhrase(
      tagalog: 'Kailangan ng tulong',
      english: 'Need help',
      fsl: 'Ipatong ang nakasarang kamao sa kabilang palad at iangat.',
      icon: Icons.help_outline_rounded,
    ),
  ];

  void _goToDashboard(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  void _openSignToText(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignToTextScreen()),
    );
  }

  void _openSpeechToText(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpeechToTextScreen()),
    );
  }

  void _adjustTextScale(BuildContext context, double delta) {
    final settings = context.read<SettingsService>();
    final newScale = (settings.textScaleFactor + delta).clamp(0.8, 1.4);
    settings.setTextScaleFactor(double.parse(newScale.toStringAsFixed(1)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settingsService = context.watch<SettingsService>();
    final textScale = settingsService.textScaleFactor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: _isTagalog ? 'Bumalik sa Dashboard' : 'Back to Dashboard',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => _goToDashboard(context),
        ),
        title: Text(
          'TinigSenyas',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: isDark ? Colors.white : const Color(0xFF1565C0),
          ),
        ),
        actions: [
          const ConnectivityBadge(),
          const SizedBox(width: 4),

          // Language switcher
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              setState(() {
                _isTagalog = !_isTagalog;
              });
            },
            child: Text(
              _isTagalog ? 'EN' : 'FIL',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),

          // Dark mode toggle
          IconButton(
            tooltip: isDark ? 'Light mode' : 'Dark mode',
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode_outlined),
            onPressed: () {
              context.read<ThemeProvider>().setThemeMode(
                isDark ? ThemeMode.light : ThemeMode.dark,
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 720;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 32.0 : 16.0,
              vertical: 16.0,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. PWD ACCESSIBILITY QUICK TOOLBAR
                    _buildAccessibilityToolbar(context, isDark, textScale),
                    const SizedBox(height: 16),

                    // 2. HERO CARD (Clean, Simple, Inspiring)
                    _buildHeroCard(context, isDark),
                    const SizedBox(height: 20),

                    // 3. TWO PRIMARY ACCESSIBLE CHANNELS (SENYAS vs BOSES)
                    if (isWide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildSenyasCard(context, isDark)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildBosesCard(context, isDark)),
                        ],
                      )
                    else
                      Column(
                        children: [
                          _buildSenyasCard(context, isDark),
                          const SizedBox(height: 16),
                          _buildBosesCard(context, isDark),
                        ],
                      ),
                    const SizedBox(height: 20),

                    // 4. QUICK PRACTICE PHRASES (Simple & Helpful)
                    _buildQuickPhrasesCard(context, isDark),
                    const SizedBox(height: 20),

                    // 5. DIRECT RETURN TO DASHBOARD FOOTER
                    _buildBottomDashboardAction(context, isDark),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 1. PWD ACCESSIBILITY QUICK TOOLBAR
  Widget _buildAccessibilityToolbar(
    BuildContext context,
    bool isDark,
    double textScale,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF242C38) : const Color(0xFFEBF3FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.accessibility_new_rounded, color: const Color(0xFF1976D2), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _isTagalog
                  ? 'Laki ng letra: ${(textScale * 100).toInt()}%'
                  : 'Text size: ${(textScale * 100).toInt()}%',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          // Decrement text size
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _isTagalog ? 'Paliitin ang teksto' : 'Decrease text size',
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
            onPressed: textScale > 0.8 ? () => _adjustTextScale(context, -0.1) : null,
          ),
          // Increment text size
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: _isTagalog ? 'Palakihin ang teksto' : 'Increase text size',
            icon: const Icon(Icons.text_increase_rounded, size: 20),
            onPressed: textScale < 1.4 ? () => _adjustTextScale(context, 0.1) : null,
          ),
        ],
      ),
    );
  }

  // 2. HERO CARD
  Widget _buildHeroCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sign_language_rounded, color: Color(0xFF1976D2), size: 20),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.sync_alt_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF00897B), size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isTagalog
                ? 'Tinig at Senyas: Tulay sa Komunikasyon'
                : 'Tinig at Senyas: Communication Bridge',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isTagalog
                ? 'Dinisenyo para sa komunidad ng mga Bingi at Nakakarinig upang madaling magkaunawaan.'
                : 'Designed for the Deaf and Hearing communities to communicate effortlessly.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // 3. CARD A: SENYAS (SIGN TO TEXT)
  Widget _buildSenyasCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1976D2).withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sign_language_rounded, color: Color(0xFF1976D2), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTagalog ? 'SENYAS (FSL)' : 'SIGN (FSL)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1976D2),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _isTagalog ? 'Para sa Nagse-senyas' : 'For Signers',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isTagalog
                ? 'Itutok ang camera sa kamay. Isasalin ang senyas sa teksto at boses.'
                : 'Point the camera at your signs to translate them to text and voice.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Icon(Icons.videocam_rounded),
              label: Text(
                _isTagalog ? 'Buksan ang Kamera' : 'Open Sign Camera',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () => _openSignToText(context),
            ),
          ),
        ],
      ),
    );
  }

  // 3. CARD B: BOSES (SPEECH TO TEXT)
  Widget _buildBosesCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.mic_rounded, color: Color(0xFF00897B), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTagalog ? 'BOSES (SPEECH)' : 'SPEECH (VOICE)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _isTagalog ? 'Para sa Nagsasalita' : 'For Speakers',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isTagalog
                ? 'Magsalita sa mikropono upang makita ang malalaking letra sa screen.'
                : 'Speak into the mic to display clear live subtitles for your deaf companion.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black87,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
              ),
              icon: const Icon(Icons.mic_rounded),
              label: Text(
                _isTagalog ? 'Magsimulang Magsalita' : 'Start Speech to Text',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () => _openSpeechToText(context),
            ),
          ),
        ],
      ),
    );
  }

  // 4. QUICK PHRASES (COMPACT & SIMPLE)
  Widget _buildQuickPhrasesCard(BuildContext context, bool isDark) {
    final currentPhrase = _samplePhrases[_selectedDemoIndex];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_rounded, color: Color(0xFF1976D2), size: 20),
              const SizedBox(width: 8),
              Text(
                _isTagalog ? 'Mabilisang Gabay sa Senyas' : 'Quick Sign Helper',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Phrase Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_samplePhrases.length, (index) {
              final isSelected = _selectedDemoIndex == index;
              final p = _samplePhrases[index];
              return ChoiceChip(
                avatar: Icon(
                  p.icon,
                  size: 16,
                  color: isSelected ? Colors.white : const Color(0xFF1976D2),
                ),
                label: Text(p.tagalog),
                selected: isSelected,
                selectedColor: const Color(0xFF1976D2),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedDemoIndex = index;
                    });
                  }
                },
              );
            }),
          ),
          const SizedBox(height: 12),
          // Guide Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121B26) : const Color(0xFFF5F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(currentPhrase.icon, color: const Color(0xFF1976D2), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentPhrase.tagalog} (${currentPhrase.english})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentPhrase.fsl,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 5. BOTTOM DASHBOARD SHORTCUT
  Widget _buildBottomDashboardAction(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2636) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          final button = FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              _isTagalog ? 'Bumalik sa Dashboard' : 'Go to Dashboard',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            onPressed: () => _goToDashboard(context),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.dashboard_customize_rounded, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isTagalog ? 'Main Dashboard' : 'Main Dashboard',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _isTagalog
                      ? 'I-access ang buong translation, history, at settings.'
                      : 'Access all translation tools, logs, and settings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                button,
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isTagalog ? 'Main Dashboard' : 'Main Dashboard',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      _isTagalog
                          ? 'I-access ang buong translation, history, at settings.'
                          : 'Access all translation tools, logs, and settings.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              button,
            ],
          );
        },
      ),
    );
  }
}
