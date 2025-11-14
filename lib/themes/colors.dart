import 'package:flutter/material.dart';

// Youthful, vibrant color scheme with teal as base
class AppColors {
  // Primary colors - keeping teal but making it more vibrant
  static const Color primary = Color(0xFF00BFA5); // Vibrant teal
  static const Color primaryDark = Color(0xFF00897B); // Darker teal
  static const Color primaryLight = Color(0xFF4DD0E1); // Light teal
  
  // Accent colors for youthful vibe
  static const Color accent = Color(0xFFFF6B9D); // Pink accent
  static const Color accent2 = Color(0xFFFFC107); // Amber
  static const Color accent3 = Color(0xFF9C27B0); // Purple
  
  // Background colors
  static const Color background = Color(0xFFF5F7FA); // Light gray-blue
  static const Color surface = Colors.white;
  static const Color cardBackground = Color(0xFFFFFFFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textLight = Color(0xFF9CA3AF);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, accent3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// Legacy support
var PrimaryColor = AppColors.primaryDark;
