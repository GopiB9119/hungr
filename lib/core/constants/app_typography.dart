import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Hungr Typography System:
/// - Plus Jakarta Sans: Headers, Hero Titles, Badges
/// - Inter: Clean, legible body copy, descriptions, dialogs
/// - JetBrains Mono: Precise digits, live countdown flip clock, monetary values
///
/// Enhancements: display weights for hero text, animated text styles,
/// premium text shadows, priceStrikethrough, heroTitle for splash/marketing.
class AppTypography {
  AppTypography._();

  // ─────────────────────────────────────────────────────────
  // Hero & Display Weights (Splash, Marketing, Onboarding)
  // ─────────────────────────────────────────────────────────

  /// 48px w900 hero title for splash screens and marketing banners.
  /// Pairs with [heroTitleShadow] for dramatic depth.
  static TextStyle get heroTitle => GoogleFonts.plusJakartaSans(
        fontSize: 48,
        fontWeight: FontWeight.w900,
        color: AppColors.textCrispWhite,
        letterSpacing: -1.5,
        height: 1.1,
      );

  /// 40px w800 for secondary hero headlines on onboarding slides.
  static TextStyle get heroSubtitle => GoogleFonts.plusJakartaSans(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        color: AppColors.textCrispWhite,
        letterSpacing: -1.0,
        height: 1.15,
      );

  /// 56px w900 ultra-display for splash brand name ("HUNGR").
  static TextStyle get displayHero => GoogleFonts.plusJakartaSans(
        fontSize: 56,
        fontWeight: FontWeight.w900,
        color: AppColors.zomatoRed,
        letterSpacing: -2.0,
        height: 1.0,
      );

  // ─────────────────────────────────────────────────────────
  // Plus Jakarta Sans — Headlines & Titles
  // ─────────────────────────────────────────────────────────

  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: AppColors.textCrispWhite,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: AppColors.textCrispWhite,
        letterSpacing: -0.4,
      );

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textCrispWhite,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
        letterSpacing: -0.2,
      );

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
      );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
      );

  // ─────────────────────────────────────────────────────────
  // Inter — Body & Informational Text
  // ─────────────────────────────────────────────────────────

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: AppColors.textCrispWhite,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textMutedSlate,
        height: 1.4,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textMutedSlate,
      );

  static TextStyle get caption => bodySmall;

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
        letterSpacing: 0.2,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
        letterSpacing: 0.2,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: AppColors.textMutedSlate,
        letterSpacing: 0.5,
      );

  // ─────────────────────────────────────────────────────────
  // JetBrains Mono — Real-time Countdown, Metrics, Prices & Timestamps
  // ─────────────────────────────────────────────────────────

  static TextStyle get monoClockLarge => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.electricSaffron,
        letterSpacing: 1.0,
      );

  static TextStyle get monoClockUrgent => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.urgentCrimson,
        letterSpacing: 1.0,
      );

  static TextStyle get monoPrice => GoogleFonts.jetBrainsMono(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textCrispWhite,
      );

  static TextStyle get monoBadge => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textCrispWhite,
        letterSpacing: 0.5,
      );

  // ─────────────────────────────────────────────────────────
  // Specialised Styles
  // ─────────────────────────────────────────────────────────

  /// Strikethrough price for showing original price next to discounted price.
  /// e.g. ~~₹120~~ ₹89
  static TextStyle get priceStrikethrough => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSubtle,
        decoration: TextDecoration.lineThrough,
        decorationColor: AppColors.textSubtle,
        decorationThickness: 2.0,
      );

  /// Large strikethrough for prominent price comparisons on detail pages.
  static TextStyle get priceStrikethroughLarge => GoogleFonts.jetBrainsMono(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textSubtle,
        decoration: TextDecoration.lineThrough,
        decorationColor: AppColors.textSubtle,
        decorationThickness: 2.0,
      );

  /// Savings badge text — "Save ₹31" in emerald green.
  static TextStyle get savingsBadge => GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.neonMint,
        letterSpacing: 0.3,
      );

  /// Countdown digit for inline timers (smaller than flip clock).
  static TextStyle get monoCountdownInline => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.zomatoRed,
        letterSpacing: 0.5,
      );

  /// Button text on crimson backgrounds
  static TextStyle get buttonOnPrimary => GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPrimary,
        letterSpacing: 0.3,
      );

  // ─────────────────────────────────────────────────────────
  // Premium Text Shadows
  // ─────────────────────────────────────────────────────────

  /// Dramatic depth shadow for hero titles on image backgrounds.
  static const List<Shadow> heroTitleShadow = [
    Shadow(
      color: Color(0x3D111827), // 24% Gray-900
      blurRadius: 24,
      offset: Offset(0, 4),
    ),
    Shadow(
      color: Color(0x14111827), // 8% Gray-900
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Subtle elevation shadow for card titles.
  static const List<Shadow> cardTitleShadow = [
    Shadow(
      color: Color(0x14111827),
      blurRadius: 8,
      offset: Offset(0, 1),
    ),
  ];

  /// Crimson glow shadow for text on dark backgrounds (promo banners).
  static const List<Shadow> crimsonGlowShadow = [
    Shadow(
      color: Color(0x52E23744), // 32% Zomato Red
      blurRadius: 20,
      offset: Offset(0, 2),
    ),
  ];

  /// Soft white glow for text overlaying images.
  static const List<Shadow> whiteGlowShadow = [
    Shadow(
      color: Color(0x99FFFFFF),
      blurRadius: 16,
      offset: Offset.zero,
    ),
  ];
}
