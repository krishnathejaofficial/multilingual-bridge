import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/record_button.dart';
import '../widgets/loading_overlay.dart';

class VoiceQueryScreen extends StatefulWidget {
  const VoiceQueryScreen({super.key});

  @override
  State<VoiceQueryScreen> createState() => _VoiceQueryScreenState();
}

class _VoiceQueryScreenState extends State<VoiceQueryScreen> {
  bool _isRecording = false;
  bool _isLoading = false;
  String _transcript = '';
  String _translatedText = '';
  String _detectedLang = '';

  Future<void> _startRecording() async {
    final audio = Provider.of<AudioService>(context, listen: false);
    await audio.startRecording();
    setState(() {
      _isRecording = true;
      _transcript = '';
      _translatedText = '';
    });
    HapticFeedback.heavyImpact();
  }

  Future<void> _stopAndProcess() async {
    if (!_isRecording) return;
    final audio = Provider.of<AudioService>(context, listen: false);
    final bytes = await audio.stopRecording();
    setState(() {
      _isRecording = false;
      _isLoading = true;
    });
    HapticFeedback.heavyImpact();

    final appState = Provider.of<AppState>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final result = await api.voiceQuery(
        audioBytes: bytes!,
        sourceLang: appState.userNativeLang,
        targetLang: appState.targetLang,
        speed: appState.ttsSpeed,
      );

      setState(() {
        _transcript = result['transcript'] ?? '';
        _translatedText = result['translated_text'] ?? '';
        _detectedLang = result['detected_lang'] ?? '';
        _isLoading = false;
      });

      final audioB64 = result['tts_audio_base64'];
      if (audioB64 != null) {
        final bytes = base64.decode(audioB64);
        await Provider.of<AudioService>(context, listen: false).playBytes(bytes);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        title: const Text('🎤 Speak & Translate',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Text(
                  'Speak in your language.\nYour words will be translated.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.black54),
                ),
                const Spacer(),

                // Result cards
                if (_transcript.isNotEmpty) ...[
                  _ResultCard(
                    label: 'You said ($_detectedLang)',
                    text: _transcript,
                    color: const Color(0xFFE3F2FD),
                  ),
                  const SizedBox(height: 16),
                ],
                if (_translatedText.isNotEmpty) ...[
                  _ResultCard(
                    label: 'Translation',
                    text: _translatedText,
                    color: const Color(0xFFE8F5E9),
                  ),
                  const SizedBox(height: 16),
                ],

                const Spacer(),

                RecordButton(
                  isRecording: _isRecording,
                  onStart: _startRecording,
                  onStop: _stopAndProcess,
                  color: const Color(0xFF1565C0),
                ),
                const SizedBox(height: 16),
                Text(
                  _isRecording ? '🔴 Recording... Release to translate' : 'Hold to speak',
                  style: TextStyle(
                    fontSize: 16,
                    color: _isRecording ? Colors.red : Colors.grey,
                    fontWeight: _isRecording ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final String text;
  final Color color;

  const _ResultCard({required this.label, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 6),
          Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
