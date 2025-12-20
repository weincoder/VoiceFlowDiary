import 'package:example/config/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Widget para seleccionar el idioma de la aplicación
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentLocale = appState.locale;

    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: currentLocale.languageCode == 'es' ? 'Idioma' : 'Language',
      onSelected: (Locale locale) {
        appState.setLocale(locale);
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<Locale>>[
        PopupMenuItem<Locale>(
          value: const Locale('es'),
          child: Row(
            children: [
              Text('🇪🇸', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text('Español'),
              if (currentLocale.languageCode == 'es')
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20),
                ),
            ],
          ),
        ),
        PopupMenuItem<Locale>(
          value: const Locale('en'),
          child: Row(
            children: [
              Text('🇺🇸', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              const Text('English'),
              if (currentLocale.languageCode == 'en')
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.check, size: 20),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
