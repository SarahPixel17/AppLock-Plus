import 'package:flutter/material.dart';

class ThemedImageButton extends StatelessWidget {
  final String label;
  final double fontSize; // e.g. 40 on main, 48 on auth as per PDF
  final VoidCallback onTap;

  const ThemedImageButton({
    super.key,
    required this.label,
    required this.onTap,
    this.fontSize = 36,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/ui/button.png', // replace with your button png
            height: 70,                // bigger button
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),

          Text(
            label,
            style: TextStyle(
              fontFamily: 'Lancelot',
              fontSize: fontSize,
              color: const Color(0xFF553F2B), // #553f2b
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
