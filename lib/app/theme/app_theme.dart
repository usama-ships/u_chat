import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const _fontFamily = 'Manrope';

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.silver200,
      onPrimary: AppColors.graphite900,
      primaryContainer: AppColors.graphite700,
      onPrimaryContainer: AppColors.silver100,
      secondary: AppColors.bronze400,
      onSecondary: AppColors.graphite950,
      secondaryContainer: AppColors.graphite700,
      onSecondaryContainer: AppColors.silver100,
      surface: AppColors.graphite900,
      onSurface: AppColors.silver100,
      onSurfaceVariant: AppColors.silver300,
      surfaceContainerHigh: AppColors.graphite800,
      surfaceContainerHighest: AppColors.graphite700,
      outline: AppColors.silver500,
      outlineVariant: AppColors.graphite600,
      error: AppColors.clay,
      onError: AppColors.graphite950,
    );

    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: _fontFamily,
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.graphite950,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: base.textTheme.copyWith(
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.4),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
        bodySmall: base.textTheme.bodySmall?.copyWith(
          height: 1.4,
          color: AppColors.silver300,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelMedium: base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        labelSmall: base.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 10),
        hintStyle: TextStyle(color: AppColors.silver400),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.bronze400,
        selectionColor: AppColors.bronze400.withValues(alpha: 0.35),
        selectionHandleColor: AppColors.bronze400,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.graphite950
              : AppColors.silver400,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.bronze400
              : Colors.white.withValues(alpha: 0.08),
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : Colors.white.withValues(alpha: 0.18),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.silver300),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.07),
        thickness: 1,
        space: 1,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.graphite800,
        surfaceTintColor: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.graphite700,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: AppColors.silver100, fontFamily: _fontFamily),
      ),
    );
  }
}
