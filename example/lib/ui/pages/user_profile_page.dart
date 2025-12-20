import 'package:example/config/models/user_profile.dart';
import 'package:example/config/state/app_state.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Página de configuración del perfil de usuario
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  UserGender? _selectedGender;

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    final profile = appState.userProfile;

    _nameController.text = profile.name ?? '';
    _ageController.text = profile.age?.toString() ?? '';
    _selectedGender = profile.gender;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _saveProfile() {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.read<AppState>();

    final profile = UserProfile(
      name: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      gender: _selectedGender ?? UserGender.preferNotToSay,
      age: int.tryParse(_ageController.text.trim()),
    );

    appState.setUserProfile(profile);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.profileSaved),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.userProfile),
        backgroundColor: colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono de perfil
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  size: 50,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Campo de nombre
            Text(
              '${l10n.name} (${l10n.optional})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: l10n.nameHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 24),

            // Selector de género
            Text(
              l10n.gender,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.genderHelp,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            ...UserGender.values.map((gender) {
              return RadioListTile<UserGender>(
                title: Text(gender.displayName(context)),
                value: gender,
                groupValue: _selectedGender,
                onChanged: (UserGender? value) {
                  setState(() {
                    _selectedGender = value;
                  });
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),

            // Campo de edad (opcional)
            Text(
              '${l10n.age} (${l10n.optional})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: l10n.ageHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.cake),
              ),
            ),
            const SizedBox(height: 32),

            // Botón de guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l10n.saveProfile,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
