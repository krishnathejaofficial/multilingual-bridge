import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'preferences_service.dart';

class ApiService {
  String get baseUrl {
    return PreferencesService.getString('api_base_url') ?? 'http://10.0.2.2:8000';
  }

  // ── Helper ────────────────────────────────────────────────────────────────

  Map<String, String> get _headers => {'Accept': 'application/json'};

  // ── TTS ────────────────────────────────────────────────────────────────────

  Future<Uint8List?> getTTS({
    required String text,
    required String langCode,
    required String speed,
  }) async {
    try {
      final req = http.MultipartRequest(
        'POST', Uri.parse('$baseUrl/api/paste-reply/tts'),
      )
        ..fields['text'] = text
        ..fields['language_code'] = langCode
        ..fields['speed'] = speed;

      final streamed = await req.send();
      if (streamed.statusCode == 200) {
        return Uint8List.fromList(await streamed.stream.toBytes());
      }
    } catch (e) {
      print('TTS error: $e');
    }
    return null;
  }

  // ── Paste & Reply ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> explainPastedMessage({
    required String pastedText,
    required String userNativeLang,
    required String speed,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/paste-reply/explain'),
      headers: {..._headers, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'pasted_text': pastedText,
        'user_native_lang': userNativeLang,
        'speed': speed,
      }),
    ).timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Explain API failed: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, dynamic>> generateReply({
    required String pastedTextContext,
    required String userNativeLang,
    required String recipientLang,
    required String speed,
    List<int>? audioBytes,
    String? replyText,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/api/paste-reply/reply'),
    )
      ..fields['pasted_text_context'] = pastedTextContext
      ..fields['user_native_lang'] = userNativeLang
      ..fields['recipient_lang'] = recipientLang
      ..fields['speed'] = speed;

    if (audioBytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'user_reply_audio',
        audioBytes,
        filename: 'reply.wav',
      ));
    }
    if (replyText != null) {
      req.fields['user_reply_text'] = replyText;
    }

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) {
      return jsonDecode(body);
    }
    throw Exception('Reply API failed: ${streamed.statusCode} $body');
  }

  // ── Voice Query ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> voiceQuery({
    required List<int> audioBytes,
    required String sourceLang,
    required String targetLang,
    required String speed,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/api/voice/query'),
    )
      ..fields['source_lang'] = sourceLang
      ..fields['target_lang'] = targetLang
      ..fields['speed'] = speed
      ..files.add(http.MultipartFile.fromBytes(
        'audio', audioBytes, filename: 'query.wav',
      ));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) return jsonDecode(body);
    throw Exception('Voice query failed: ${streamed.statusCode}');
  }

  // ── Screenshot ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> processScreenshot({
    required List<int> imageBytes,
    required String userNativeLang,
    String? question,
    String? speed,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/api/image/screenshot'),
    )
      ..fields['user_native_lang'] = userNativeLang
      ..fields['speed'] = speed ?? 'slow'
      ..files.add(http.MultipartFile.fromBytes(
        'image', imageBytes, filename: 'screenshot.jpg',
      ));

    if (question != null) req.fields['question'] = question;

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) return jsonDecode(body);
    throw Exception('Screenshot API failed: ${streamed.statusCode}');
  }

  // ── Conversation ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> conversationTurn({
    required int speakerId,
    required String speakerLang,
    required String listenerLang,
    required String speed,
    List<int>? audioBytes,
    String? text,
  }) async {
    final req = http.MultipartRequest(
      'POST', Uri.parse('$baseUrl/api/conversation/turn'),
    )
      ..fields['speaker_id'] = speakerId.toString()
      ..fields['speaker_lang'] = speakerLang
      ..fields['listener_lang'] = listenerLang
      ..fields['speed'] = speed;

    if (audioBytes != null) {
      req.files.add(http.MultipartFile.fromBytes(
        'audio', audioBytes, filename: 'turn.wav',
      ));
    }
    if (text != null) req.fields['text'] = text;

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode == 200) return jsonDecode(body);
    throw Exception('Conversation turn failed: ${streamed.statusCode}');
  }
}
