import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: implementation_imports
import 'dart:ui_web' as ui_web;
import 'database_helper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TinigSenyasApp());
}

class TinigSenyasApp extends StatelessWidget {
  const TinigSenyasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TinigSenyas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// NAVIGATION BAR SETUP
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const HistoryScreen(),
    const Center(child: Text('Favorites Screen')),
    const Center(child: Text('Guide Screen')),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.black54,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'Guide'),
        ],
      ),
    );
  }
}

// ==========================================
// HOME SCREEN (Sidebar with Accessibility & Dark Mode)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDarkMode = false;
  double _textScaleFactor = 1.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _isDarkMode ? Colors.grey[900] : const Color(0xFF64B5F6),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: _isDarkMode ? Colors.white : Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'TinigSenyas',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[850] : const Color(0xFF64B5F6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.back_hand, size: 28, color: Colors.blueAccent),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'TinigSenyas System',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                  Text(
                    'FSL Translation Module',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Dark Mode Switch
            SwitchListTile(
              secondary: const Icon(Icons.dark_mode, color: Colors.blueAccent),
              title: const Text('Dark Mode'),
              value: _isDarkMode,
              onChanged: (val) {
                setState(() {
                  _isDarkMode = val;
                });
              },
            ),
            const Divider(),
            // Typography / Text Size Adjustment Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: const [
                  Icon(Icons.text_fields, color: Colors.blueAccent),
                  SizedBox(width: 16),
                  Text('Text Size Scale', style: TextStyle(fontSize: 16, color: Colors.black87)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Slider(
                value: _textScaleFactor,
                min: 0.8,
                max: 1.4,
                divisions: 3,
                label: '${(_textScaleFactor * 100).toInt()}%',
                onChanged: (val) {
                  setState(() {
                    _textScaleFactor = val;
                  });
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.menu_book, color: Colors.blueAccent),
              title: const Text('FSL Learning Guide'),
              onTap: () {
                Navigator.pop(context);
                // Hook up guide navigation if needed
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blueAccent),
              title: const Text('About Project'),
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
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(_textScaleFactor)),
        child: Container(
          color: _isDarkMode ? Colors.grey[900] : Colors.white,
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              Text(
                'How can we help you today?',
                style: TextStyle(color: _isDarkMode ? Colors.white60 : Colors.grey),
              ),
              const SizedBox(height: 20),

              // Sign to Text Card
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignToTextScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF90CAF9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SIGN TO TEXT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            SizedBox(height: 8),
                            Text('Translate your\nHand gesture', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Text('Tap here to start ', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                Icon(Icons.arrow_forward, size: 14, color: Colors.blueAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.back_hand, size: 60, color: Colors.white.withOpacity(0.8)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Speech to Text Card
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SpeechToTextScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBBDEFB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('SPEECH TO TEXT', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                            SizedBox(height: 8),
                            Text('Translate your\nVoice to Text', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black)),
                            SizedBox(height: 10),
                            Row(
                              children: [
                                Text('Tap here to start ', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                                Icon(Icons.arrow_forward, size: 14, color: Colors.blueAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.mic, size: 60, color: Colors.blueAccent.withOpacity(0.8)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SIGN TO TEXT CAMERA SCREEN
// ==========================================
class SignToTextScreen extends StatefulWidget {
  const SignToTextScreen({super.key});

  @override
  State<SignToTextScreen> createState() => _SignToTextScreenState();
}

class _SignToTextScreenState extends State<SignToTextScreen> {
  late String _viewId;
  // ignore: avoid_web_libraries_in_flutter, deprecated_member_use
  html.ImageElement? _imgElement;
  
  final String _currentRecognizedText = "Waiting for gesture...";
  final String _currentTranslation = "Position your hands in frame";
  final double _currentConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _viewId = 'mjpeg-stream-${DateTime.now().millisecondsSinceEpoch}';
    
    _imgElement = html.ImageElement()
      ..src = 'http://127.0.0.1:5000/video_feed'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';

    // ignore: undefined_prefixed_name, implementation_imports
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => _imgElement!,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Sign to Text', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      HtmlElementView(viewType: _viewId),
                      Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF64B5F6), width: 3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 65,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFBBDEFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Recognized:', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 10)),
                        Row(
                          children: [
                            Text(_currentRecognizedText, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black)),
                            const SizedBox(width: 4),
                            Text('($_currentTranslation)', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Color(0xFF03A9F4),
                    child: Icon(Icons.volume_up, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () async {
                          if (_currentRecognizedText == "Waiting for gesture...") {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No gesture detected to send yet!'), duration: Duration(milliseconds: 600)),
                            );
                            return;
                          }

                          await DatabaseHelper.instance.saveRecognizedGesture(_currentRecognizedText, _currentConfidence);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Saved to History!'), duration: Duration(milliseconds: 800)),
                            );
                          }
                        },
                        child: const Row(
                          children: [
                            Text('Send', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)),
                            SizedBox(width: 2),
                            Icon(Icons.send, size: 14, color: Colors.blueAccent),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Text('Repeat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                          SizedBox(width: 2),
                          Icon(Icons.replay, size: 12, color: Colors.black54),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SPEECH TO TEXT SCREEN (Chat Message Bubbles)
// ==========================================
class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({super.key});

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentWords = "";
  final List<String> _messages = [];

  void _toggleListen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => print('status: $status'),
        onError: (error) => print('error: $error'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          _currentWords = "Listening...";
        });
        _speech.listen(
          onResult: (result) => setState(() {
            _currentWords = result.recognizedWords;
            // If the speech recognition result is final, add it as a chat bubble
            if (result.finalResult && _currentWords.isNotEmpty) {
              _messages.add(_currentWords);
              _currentWords = "Listening...";
            }
          }),
        );
      } else {
        setState(() {
          _currentWords = "Speech recognition unavailable.";
        });
      }
    } else {
      setState(() {
        _isListening = false;
        if (_currentWords.isNotEmpty && _currentWords != "Listening..." && _currentWords != "Speech recognition unavailable.") {
          _messages.add(_currentWords);
        }
        _currentWords = "";
      });
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Speech to Text', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Chat Messages Bubble List Area
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _messages.isEmpty && _currentWords.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages yet.\nTap the mic below and start speaking!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    : ListView(
                        children: [
                          ..._messages.map((msg) => Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF64B5F6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    msg,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              )),
                          if (_isListening && _currentWords.isNotEmpty)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue[200]?.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _currentWords,
                                  style: const TextStyle(color: Colors.black54, fontSize: 16, fontStyle: FontStyle.italic),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Microphone Button
            FloatingActionButton.extended(
              onPressed: _toggleListen,
              backgroundColor: _isListening ? Colors.redAccent : const Color(0xFF03A9F4),
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
              label: Text(_isListening ? 'Listening...' : 'Tap to Speak'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HISTORY SCREEN
// ==========================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _historyList = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.getHistory();
    setState(() {
      _historyList = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF64B5F6),
        title: const Text('Translation History', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _historyList.isEmpty
          ? const Center(
              child: Text(
                'No translation history yet.\nTry translating a sign and hit Send!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              itemCount: _historyList.length,
              itemBuilder: (context, index) {
                final item = _historyList[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF90CAF9),
                      child: Icon(Icons.back_hand, color: Colors.blueAccent),
                    ),
                    title: Text(
                      item['output_text'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text('Confidence: ${((item['confidence'] ?? 0.95) * 100).toStringAsFixed(1)}%'),
                    trailing: Text(
                      item['created_at'].toString().substring(11, 16),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
    );
  }
}