import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_theme_extension.dart';

/// Tema institucional aplicado ao app inteiro com tokens reutilizáveis.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );
    final backgroundColor =
        isDark ? const Color(0xFF0F1423) : AppColors.background;
    final colorScheme = baseScheme.copyWith(
      primary: AppColors.primary,
      primaryContainer: isDark ? const Color(0xFF1B2438) : AppColors.surfaceAlt,
      secondary: AppColors.highlight,
      secondaryContainer:
          isDark ? const Color(0xFF222C44) : AppColors.surfaceAlt,
      tertiary: AppColors.support,
      error: AppColors.alert,
      surface: isDark ? const Color(0xFF161E31) : AppColors.surface,
      onPrimary: Colors.white,
      onSecondary: AppColors.textPrimary,
      onSurface: isDark ? Colors.white : AppColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
    );

    final montserrat = GoogleFonts.montserratTextTheme(base.textTheme);
    final textTheme = montserrat
        .copyWith(
          displayLarge: montserrat.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            height: 1.1,
          ),
          displayMedium: montserrat.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.1,
          ),
          headlineLarge: montserrat.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          headlineMedium: montserrat.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          headlineSmall: montserrat.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: montserrat.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: montserrat.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          titleSmall: montserrat.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          bodyLarge: montserrat.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          bodyMedium: montserrat.bodyMedium?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          bodySmall: montserrat.bodySmall?.copyWith(
            fontWeight: FontWeight.w400,
            height: 1.45,
          ),
          labelLarge: montserrat.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelMedium: montserrat.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          labelSmall: montserrat.labelSmall?.copyWith(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        )
        .apply(
          bodyColor: isDark ? Colors.white : AppColors.textPrimary,
          displayColor: isDark ? Colors.white : AppColors.textPrimary,
        );

    final decorations = isDark ? AppDecorations.dark : AppDecorations.light;
    final surfaceAlt = isDark ? const Color(0xFF222C44) : AppColors.surfaceAlt;

    return base.copyWith(
      colorScheme: colorScheme,
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        decorations,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      iconTheme: base.iconTheme.copyWith(
        color: colorScheme.onSurface,
      ),
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : AppColors.border,
        thickness: 1,
        space: 32,
      ),
      cardTheme: base.cardTheme.copyWith(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: decorations.cardRadius,
          side: BorderSide(
            color: isDark ? Colors.white10 : AppColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        surfaceTintColor: Colors.transparent,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaceAlt,
        selectedColor: AppColors.primary,
        secondarySelectedColor: AppColors.highlight,
        disabledColor: AppColors.border,
        labelStyle: textTheme.labelMedium,
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: decorations.tileRadius,
          side: BorderSide(
            color: isDark ? Colors.white12 : AppColors.border,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.border;
          }
          return surfaceAlt;
        }),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.textSecondary;
        }),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withOpacity(0.4);
          }
          return AppColors.border;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.surface;
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: decorations.tileRadius,
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: decorations.tileRadius,
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: decorations.tileRadius,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: decorations.tileRadius,
          borderSide: const BorderSide(color: AppColors.alert, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: decorations.tileRadius,
          borderSide: const BorderSide(color: AppColors.alert, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white38 : AppColors.textSecondary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.highlight,
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 48),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
          textStyle: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: decorations.tileRadius),
          ),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const BorderSide(color: AppColors.primary, width: 1.2);
            }
            return BorderSide(color: AppColors.border.withOpacity(0.9));
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primary.withOpacity(0.12);
            }
            return surfaceAlt;
          }),
          foregroundColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        tileColor: colorScheme.surface,
        selectedTileColor: AppColors.primary.withOpacity(0.12),
        iconColor: isDark ? Colors.white70 : AppColors.textSecondary,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: surfaceAlt,
        linearTrackColor: surfaceAlt,
        linearMinHeight: 6,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        actionTextColor: AppColors.highlight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: decorations.tileRadius),
      ),
      bottomNavigationBarTheme: base.bottomNavigationBarTheme.copyWith(
        backgroundColor: isDark ? const Color(0xFF161E31) : Colors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: isDark ? Colors.white70 : AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        elevation: 0,
        selectedLabelStyle:
            textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w500),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF161E31) : Colors.white,
        indicatorColor: AppColors.primary.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primary);
          }
          return IconThemeData(
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            );
          }
          return textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          );
        }),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: decorations.sheetRadius),
        showDragHandle: true,
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: decorations.sheetRadius),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: base.inputDecorationTheme,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll<Color>(colorScheme.surface),
          elevation: const WidgetStatePropertyAll<double>(12),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(borderRadius: decorations.tileRadius),
          ),
          shadowColor: const WidgetStatePropertyAll<Color>(AppColors.shadow),
        ),
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppColors.primary,
        unselectedLabelColor: isDark ? Colors.white70 : AppColors.textSecondary,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
        indicator: BoxDecoration(
          borderRadius: decorations.tileRadius,
          color: AppColors.primary.withOpacity(0.12),
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(48),
        thickness: const WidgetStatePropertyAll<double>(6),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return AppColors.primary;
          }
          return AppColors.primary.withOpacity(0.6);
        }),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B2438) : AppColors.textPrimary,
          borderRadius: decorations.tileRadius,
        ),
        textStyle: textTheme.labelSmall?.copyWith(color: Colors.white),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withOpacity(0.24),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}
