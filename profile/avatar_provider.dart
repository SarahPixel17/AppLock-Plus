// lib/profile/avatar_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Expressions used by all avatars
enum CatExpression { neutral, happy, sad, curious, sleeping }

class AvatarProvider extends ChangeNotifier {
  static const _keyCharacter = 'selected_avatar_character';
  static const _keyExpression = 'selected_avatar_expression';

  // Default character (must match the filenames in assets/avatars/)
  String _character = 'defaultcat';
  CatExpression _expression = CatExpression.neutral;

  String get character => _character;
  CatExpression get expression => _expression;

  /// Loads saved character & expression from SharedPreferences
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _character = prefs.getString(_keyCharacter) ?? _character;
    final expIndex = prefs.getInt(_keyExpression);
    if (expIndex != null &&
        expIndex >= 0 &&
        expIndex < CatExpression.values.length) {
      _expression = CatExpression.values[expIndex];
    }
    notifyListeners();
  }

  /// Sets and persists chosen character (e.g. 'fox', 'dog', 'defaultcat', ...)
  Future<void> setCharacter(String character) async {
    _character = character;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCharacter, _character);
    notifyListeners();
  }

  /// Sets and persists current expression
  Future<void> setExpression(CatExpression expression) async {
    _expression = expression;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyExpression, expression.index);
    notifyListeners();
  }

  /// Returns appropriate asset path for the selected avatar & expression.
  /// NOTE: This assumes your files are named like:
  ///   defaultcat.png
  ///   defaultcathappy.png
  ///   defaultcatsad.png
  ///   defaultcatcurios.png
  ///   defaultcatsleep.png
  ///
  /// and similarly for other characters (e.g. fox.png, foxhappy.png, foxsad.png, foxcurios.png, foxsleep.png)
  String get currentAsset {
    final base = 'assets/avatars/$_character';
    switch (_expression) {
      case CatExpression.happy:
        return '${base}happy.png';
      case CatExpression.sad:
        return '${base}sad.png';
      case CatExpression.curious:
        return '${base}curios.png';
      case CatExpression.sleeping:
        return '${base}sleep.png';
      case CatExpression.neutral:
      default:
        return '$base.png';
    }
  }
}
