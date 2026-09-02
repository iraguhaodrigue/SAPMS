// ============================================================
// SAPMS - Locale Controller
// ============================================================
// Holds the currently selected language, persists it to
// SharedPreferences, and exposes it to the whole widget tree.
// Switching language rebuilds the entire app (see main.dart) so
// every screen re-reads its strings immediately — no restart needed.
// ============================================================

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LocaleController {
  LocaleController._internal();
  static final LocaleController instance = LocaleController._internal();

  static const _prefsKey = 'sapms_language';

  // 'en' or 'rw'. Listenable so MaterialApp rebuilds on change.
  final ValueNotifier<String> languageCode = ValueNotifier<String>('en');

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    languageCode.value = prefs.getString(_prefsKey) ?? 'en';
  }

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'rw') return;
    languageCode.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, code);
  }

  AppStrings get strings => AppStrings(languageCode.value);
}

/// Makes the current AppStrings available to any descendant via
/// context.strings — updated whenever the language changes.
class LocaleScope extends InheritedWidget {
  final String languageCode;
  const LocaleScope({
    super.key,
    required this.languageCode,
    required super.child,
  });

  static AppStrings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LocaleScope>();
    return AppStrings(scope?.languageCode ?? 'en');
  }

  @override
  bool updateShouldNotify(LocaleScope oldWidget) =>
      oldWidget.languageCode != languageCode;
}

/// Convenience: `context.tr('sign_in')` anywhere in the app.
extension LocaleContext on BuildContext {
  AppStrings get strings => LocaleScope.of(this);
  String tr(String key) => LocaleScope.of(this).t(key);
}
