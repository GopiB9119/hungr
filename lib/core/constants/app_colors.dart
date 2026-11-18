import 'package:flutter/material.dart';

/// Hungr Flagship Crisp Light Theme Palette ("Morning Porcelain & Crimson")
/// Engineered for Impeller 120FPS rendering with high contrast,
/// clean pure white surfaces, crisp slate typography, and appetite-stimulating crimson accents.
///
/// Enhancements: shimmer gradients, premium surface tints, animated gradient presets,
/// micro-interaction colors (success pulse green, warning amber pulse, tap ripple colors).
class AppColors {
  AppColors._();

  // ─────────────────────────────────────────────────────────
  // Primary Canvas & Surface (Pristine Light Palette)
  // ─────────────────────────────────────────────────────────
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color obsidianBackground = Color(0xFFF8F9FA); // Clean Soft Canvas
  static const Color matteCharcoal = Color(0xFFFFFFFF); // Elevated Crisp Card Surface
  static const Color charcoalBorder = Color(0xFFE5E7EB); // 1px Subtle Border (Tailwind Gray-200)
  static const Color surfaceVariant = Color(0xFFF3F4F6); // Secondary Gray Surface
  static const Color surfaceHighlight = Color(0xFFE5E7EB); // Elevated Highlight

  // Premium Surface Tints (Layered depth for card hierarchies)
  static const Color surfaceTint1 = Color(0xFFFFFBFA); // Warm porcelain tint (level 1)
  static const Color surfaceTint2 = Color(0xFFFFF7F5); // Soft rose warmth (level 2)
  static const Color surfaceTint3 = Color(0xFFFFF0ED); // Deeper rose warmth (level 3)
  static const Color surfaceElevated = Color(0xFFFFFFFF); // Pure elevated card
  static const Color surfacePressed = Color(0xFFF9FAFB); // Pressed state surface

  // ─────────────────────────────────────────────────────────
  // Glassmorphic Backdrop
  // ─────────────────────────────────────────────────────────
  static const Color glassmorphicBackground = Color(0xEEFFFFFF); // 93% Frosted White
  static const Color glassmorphicBorder = Color(0x1F000000); // 12% Black Subtle Edge
  static const Color glassmorphicOverlay = Color(0x0A000000); // 4% Black overlay
  static const Color glassmorphicDark = Color(0xCC1F2937); // 80% Dark glass for modals

  // ─────────────────────────────────────────────────────────
  // Primary Brand (Zomato Hunger-Stimulating Crimson Red & Accents)
  // ─────────────────────────────────────────────────────────
  static const Color zomatoRed = Color(0xFFE23744); // Proven Appetite Red
  static const Color zomatoRedDark = Color(0xFFB81D2B); // Deep Rich Crimson
  static const Color zomatoRedDeep = Color(0xFF8B1522); // Deepest crimson for text on red surface
  static const Color zomatoRedGlow = Color(0x26E23744); // Soft Crimson Ambient Shadow
  static const Color zomatoRedLight = Color(0xFFFF5263); // Bright Coral Red Highlight
  static const Color zomatoRedSurface = Color(0xFFFFF1F2); // Rose-50 Tinted Surface
  static const Color zomatoRedBorder = Color(0xFFFECDD3); // Rose-200 Subtle Border
  static const Color zomatoRedMuted = Color(0xFFFDA4AF); // Rose-300 Muted accent

  // Legacy & Cross-token Aliases (Mapped to Zomato Red)
  static const Color electricSaffron = zomatoRed;
  static const Color electricSaffronDark = zomatoRedDark;
  static const Color saffronGlow = zomatoRedGlow;
  static const Color saffronLight = zomatoRedLight;
  static const Color goldenAmber = Color(0xFFD97706); // Warm Breakfast Amber (Readable on white)
  static const Color goldenAmberSurface = Color(0xFFFFFBEB); // Amber-50 Light Surface

  // ─────────────────────────────────────────────────────────
  // Functional Accents (High-Contrast for Light Theme)
  // ─────────────────────────────────────────────────────────
  static const Color neonMint = Color(0xFF059669); // Emerald-600: Active Pass / Delivered
  static const Color neonMintGlow = Color(0x20059669); // Ambient Emerald Shadow
  static const Color neonMintSurface = Color(0xFFECFDF5); // Emerald-50 Soft Surface
  static const Color urgentCrimson = Color(0xFFDC2626); // Red-600: 9:00 PM Cutoff Alert
  static const Color urgentCrimsonGlow = Color(0x26DC2626); // Crimson Shadow
  static const Color urgentCrimsonSurface = Color(0xFFFEF2F2); // Red-50 Soft Alert Surface
  static const Color warningAmber = Color(0xFFD97706); // Pending / In Preparation

