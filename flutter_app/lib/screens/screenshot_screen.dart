import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import '../main.dart';
import '../services/api_service.dart';
import '../services/audio_service.dart';
import '../widgets/loading_overlay.dart';

class ScreenshotScreen extends StatefulWidget {
  const ScreenshotScreen({super.key});

  @override
  State<ScreenshotScreen> createState() => _ScreenshotScreenState();
}

class _ScreenshotScreenState extends State<ScreenshotScreen> {
  File? _selectedImage;
  String _extractedText = '';
  String _answer = '';
  bool _isLoading = false;
  final _questionController = TextEditingController();

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _selectedImage = File(picked.path);
      _extractedText = '';
      _answer = '';
    });

    await _processImage();
  }

  Future<void> _processImage({String? question}) async {
    if (_selectedImage == null) return;
    final appState = Provider.of<AppState>(context, listen: false);
    final api = Provider.of<ApiService>(context, listen: false);

    setState(() => _isLoading = true);

    try {
      final imageBytes = await _selectedImage!.readAsBytes();
      final result = await api.processScreenshot(
        imageBytes: imageBytes,
        userNativeLang: appState.userNativeLang,
        question: question,
        speed: appState.ttsSpeed,
      );

      setState(() {
        _extractedText = result['extracted_text'] ?? '';
        _answer = result['answer'] ?? '';
        _isLoading = false;
      });

      // Play audio if available
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
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2E7D32),
        title: const Text('📷 Screenshot Reader',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Image picker buttons
                Row(
                  children: [
                    Expanded(
                      child: _PickButton(
                        icon: '📷',
                        label: 'Take Photo',
                        color: const Color(0xFF2E7D32),
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickButton(
                        icon: '🖼️',
                        label: 'From Gallery',
                        color: const Color(0xFF1565C0),
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Preview
                if (_selectedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _selectedImage!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 16),

                // Results
                if (_extractedText.isNotEmpty)
                  _ResultSection(
                    icon: '📝',
                    label: 'Text Found',
                    content: _extractedText,
                    color: const Color(0xFFE3F2FD),
                  ),

                if (_answer.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ResultSection(
                    icon: '💡',
                    label: 'Translated / Explained',
                    content: _answer,
                    color: const Color(0xFFE8F5E9),
                  ),
                ],

                if (_selectedImage != null) ...[
                  const SizedBox(height: 16),
                  // Ask a question
                  TextField(
                    controller: _questionController,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      hintText: 'Ask a question about this image...',
                      hintStyle: const TextStyle(fontSize: 16),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, size: 28),
                        onPressed: () {
                          if (_questionController.text.isNotEmpty) {
                            _processImage(question: _questionController.text);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 36)),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  final String icon, label, content;
  final Color color;

  const _ResultSection({
    required this.icon, required this.label,
    required this.content, required this.color,
  });

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
          Text('$icon $label',
              style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 18, height: 1.4)),
        ],
      ),
    );
  }
}
