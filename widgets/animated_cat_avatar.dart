// lib/widgets/animated_cat_avatar.dart
import 'package:flutter/material.dart';
import 'package:applockplus/profile/avatar_provider.dart';

/// Stateless widget that chooses the correct avatar image file
/// based on the provided character name and expression.
/// Use AnimatedCatAvatar(character: provider.character, expression: provider.expression, size: ...)
class AnimatedCatAvatar extends StatelessWidget {
  final String character;
  final CatExpression expression;
  final double size;

  const AnimatedCatAvatar({
    super.key,
    required this.character,
    required this.expression,
    this.size = 140,
  });

  String _assetForExpression(String character, CatExpression exp) {
    final base = 'assets/avatars/$character';
    switch (exp) {
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

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetForExpression(character, expression),
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
