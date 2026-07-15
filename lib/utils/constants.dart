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

  // Classic WhatsApp Wallpaper Pattern Painting (Fallback)
  static Widget chatWallpaper(BuildContext context, {bool isDark = false}) {
    return Container(
      color: isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
      child: Opacity(
        opacity: isDark ? 0.05 : 0.08,
        child: const Center(
          child: Icon(
            Icons.chat_bubble_outline,
            size: 200,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
