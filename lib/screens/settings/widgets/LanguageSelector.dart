
import 'package:flutter/material.dart';

class LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final ValueChanged<String> onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: currentLanguage,
      decoration: const InputDecoration(
        labelText: 'Lingua',
        border: OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(value: 'it', child: Text('Italiano')),
        DropdownMenuItem(value: 'en', child: Text('English')),
        DropdownMenuItem(value: 'es', child: Text('Español')),
        DropdownMenuItem(value: 'fr', child: Text('Français')),
      ],
      onChanged: (value) {
        if (value != null) onLanguageChanged(value);
      },
    );
  }
}