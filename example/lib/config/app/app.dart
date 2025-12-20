import 'package:example/config/state/app_state.dart';
import 'package:example/l10n/app_localizations.dart';
import 'package:example/ui/pages/diary_home_page.dart';
import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          return BetterFeedback(
            theme: FeedbackThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: appState.appTheme.colorScheme.primary,
              ),
            ),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: appState.appTheme,
              locale: appState.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('en'), // English
                Locale('es'), // Spanish
              ],
              home: const DiaryHomePage(),
            ),
          );
        },
      ),
    );
  }
}
