import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppDecorations extends ThemeExtension<AppDecorations> {
  const AppDecorations({
    required this.cardRadius,
    required this.tileRadius,
    required this.sheetRadius,
    required this.softShadow,
    required this.mediumShadow,
    required this.deepShadow,
    required this.heroGradient,
    required this.accentGradient,
    required this.backgroundGradient,
  });

  final BorderRadius cardRadius;
  final BorderRadius tileRadius;
  final BorderRadius sheetRadius;
  final List<BoxShadow> softShadow;
  final List<BoxShadow> mediumShadow;
  final List<BoxShadow> deepShadow;
  final LinearGradient heroGradient;
  final LinearGradient accentGradient;
  final LinearGradient backgroundGradient;

  static const AppDecorations light = AppDecorations(
    cardRadius: BorderRadius.all(Radius.circular(24)),
    tileRadius: BorderRadius.all(Radius.circular(20)),
    sheetRadius: BorderRadius.all(Radius.circular(28)),
    softShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 12,
        offset: Offset(0, 6),
      ),
    ],
    mediumShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
    deepShadow: [
      BoxShadow(
        color: AppColors.shadow,
        blurRadius: 24,
        offset: Offset(0, 12),
      ),
    ],
    heroGradient: LinearGradient(
      colors: [
        AppColors.primary,
        Color(0xFF023A7A),
        AppColors.highlight,
      ],
      stops: [0.0, 0.55, 1.0],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [AppColors.primary, AppColors.support],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: LinearGradient(
      colors: [
        Color(0xFFE9F1FF),
        AppColors.background,
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  static const AppDecorations dark = AppDecorations(
    cardRadius: BorderRadius.all(Radius.circular(24)),
    tileRadius: BorderRadius.all(Radius.circular(20)),
    sheetRadius: BorderRadius.all(Radius.circular(28)),
    softShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 12,
        offset: Offset(0, 6),
      ),
    ],
    mediumShadow: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ],
    deepShadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 26,
        offset: Offset(0, 14),
      ),
    ],
    heroGradient: LinearGradient(
      colors: [
        Color(0xFF101A2E),
        Color(0xFF0B1223),
        AppColors.primary,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    accentGradient: LinearGradient(
      colors: [Color(0xFF0D1B32), AppColors.primary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    backgroundGradient: LinearGradient(
      colors: [Color(0xFF0E1628), Color(0xFF0A101E)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
  );

  @override
  AppDecorations copyWith({
    BorderRadius? cardRadius,
    BorderRadius? tileRadius,
    BorderRadius? sheetRadius,
    List<BoxShadow>? softShadow,
    List<BoxShadow>? mediumShadow,
    List<BoxShadow>? deepShadow,
    LinearGradient? heroGradient,
    LinearGradient? accentGradient,
    LinearGradient? backgroundGradient,
  }) {
    return AppDecorations(
      cardRadius: cardRadius ?? this.cardRadius,
      tileRadius: tileRadius ?? this.tileRadius,
      sheetRadius: sheetRadius ?? this.sheetRadius,
      softShadow: softShadow ?? this.softShadow,
      mediumShadow: mediumShadow ?? this.mediumShadow,
      deepShadow: deepShadow ?? this.deepShadow,
      heroGradient: heroGradient ?? this.heroGradient,
      accentGradient: accentGradient ?? this.accentGradient,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    );
  }

  @override
  AppDecorations lerp(ThemeExtension<AppDecorations>? other, double t) {
    if (other is! AppDecorations) return this;
    return AppDecorations(
      cardRadius:
          BorderRadius.lerp(cardRadius, other.cardRadius, t) ?? cardRadius,
      tileRadius:
          BorderRadius.lerp(tileRadius, other.tileRadius, t) ?? tileRadius,
      sheetRadius:
          BorderRadius.lerp(sheetRadius, other.sheetRadius, t) ?? sheetRadius,
      softShadow:
          BoxShadow.lerpList(softShadow, other.softShadow, t) ?? softShadow,
      mediumShadow: BoxShadow.lerpList(mediumShadow, other.mediumShadow, t) ??
          mediumShadow,
      deepShadow:
          BoxShadow.lerpList(deepShadow, other.deepShadow, t) ?? deepShadow,
      heroGradient: LinearGradient.lerp(heroGradient, other.heroGradient, t) ??
          heroGradient,
      accentGradient:
          LinearGradient.lerp(accentGradient, other.accentGradient, t) ??
              accentGradient,
      backgroundGradient: LinearGradient.lerp(
              backgroundGradient, other.backgroundGradient, t) ??
          backgroundGradient,
    );
  }
}
