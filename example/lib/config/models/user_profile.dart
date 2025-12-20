import 'package:flutter/material.dart';

/// Enum para representar el género del usuario
enum UserGender {
  male,
  female,
  nonBinary,
  preferNotToSay;

  /// Obtener la descripción en español (deprecated - usar displayName con contexto)
  @deprecated
  String get displayNameEs {
    switch (this) {
      case UserGender.male:
        return 'Masculino';
      case UserGender.female:
        return 'Femenino';
      case UserGender.nonBinary:
        return 'No binario';
      case UserGender.preferNotToSay:
        return 'Prefiero no decir';
    }
  }

  /// Obtener el nombre localizado
  String displayName(BuildContext context) {
    // Detectar idioma actual
    final isEs = Localizations.localeOf(context).languageCode == 'es';

    switch (this) {
      case UserGender.male:
        return isEs ? 'Masculino' : 'Male';
      case UserGender.female:
        return isEs ? 'Femenino' : 'Female';
      case UserGender.nonBinary:
        return isEs ? 'No binario' : 'Non-binary';
      case UserGender.preferNotToSay:
        return isEs ? 'Prefiero no decir' : 'Prefer not to say';
    }
  }

  /// Obtener el término para usar en prompts de IA (en inglés)
  String get promptTerm {
    switch (this) {
      case UserGender.male:
        return 'a man';
      case UserGender.female:
        return 'a woman';
      case UserGender.nonBinary:
        return 'a person';
      case UserGender.preferNotToSay:
        return 'a person';
    }
  }
}

/// Modelo de perfil de usuario
class UserProfile {
  final String? name;
  final UserGender gender;
  final int? age;

  UserProfile({this.name, required this.gender, this.age});

  /// Constructor desde JSON
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] as String?,
      gender: UserGender.values.firstWhere(
        (e) => e.name == json['gender'],
        orElse: () => UserGender.preferNotToSay,
      ),
      age: json['age'] as int?,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {'name': name, 'gender': gender.name, 'age': age};
  }

  /// Crear copia con modificaciones
  UserProfile copyWith({String? name, UserGender? gender, int? age}) {
    return UserProfile(
      name: name ?? this.name,
      gender: gender ?? this.gender,
      age: age ?? this.age,
    );
  }

  /// Perfil por defecto
  static UserProfile get defaultProfile =>
      UserProfile(gender: UserGender.preferNotToSay);
}
