import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// YNFB Typography
/// Friendly serif for headings, clean sans-serif for body
class AppTypography {
  // Heading font - Playfair Display (friendly serif)
  static TextStyle get headingFont => GoogleFonts.playfairDisplay();
  
  // Body font - Source Sans Pro (clean, readable)
  static TextStyle get bodyFont => GoogleFonts.sourceSans3();
  
  // Display styles (largest headings)
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    letterSpacing: -0.5,
  );
  
  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textDark,
    letterSpacing: -0.25,
  );
  
  static TextStyle displaySmall = GoogleFonts.playfairDisplay(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  // Headline styles
  static TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  static TextStyle headlineMedium = GoogleFonts.playfairDisplay(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  static TextStyle headlineSmall = GoogleFonts.playfairDisplay(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
  );
  
  // Title styles
  static TextStyle titleLarge = GoogleFonts.sourceSans3(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  static TextStyle titleMedium = GoogleFonts.sourceSans3(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  static TextStyle titleSmall = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );
  
  // Body styles
  static TextStyle bodyLarge = GoogleFonts.sourceSans3(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: AppColors.textMedium,
    height: 1.5,
  );
  
  static TextStyle bodyMedium = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: AppColors.textMedium,
    height: 1.5,
  );
  
  static TextStyle bodySmall = GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: AppColors.textLight,
    height: 1.4,
  );
  
  // Label styles
  static TextStyle labelLarge = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
    letterSpacing: 0.5,
  );
  
  static TextStyle labelMedium = GoogleFonts.sourceSans3(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMedium,
    letterSpacing: 0.5,
  );
  
  static TextStyle labelSmall = GoogleFonts.sourceSans3(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textLight,
    letterSpacing: 0.5,
  );
  
  // Button text
  static TextStyle buttonLarge = GoogleFonts.sourceSans3(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
  
  static TextStyle buttonMedium = GoogleFonts.sourceSans3(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}
