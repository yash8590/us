import 'package:flutter/material.dart';

class WAConstants {
  static const String appName = "UsChat";
  
  // Color presets for text status uploads
  static const List<Color> statusBackgrounds = [
    Color(0xFF008069),
    Color(0xFF128C7E),
    Color(0xFF1D5A50),
    Color(0xFF9055A2),
    Color(0xFFC75B7A),
    Color(0xFF7F4F24),
    Color(0xFF3F37C9),
    Color(0xFF4361EE),
    Color(0xFFF72585),
    Color(0xFF2B2D42),
  ];

  // Custom Premium Wallpaper Gradient & Aura
  static Widget chatWallpaper(BuildContext context, {bool isDark = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0B0F19), const Color(0xFF131824)]
              : [const Color(0xFFF9FAFB), const Color(0xFFEEF2FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6366F1).withOpacity(isDark ? 0.04 : 0.03),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF43F5E).withOpacity(isDark ? 0.04 : 0.03),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
