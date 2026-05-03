import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _serverController.text =
        PreferencesService.getString('api_base_url') ?? 'http://10.0.2.2:8000';
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ Settings',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.grey[800],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionHeader('Speech Settings'),
          _SettingTile(
            icon: '🗣️',
            title: 'Speech Speed',
            subtitle: 'Current: ${appState.ttsSpeed}',
            onTap: () => _showSpeedPicker(appState),
          ),

          const SizedBox(height: 16),
          _SectionHeader('Server Configuration'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: TextField(
              controller: _serverController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Backend Server URL',
                hintText: 'http://10.0.2.2:8000',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.save),
                  onPressed: () {
                    PreferencesService.setString(
                        'api_base_url', _serverController.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Server URL saved')),
                    );
                  },
                ),
              ),
            ),
          ),
          const Text(
            '• For Android emulator: http://10.0.2.2:8000\n'
            '• For physical device: use your computer\'s local IP (e.g., http://192.168.1.5:8000)\n'
            '• For production: your deployed server URL',
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.6),
          ),

          const SizedBox(height: 16),
          _SectionHeader('About'),
          ListTile(
            leading: const Text('🌐', style: TextStyle(fontSize: 28)),
            title: const Text('Multilingual Bridge', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('v1.0.0 — Empowering communication for all'),
          ),
        ],
      ),
    );
  }

  void _showSpeedPicker(AppState appState) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Choose Speech Speed', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          _SpeedOption('🏃 Normal', 'normal', appState),
          _SpeedOption('🚶 Slow (Recommended)', 'slow', appState),
          _SpeedOption('🐢 Very Slow', 'very_slow', appState),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SpeedOption extends StatelessWidget {
  final String label;
  final String value;
  final AppState appState;

  const _SpeedOption(this.label, this.value, this.appState);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: appState.ttsSpeed == value
          ? const Icon(Icons.check_circle, color: Color(0xFF1565C0))
          : const Icon(Icons.radio_button_unchecked),
      title: Text(label, style: const TextStyle(fontSize: 18)),
      onTap: () {
        appState.setTtsSpeed(value);
        Navigator.pop(context);
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String icon, title, subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Text(icon, style: const TextStyle(fontSize: 28)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
