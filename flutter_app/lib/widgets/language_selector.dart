import 'package:flutter/material.dart';

const _languages = [
  {'code': 'te', 'name': 'Telugu', 'flag': '🇮🇳'},
  {'code': 'hi', 'name': 'Hindi', 'flag': '🇮🇳'},
  {'code': 'ta', 'name': 'Tamil', 'flag': '🇮🇳'},
  {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
  {'code': 'kn', 'name': 'Kannada', 'flag': '🇮🇳'},
  {'code': 'ml', 'name': 'Malayalam', 'flag': '🇮🇳'},
  {'code': 'bn', 'name': 'Bengali', 'flag': '🇮🇳'},
  {'code': 'mr', 'name': 'Marathi', 'flag': '🇮🇳'},
  {'code': 'gu', 'name': 'Gujarati', 'flag': '🇮🇳'},
  {'code': 'pa', 'name': 'Punjabi', 'flag': '🇮🇳'},
];

Future<String?> showLanguagePicker(BuildContext context, String currentCode) {
  return showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Select Language',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _languages.length,
            itemBuilder: (ctx, i) {
              final lang = _languages[i];
              final isSelected = lang['code'] == currentCode;
              return ListTile(
                leading: Text(
                  lang['flag']!,
                  style: const TextStyle(fontSize: 28),
                ),
                title: Text(
                  lang['name']!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? const Color(0xFF1565C0) : null,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle,
                        color: Color(0xFF1565C0), size: 28)
                    : null,
                onTap: () => Navigator.pop(ctx, lang['code']),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    ),
  );
}
