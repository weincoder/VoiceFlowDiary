import 'package:flutter/material.dart';
import 'package:example/config/models/user_profile.dart';

class AppState with ChangeNotifier {
  double fontSizeFactor = 1;
  String fontFamily = 'Georgia';
  Color appColor = Colors.yellow;
  ThemeData appTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.black12),
  );
  UserProfile userProfile = UserProfile.defaultProfile;
  Locale locale = const Locale('es'); // Idioma por defecto: español

  AppState();

  // Configure the font size factor
  double setFontSizeFactor(double newValue) {
    fontSizeFactor = newValue;
    notifyListeners();

    return fontSizeFactor;
  }

  // Increase font size factor
  void increaseFontSizeFactor() {
    fontSizeFactor += .05;
    notifyListeners();
  }

  // Change font family
  String setFontFamily(String newFontFamily) {
    fontFamily = newFontFamily;
    notifyListeners();
    return fontFamily;
  }

  // Change app theme color
  Color setAppColor(Color newColor) {
    appColor = newColor;
    appTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appColor,
        brightness: Brightness.light,
      ),
    );
    notifyListeners();

    return appColor;
  }

  // Update user profile
  void setUserProfile(UserProfile profile) {
    userProfile = profile;
    notifyListeners();
  }

  // Update user gender
  void setUserGender(UserGender gender) {
    userProfile = userProfile.copyWith(gender: gender);
    notifyListeners();
  }

  // Change app locale
  void setLocale(Locale newLocale) {
    locale = newLocale;
    notifyListeners();
  }
}
