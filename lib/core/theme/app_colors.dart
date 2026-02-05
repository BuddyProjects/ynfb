import 'package:flutter/material.dart';

/// YNFB Color Palette
/// Cozy, warm, inviting - like a bookstore
class AppColors {
  // Primary backgrounds
  static const Color cream = Color(0xFFFAF7F2);
  static const Color beige = Color(0xFFF5EFE6);
  static const Color warmWhite = Color(0xFFFFFBF5);
  
  // Accent colors
  static const Color burntOrange = Color(0xFFD4763C);
  static const Color burntOrangeLight = Color(0xFFE89B67);
  static const Color forestGreen = Color(0xFF2D5A3D);
  static const Color forestGreenLight = Color(0xFF4A8B5C);
  
  // Text colors
  static const Color textDark = Color(0xFF2C2420);
  static const Color textMedium = Color(0xFF5C524A);
  static const Color textLight = Color(0xFF8B8179);
  
  // UI elements
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE8E0D5);
  static const Color shadow = Color(0x1A2C2420);
  
  // Status colors
  static const Color success = Color(0xFF4A8B5C);
  static const Color warning = Color(0xFFE89B67);
  static const Color error = Color(0xFFB84A3C);
  
  // Rating stars
  static const Color starFilled = Color(0xFFD4763C);
  static const Color starEmpty = Color(0xFFE8E0D5);
  
  // Gradients
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [warmWhite, cream],
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cardBackground, beige],
  );
}
