import 'package:flutter/material.dart';

/// Paleta de marca de toda la app: fondo negro/verde oscuro, con los
/// datos y textos que deben leerse a distancia en verde claro brillante
/// (el verde oscuro de marca es demasiado oscuro para texto).
class AppColors {
  AppColors._();

  static const background = Colors.black;
  static const brandDark = Color(0xFF0D3D29);
  static const brandBright = Color(0xFF4ADE80);
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.brandBright,
    onPrimary: Colors.black,
    secondary: AppColors.brandDark,
    onSecondary: AppColors.brandBright,
    surface: AppColors.background,
    onSurface: AppColors.brandBright,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.brandBright,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 48,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.brandDark,
      height: 56,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? AppColors.brandBright
              : Colors.white38,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brandBright,
        foregroundColor: Colors.black,
      ),
    ),
  );
}
