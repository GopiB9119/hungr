import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';

/// Glassmorphism utility for floating headers, bottom navigation bars,
/// and contextual overlays inspired by CRED & Airbnb.
///
/// Enhanced with presets: frosted card, blurred bottom bar, glass pill badge.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double blurSigma;
  final List<BoxShadow>? shadows;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(AppDimensions.p16),
    this.margin,
    this.borderRadius,
    this.backgroundColor = AppColors.glassmorphicBackground,
    this.borderColor = AppColors.glassmorphicBorder,
    this.borderWidth = 1.0,
    this.blurSigma = 16.0,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? AppDimensions.radius16;

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: effectiveRadius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: effectiveRadius,
              border: Border.all(
                color: borderColor,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Glassmorphic Presets
// ═════════════════════════════════════════════════════════════

/// A frosted card with heavy blur, subtle border, and soft elevation.
/// Perfect for content cards overlaying images or gradient backgrounds.
///
/// Usage:
/// ```dart
/// GlassFrostedCard(
///   child: Column(children: [...]),
/// )
/// ```
class GlassFrostedCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const GlassFrostedCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(AppDimensions.p20),
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      borderRadius: borderRadius ?? AppDimensions.radius20,
      backgroundColor: const Color(0xE6FFFFFF), // 90% white frosted
      borderColor: const Color(0x1AFFFFFF), // 10% white edge highlight
      borderWidth: 1.5,
      blurSigma: 24.0,
      shadows: const [
        BoxShadow(
          color: Color(0x0A000000), // 4% black
          blurRadius: 16,
          spreadRadius: 0,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x05000000), // 2% black
          blurRadius: 6,
          offset: Offset(0, 1),
        ),
      ],
      child: child,
    );
  }
}

/// A blurred bottom bar for navigation, floating above scrollable content.
/// Mimics iOS-style frosted navigation with safe area padding built in.
///
/// Usage:
/// ```dart
/// Scaffold(
///   bottomNavigationBar: GlassBlurredBottomBar(
///     child: Row(children: [navItem1, navItem2, ...]),
///   ),
/// )
/// ```
class GlassBlurredBottomBar extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassBlurredBottomBar({
    super.key,
    required this.child,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GlassContainer(
      height: height,
      padding: padding ??
          EdgeInsets.only(
            left: AppDimensions.p16,
            right: AppDimensions.p16,
            top: AppDimensions.p12,
            bottom: AppDimensions.p12 + bottomPadding,
          ),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppDimensions.r20),
      ),
      backgroundColor: const Color(0xF2FFFFFF), // 95% white
      borderColor: AppColors.charcoalBorder,
      borderWidth: 0.5,
      blurSigma: 20.0,
      shadows: const [
        BoxShadow(
          color: Color(0x0F000000), // 6% black
          blurRadius: 24,
          spreadRadius: 0,
          offset: Offset(0, -4),
        ),
      ],
      child: child,
    );
  }
}

/// A compact glassmorphic pill badge for labels, tags, and status indicators
/// overlaying images or colored backgrounds.
///
/// Usage:
/// ```dart
/// GlassPillBadge(
///   child: Text('BESTSELLER', style: AppTypography.labelSmall),
/// )
/// ```
class GlassPillBadge extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;

  const GlassPillBadge({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppDimensions.p12,
      vertical: AppDimensions.p6,
    ),
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding,
      borderRadius: AppDimensions.radiusCircle,
      backgroundColor: backgroundColor ?? const Color(0xDDFFFFFF), // 87% white
      borderColor: borderColor ?? const Color(0x26FFFFFF), // 15% white edge
      borderWidth: 1.0,
      blurSigma: 12.0,
      child: child,
    );
  }
}

/// A glassmorphic app bar / header that blurs content scrolling beneath it.
///
/// Usage:
/// ```dart
/// SliverAppBar(
///   flexibleSpace: GlassHeader(
///     child: Text('Menu', style: AppTypography.headlineMedium),
///   ),
/// )
/// ```
class GlassHeader extends StatelessWidget {
  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const GlassHeader({
    super.key,
    required this.child,
    this.height,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return GlassContainer(
      height: height,
      padding: padding ??
          EdgeInsets.only(
            left: AppDimensions.p16,
            right: AppDimensions.p16,
            top: AppDimensions.p12 + topPadding,
            bottom: AppDimensions.p12,
          ),
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(AppDimensions.r16),
      ),
      backgroundColor: const Color(0xF2FFFFFF), // 95% white
      borderColor: AppColors.charcoalBorder,
      borderWidth: 0.5,
      blurSigma: 18.0,
      shadows: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ],
      child: child,
    );
  }
}
