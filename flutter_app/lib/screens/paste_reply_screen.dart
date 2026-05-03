import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/record_button.dart';

enum PasteReplyStep { paste, understand, reply, done }

class PasteReplyScreen extends StatefulWidget {
  const PasteReplyScreen({super.key});

  @override
  State<PasteReplyScreen> createState() => _PasteReplyScreenState();
}

class _PasteReplyScreenState extends State<PasteReplyScreen>
    with TickerProviderStateMixin {
  PasteReplyStep _step = PasteReplyStep.paste;

  String _pastedText = '';
  String _normalizedText = '';
  String _detectedLangName = '';
  String _explanationText = '';
  String _sentimentText = '';
  String _translatedReply = '';
  String _userReplyText = '';

  bool _isLoading = false;
  bool _isRecording = false;
  String _errorMessage = '';

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _speakInstruction('Paste the message you received. Tap the Paste button.');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _speakInstruction(String text) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);
    try {
      final audioBytes = await api.getTTS(
        text: text,
        langCode: appState.userNativeLang,
        speed: appState.ttsSpeed,
      );
      if (audioBytes != null) {
        await Provider.of<AudioService>(context, listen: false)
            .playBytes(audioBytes);
      }
    } catch (_) {}
  }

  Future<void> _pasteText() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) {
      _showError('Nothing in clipboard! Copy a message first.');
      return;
    }
    setState(() {
      _pastedText = data.text!;
      _step = PasteReplyStep.understand;
      _errorMessage = '';
    });
    HapticFeedback.mediumImpact();
    await _explainMessage();
  }

  Future<void> _explainMessage() async {
    final appState = Provider.of<AppState>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final result = await api.explainPastedMessage(
        pastedText: _pastedText,
        userNativeLang: appState.userNativeLang,
        speed: appState.ttsSpeed,
      );

      setState(() {
        _detectedLangName = result['detected_source_lang_name'] ?? '';
        _explanationText = result['explanation_in_user_lang'] ?? '';
        _sentimentText = result['sentiment'] ?? '';
        _normalizedText = result['normalized_text'] ?? _pastedText;
        _isLoading = false;
      });

      // Play audio
      final audioB64 = result['tts_audio_base64'];
      if (audioB64 != null) {
        final bytes = base64.decode(audioB64);
        await Provider.of<AudioService>(context, listen: false).playBytes(bytes);
      }

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not process message. Check your connection.';
      });
    }
  }

  Future<void> _startRecording() async {
    final audio = Provider.of<AudioService>(context, listen: false);
    await audio.startRecording();
    setState(() => _isRecording = true);
    HapticFeedback.heavyImpact();
    await _speakInstruction('Recording. Speak your reply now.');
  }

  Future<void> _stopRecordingAndReply() async {
    if (!_isRecording) return;
    final audio = Provider.of<AudioService>(context, listen: false);
    final bytes = await audio.stopRecording();
    setState(() {
      _isRecording = false;
      _isLoading = true;
    });
    HapticFeedback.heavyImpact();

    await _generateReply(audioBytes: bytes);
  }

  Future<void> _generateReply({List<int>? audioBytes, String? text}) async {
    final appState = Provider.of<AppState>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    try {
      final result = await api.generateReply(
        pastedTextContext: _pastedText,
        userNativeLang: appState.userNativeLang,
        recipientLang: appState.targetLang,
        speed: appState.ttsSpeed,
        audioBytes: audioBytes,
        replyText: text,
      );

      setState(() {
        _userReplyText = result['user_reply_original'] ?? '';
        _translatedReply = result['translated_reply'] ?? '';
        _step = PasteReplyStep.done;
        _isLoading = false;
      });

      final audioB64 = result['tts_audio_base64'];
      if (audioB64 != null) {
        final bytes = base64.decode(audioB64);
        await Provider.of<AudioService>(context, listen: false).playBytes(bytes);
      }

      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Reply generation failed. Please try again.';
      });
    }
  }

  void _copyReply() {
    Clipboard.setData(ClipboardData(text: _translatedReply));
    HapticFeedback.heavyImpact();
    _speakInstruction(
        'Message copied! Now go back to your chat app and paste it.');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Copied! Now paste in your chat app.',
            style: TextStyle(fontSize: 18)),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  void _showError(String msg) {
    setState(() => _errorMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.red[700],
      ),
    );
  }

  void _reset() {
    setState(() {
      _step = PasteReplyStep.paste;
      _pastedText = '';
      _explanationText = '';
      _translatedReply = '';
      _errorMessage = '';
    });
    _speakInstruction('Paste the message you received.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        title: const Text(
          '📋 Paste & Reply',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_step != PasteReplyStep.paste)
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _reset,
              tooltip: 'Start Over',
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case PasteReplyStep.paste:
        return _buildPasteStep();
      case PasteReplyStep.understand:
        return _buildUnderstandStep();
      case PasteReplyStep.reply:
        return _buildReplyStep();
      case PasteReplyStep.done:
        return _buildDoneStep();
    }
  }

  // ── STEP 1: Paste ──────────────────────────────────────────────────────────

  Widget _buildPasteStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'STEP 1',
          style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 2),
        ),
        const SizedBox(height: 8),
        const Text(
          'Paste the message\nyou received',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 40),
        ScaleTransition(
          scale: _pulseAnimation,
          child: GestureDetector(
            onTap: _pasteText,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFFE65100),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE65100).withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📋', style: TextStyle(fontSize: 64)),
                  SizedBox(height: 8),
                  Text(
                    'PASTE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const Text(
          '← Copy a message in WhatsApp or any app,\nthen tap PASTE here',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
        if (_errorMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // ── STEP 2: Understand ────────────────────────────────────────────────────

  Widget _buildUnderstandStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STEP 2', style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 2)),
        const SizedBox(height: 6),
        const Text('Message Received', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Original message
        _InfoCard(
          label: 'Original Message ($_detectedLangName)',
          content: _pastedText,
          color: const Color(0xFFE3F2FD),
          icon: '📩',
        ),
        const SizedBox(height: 12),

        if (_explanationText.isNotEmpty) ...[
          _InfoCard(
            label: 'What it means (in your language)',
            content: _explanationText,
            color: const Color(0xFFE8F5E9),
            icon: '💬',
          ),
          const SizedBox(height: 8),
        ],

        if (_sentimentText.isNotEmpty) ...[
          _InfoCard(
            label: 'Tone / Mood',
            content: _sentimentText,
            color: const Color(0xFFFFF3E0),
            icon: '😊',
          ),
          const SizedBox(height: 16),
        ],

        // Replay button
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: '🔊',
                label: 'Hear Again',
                color: const Color(0xFF1565C0),
                onTap: _explainMessage,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: '✍️',
                label: 'Reply',
                color: const Color(0xFFE65100),
                onTap: () {
                  setState(() => _step = PasteReplyStep.reply);
                  _speakInstruction('Speak your reply now. Tap the microphone.');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── STEP 3: Reply ─────────────────────────────────────────────────────────

  Widget _buildReplyStep() {
    final appState = Provider.of<AppState>(context);

    return Column(
      children: [
        const Text('STEP 3', style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 2)),
        const SizedBox(height: 6),
        const Text('Speak Your Reply', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(
          'Speak in ${_getLangName(appState.userNativeLang)}. '
          'It will be translated to ${_getLangName(appState.targetLang)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, color: Colors.grey),
        ),
        const Spacer(),
        RecordButton(
          isRecording: _isRecording,
          onStart: _startRecording,
          onStop: _stopRecordingAndReply,
        ),
        const SizedBox(height: 24),
        const Text(
          'Hold to record,\nrelease when done',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const Spacer(),
        // Optional: type reply instead
        TextButton.icon(
          icon: const Icon(Icons.keyboard, size: 20),
          label: const Text('Type reply instead', style: TextStyle(fontSize: 15)),
          onPressed: () => _showTypeReplyDialog(),
        ),
      ],
    );
  }

  // ── STEP 4: Done ──────────────────────────────────────────────────────────

  Widget _buildDoneStep() {
    final appState = Provider.of<AppState>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('✅ READY TO SEND', style: TextStyle(fontSize: 14, color: Colors.grey, letterSpacing: 2)),
        const SizedBox(height: 6),
        const Text('Your Translated Reply', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        if (_userReplyText.isNotEmpty)
          _InfoCard(
            label: 'You said (${_getLangName(appState.userNativeLang)})',
            content: _userReplyText,
            color: const Color(0xFFE8F5E9),
            icon: '🎤',
          ),

        const SizedBox(height: 12),

        // The translated reply - LARGE and prominent
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1565C0),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1565C0).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Translated to ${_getLangName(appState.targetLang)}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                _translatedReply,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // GIANT COPY BUTTON
        GestureDetector(
          onTap: _copyReply,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2E7D32).withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📋', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Text(
                  'COPY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        const Center(
          child: Text(
            'Tap COPY → Go to WhatsApp → Long press → Paste',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ),

        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('New Message', style: TextStyle(fontSize: 16)),
            onPressed: _reset,
          ),
        ),
      ],
    );
  }

  void _showTypeReplyDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type Your Reply'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(
            hintText: 'Type your reply here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (controller.text.isNotEmpty) {
                setState(() => _isLoading = true);
                _generateReply(text: controller.text);
              }
            },
            child: const Text('Translate', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _getLangName(String code) {
    const names = {
      'te': 'Telugu', 'hi': 'Hindi', 'ta': 'Tamil', 'en': 'English',
      'kn': 'Kannada', 'ml': 'Malayalam', 'bn': 'Bengali', 'mr': 'Marathi',
      'gu': 'Gujarati', 'pa': 'Punjabi',
    };
    return names[code] ?? code.toUpperCase();
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String content;
  final Color color;
  final String icon;

  const _InfoCard({
    required this.label,
    required this.content,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$icon $label',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 18, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
