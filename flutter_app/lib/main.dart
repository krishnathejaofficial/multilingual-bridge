import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/audio_service.dart';
import 'services/preferences_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PreferencesService.init();
  runApp(const MultilingualBridgeApp());
}

class MultilingualBridgeApp extends StatelessWidget {
  const MultilingualBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
        Provider<AudioService>(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: MaterialApp(
        title: 'Multilingual Bridge',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const HomeScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(fontSize: 20),
        bodyMedium: TextStyle(fontSize: 18),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  String _userNativeLang = 'en';
  String _targetLang = 'hi';
  String _ttsSpeed = 'slow';
  bool _isProcessing = false;

  String get userNativeLang => _userNativeLang;
  String get targetLang => _targetLang;
  String get ttsSpeed => _ttsSpeed;
  bool get isProcessing => _isProcessing;

  void setUserNativeLang(String lang) {
    _userNativeLang = lang;
    PreferencesService.setString('user_native_lang', lang);
    notifyListeners();
  }

  void setTargetLang(String lang) {
    _targetLang = lang;
    PreferencesService.setString('target_lang', lang);
    notifyListeners();
  }

  void setTtsSpeed(String speed) {
    _ttsSpeed = speed;
    PreferencesService.setString('tts_speed', speed);
    notifyListeners();
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }
}
