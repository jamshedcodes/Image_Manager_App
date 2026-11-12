import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primaryGreen = Color(0xFF189E18);
  static const Color background = Colors.white;
  static const Color bottomNavBackground = Color(0xFFEDEDED);
  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF555555);
  static const Color hintText = Color(0xFFBDBDBD);
  static const Color divider = Color(0xFFDADADA);
  static const Color inputBorder = Color(0xFF4A4A4A);
  static const Color removeRed = Color(0xFFEF4444);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryGreen,
      primary: AppColors.primaryGreen,
      surface: AppColors.background,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bottomNavBackground,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.textPrimary,
      selectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      elevation: 0,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
