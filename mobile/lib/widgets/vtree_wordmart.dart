import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class VTreeWordmark extends StatelessWidget {
  final double fontSize;
  const VTreeWordmark({super.key, this.fontSize = 40});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'V-Tree',
          style: TextStyle(
            fontFamily: 'CormorantGaramond',
            fontWeight: FontWeight.w300,
            fontSize: fontSize,
            color: AppColors.primary,
          ),
        ),
        Positioned(
          right: -fontSize * 0.12,
          top: -fontSize * 0.18,
          child: Image.asset(
            isDark
                ? 'assets/images/vtree_leaf_white.png'
                : 'assets/images/vtree_leaf_primary.png',
            height: fontSize * 0.32,
          ),
        ),
      ],
    );
  }
}