  // ─────────────────────────────────────────────────────────
  // Micro-Interaction Colors
  // ─────────────────────────────────────────────────────────
  static const Color successPulseGreen = Color(0xFF10B981); // Emerald-500: Order confirmed pulse
  static const Color successPulseGreenGlow = Color(0x3310B981); // 20% glow ring
  static const Color warningAmberPulse = Color(0xFFF59E0B); // Amber-500: "Order preparing" pulse
  static const Color warningAmberPulseGlow = Color(0x33F59E0B); // 20% glow ring
  static const Color tapRipplePrimary = Color(0x14E23744); // 8% Crimson tap ripple
  static const Color tapRippleNeutral = Color(0x0A000000); // 4% Neutral tap ripple
  static const Color tapRippleMint = Color(0x14059669); // 8% Mint tap ripple
  static const Color focusRingColor = Color(0x4DE23744); // 30% Crimson focus ring
  static const Color skeletonBase = Color(0xFFE5E7EB); // Skeleton loading base
  static const Color skeletonHighlight = Color(0xFFF3F4F6); // Skeleton loading shimmer

  // ─────────────────────────────────────────────────────────
  // Typography (Razor-Sharp Tailwind Slate Palette on White)
  // ─────────────────────────────────────────────────────────
  static const Color textCrispWhite = Color(0xFF111827); // Gray-900: Primary High-Contrast Titles
  static const Color textPrimary = Color(0xFF111827); // Primary Dark Text
  static const Color textMutedSlate = Color(0xFF4B5563); // Gray-600: Subtitles / Metadata
  static const Color textSecondary = Color(0xFF4B5563); // Secondary Text
  static const Color textSubtle = Color(0xFF9CA3AF); // Gray-400: Inactive / Placeholders
  static const Color textDark = Color(0xFF111827); // Dark Text
  static const Color textOnPrimary = Color(0xFFFFFFFF); // White text on crimson buttons
  static const Color textOnSurface = Color(0xFF374151); // Gray-700: Body on white cards
  static const Color textDisabled = Color(0xFFD1D5DB); // Gray-300: Disabled text

  // ─────────────────────────────────────────────────────────
  // Pass Tier Card Gradients
  // ─────────────────────────────────────────────────────────
  static const LinearGradient zomatoRedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE23744),
      Color(0xFFB81D2B),
    ],
  );

  static const LinearGradient saffronCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFF1F2),
    ],
  );

  static const LinearGradient trialPassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8F9FA),
    ],
  );

  static const LinearGradient powerPassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFECFDF5),
    ],
  );

  // ─────────────────────────────────────────────────────────
  // Shimmer Gradients (for loading skeletons & premium card effects)
  // ─────────────────────────────────────────────────────────
  static const LinearGradient shimmerGradientLight = LinearGradient(
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    colors: [
      Color(0xFFE5E7EB), // Gray-200 base
      Color(0xFFF9FAFB), // Gray-50 highlight
      Color(0xFFE5E7EB), // Gray-200 base
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient shimmerGradientWarm = LinearGradient(
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    colors: [
      Color(0xFFFFF1F2), // Rose-50 base
      Color(0xFFFFFFFF), // White highlight
      Color(0xFFFFF1F2), // Rose-50 base
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const LinearGradient shimmerGradientPremium = LinearGradient(
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
    colors: [
      Color(0xFFFECDD3), // Rose-200
      Color(0xFFFFFFFF), // White
      Color(0xFFFECDD3), // Rose-200
    ],
    stops: [0.0, 0.5, 1.0],
  );

  // ─────────────────────────────────────────────────────────
  // Animated Gradient Presets (for backgrounds & hero sections)
  // ─────────────────────────────────────────────────────────
  /// Sunrise morning warmth — use for splash / onboarding backgrounds
  static const LinearGradient morningGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFF7ED), // Orange-50
      Color(0xFFFFF1F2), // Rose-50
      Color(0xFFFFFFFF), // Pure white
    ],
    stops: [0.0, 0.4, 1.0],
  );

  /// Warm crimson hero gradient — CTA backgrounds and promo banners
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE23744), // Zomato Red
      Color(0xFFFF5263), // Coral Red
      Color(0xFFE23744), // Zomato Red
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Subtle ambient gradient for premium cards
  static const LinearGradient premiumCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFFFF7F5),
      Color(0xFFFFF1F2),
    ],
    stops: [0.0, 0.6, 1.0],
  );

  /// Golden "breakfast hour" gradient
  static const LinearGradient breakfastGoldenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFBEB), // Amber-50
      Color(0xFFFFF7ED), // Orange-50
      Color(0xFFFFFFFF), // White
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Success confirmation gradient
  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF059669), // Emerald-600
      Color(0xFF10B981), // Emerald-500
    ],
  );

  // ─────────────────────────────────────────────────────────
  // Overlay & Scrim
  // ─────────────────────────────────────────────────────────
  static const Color modalScrim = Color(0x52111827); // 32% Gray-900 for modal backdrops
  static const Color bottomSheetScrim = Color(0x3D111827); // 24% Gray-900
  static const Color imageOverlay = Color(0x29111827); // 16% for image text legibility
}
