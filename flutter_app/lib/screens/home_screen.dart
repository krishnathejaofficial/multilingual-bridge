import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import 'voice_query_screen.dart';
import 'screenshot_screen.dart';
import 'paste_reply_screen.dart';
import 'conversation_screen.dart';
import 'settings_screen.dart';
import '../widgets/language_selector.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        title: const Text(
          '🌐 Multilingual Bridge',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white, size: 30),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Language selector strip
              _LanguageBar(appState: appState),
              const SizedBox(height: 20),
              // Main 2x2 grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _ModeCard(
                      icon: '🎤',
                      label: 'Speak & Translate',
                      color: const Color(0xFF1565C0),
                      description: 'Speak in your language',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const VoiceQueryScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '📷',
                      label: 'Screenshot',
                      color: const Color(0xFF2E7D32),
                      description: 'Read any image or text',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ScreenshotScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '📋',
                      label: 'Paste & Reply',
                      color: const Color(0xFFE65100),
                      description: 'Understand & reply to messages',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PasteReplyScreen()),
                      ),
                    ),
                    _ModeCard(
                      icon: '👥',
                      label: 'Two-Person Talk',
                      color: const Color(0xFF6A1B9A),
                      description: 'Two people, different languages',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ConversationScreen()),
                      ),
                    ),
                  ],
                ),
              ),
              // Speed indicator
              _SpeedIndicator(appState: appState),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageBar extends StatelessWidget {
  final AppState appState;

  const _LanguageBar({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _LangButton(
              label: 'My Language',
              langCode: appState.userNativeLang,
              onTap: () async {
                final selected = await showLanguagePicker(context, appState.userNativeLang);
                if (selected != null) appState.setUserNativeLang(selected);
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.swap_horiz, size: 28, color: Color(0xFF1565C0)),
          ),
          Expanded(
            child: _LangButton(
              label: 'Target Language',
              langCode: appState.targetLang,
              onTap: () async {
                final selected = await showLanguagePicker(context, appState.targetLang);
                if (selected != null) appState.setTargetLang(selected);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final String langCode;
  final VoidCallback onTap;

  const _LangButton({
    required this.label,
    required this.langCode,
    required this.onTap,
  });

  static const _langEmojis = {
    'te': '🇮🇳', 'hi': '🇮🇳', 'ta': '🇮🇳', 'en': '🇬🇧',
    'kn': '🇮🇳', 'ml': '🇮🇳', 'bn': '🇮🇳', 'mr': '🇮🇳',
    'gu': '🇮🇳', 'pa': '🇮🇳',
  };

  static const _langNames = {
    'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil', 'en': 'English',
    'kn': 'Kannada', 'ml': 'Malayalam', 'bn': 'Bengali', 'mr': 'Marathi',
    'gu': 'Gujarati', 'pa': 'Punjabi',
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              '${_langEmojis[langCode] ?? '🌐'} ${_langNames[langCode] ?? langCode.toUpperCase()}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1565C0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final String description;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showTutorial(context),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTutorial(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$icon $label'),
        content: Text(description, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

class _SpeedIndicator extends StatelessWidget {
  final AppState appState;

  const _SpeedIndicator({required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Speech Speed: ', style: TextStyle(fontSize: 15)),
          GestureDetector(
            onTap: () {
              final speeds = ['normal', 'slow', 'very_slow'];
              final idx = speeds.indexOf(appState.ttsSpeed);
              appState.setTtsSpeed(speeds[(idx + 1) % speeds.length]);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    appState.ttsSpeed == 'very_slow'
                        ? '🐢 Very Slow'
                        : appState.ttsSpeed == 'slow'
                            ? '🚶 Slow'
                            : '🏃 Normal',
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
