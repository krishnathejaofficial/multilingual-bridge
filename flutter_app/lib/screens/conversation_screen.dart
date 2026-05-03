import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/loading_overlay.dart';

class ConversationMessage {
  final int speakerId;
  final String originalText;
  final String translatedText;
  final String speakerLang;

  ConversationMessage({
    required this.speakerId,
    required this.originalText,
    required this.translatedText,
    required this.speakerLang,
  });
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final List<ConversationMessage> _messages = [];
  int _activeSpeaker = 0; // 0 = none, 1 or 2
  bool _isLoading = false;

  String _speaker1Lang = 'hi';
  String _speaker2Lang = 'en';

  static const _langNames = {
    'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil', 'en': 'English',
    'kn': 'Kannada', 'ml': 'Malayalam', 'bn': 'Bengali', 'mr': 'Marathi',
    'gu': 'Gujarati', 'pa': 'Punjabi',
  };

  Future<void> _handleSpeakerTap(int speakerId) async {
    if (_isLoading) return;

    final audio = Provider.of<AudioService>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    final speakerLang = speakerId == 1 ? _speaker1Lang : _speaker2Lang;
    final listenerLang = speakerId == 1 ? _speaker2Lang : _speaker1Lang;

    // Start recording
    setState(() => _activeSpeaker = speakerId);
    HapticFeedback.heavyImpact();
    await audio.startRecording();

    // Show dialog to stop
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('🎤 Speaker ${speakerId} Speaking...'),
        content: const Text(
          'Speak now. Tap DONE when finished.',
          style: TextStyle(fontSize: 18),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(double.infinity, 50),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('✅ DONE', style: TextStyle(fontSize: 20, color: Colors.white)),
          ),
        ],
      ),
    );

    // Stop recording
    final bytes = await audio.stopRecording();
    setState(() {
      _activeSpeaker = 0;
      _isLoading = true;
    });

    try {
      final result = await api.conversationTurn(
        speakerId: speakerId,
        speakerLang: speakerLang,
        listenerLang: listenerLang,
        speed: appState.ttsSpeed,
        audioBytes: bytes,
      );

      final msg = ConversationMessage(
        speakerId: speakerId,
        originalText: result['original_text'] ?? '',
        translatedText: result['translated_text'] ?? '',
        speakerLang: speakerLang,
      );

      setState(() {
        _messages.insert(0, msg);
        _isLoading = false;
      });

      // Play translation
      final audioB64 = result['tts_audio_base64'];
      if (audioB64 != null) {
        final audioBytes = base64.decode(audioB64);
        await Provider.of<AudioService>(context, listen: false).playBytes(audioBytes);
      }

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        title: const Text('👥 Two-Person Talk',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            // Speaker buttons
            Row(
              children: [
                Expanded(child: _SpeakerButton(
                  id: 1,
                  lang: _speaker1Lang,
                  langName: _langNames[_speaker1Lang] ?? _speaker1Lang,
                  color: const Color(0xFF1565C0),
                  isActive: _activeSpeaker == 1,
                  onTap: () => _handleSpeakerTap(1),
                  onLangChange: (lang) => setState(() => _speaker1Lang = lang),
                )),
                Expanded(child: _SpeakerButton(
                  id: 2,
                  lang: _speaker2Lang,
                  langName: _langNames[_speaker2Lang] ?? _speaker2Lang,
                  color: const Color(0xFF2E7D32),
                  isActive: _activeSpeaker == 2,
                  onTap: () => _handleSpeakerTap(2),
                  onLangChange: (lang) => setState(() => _speaker2Lang = lang),
                )),
              ],
            ),

            // Conversation history
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Tap a speaker button to start',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      reverse: false,
                      itemCount: _messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = _messages[i];
                        return _MessageBubble(
                          message: msg,
                          color: msg.speakerId == 1
                              ? const Color(0xFF1565C0)
                              : const Color(0xFF2E7D32),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeakerButton extends StatelessWidget {
  final int id;
  final String lang;
  final String langName;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;
  final Function(String) onLangChange;

  const _SpeakerButton({
    required this.id,
    required this.lang,
    required this.langName,
    required this.color,
    required this.isActive,
    required this.onTap,
    required this.onLangChange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 140,
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.9) : color,
          border: isActive
              ? Border.all(color: Colors.white, width: 3)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(isActive ? '🔴' : '🎤',
                style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 4),
            Text(
              'Person $id',
              style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                // Simple language selector
                final langs = {
                  'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil', 'en': 'English',
                  'kn': 'Kannada', 'ml': 'Malayalam'
                };
                final selected = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    title: Text('Select language for Person $id'),
                    children: langs.entries.map((e) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, e.key),
                      child: Text(e.value, style: const TextStyle(fontSize: 18)),
                    )).toList(),
                  ),
                );
                if (selected != null) onLangChange(selected);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🌐 $langName',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ConversationMessage message;
  final Color color;

  const _MessageBubble({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    final isLeft = message.speakerId == 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft)
            CircleAvatar(
              backgroundColor: color,
              child: Text('${message.speakerId}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.originalText,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(height: 8),
                  Text(message.translatedText,
                      style: TextStyle(fontSize: 15, color: color.withOpacity(0.8))),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!isLeft)
            CircleAvatar(
              backgroundColor: color,
              child: Text('${message.speakerId}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
