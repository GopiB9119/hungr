import 'package:flutter/material.dart';

/// Layout metrics, padding, border radii, elevation constants,
/// animation durations, spring physics, and card/bottom-sheet presets.
class AppDimensions {
  AppDimensions._();

  // ─────────────────────────────────────────────────────────
  // Spacing & Padding (4px grid)
  // ─────────────────────────────────────────────────────────
  static const double p2 = 2.0;
  static const double p4 = 4.0;
  static const double p6 = 6.0;
  static const double p8 = 8.0;
  static const double p10 = 10.0;
  static const double p12 = 12.0;

  static const double p16 = 16.0;
  static const double p20 = 20.0;
  static const double p24 = 24.0;
  static const double p32 = 32.0;
  static const double p40 = 40.0;
  static const double p48 = 48.0;
  static const double p56 = 56.0;
  static const double p64 = 64.0;

  // ─────────────────────────────────────────────────────────
  // Border Radii
  // ─────────────────────────────────────────────────────────
  static const double r4 = 4.0;
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double r28 = 28.0;
  static const double r32 = 32.0;
  static const double rCircle = 999.0;

  static const BorderRadius radius4 = BorderRadius.all(Radius.circular(r4));
  static const BorderRadius radius8 = BorderRadius.all(Radius.circular(r8));
  static const BorderRadius radius12 = BorderRadius.all(Radius.circular(r12));
  static const BorderRadius radius16 = BorderRadius.all(Radius.circular(r16));
  static const BorderRadius radius20 = BorderRadius.all(Radius.circular(r20));
  static const BorderRadius radius24 = BorderRadius.all(Radius.circular(r24));
  static const BorderRadius radius28 = BorderRadius.all(Radius.circular(r28));
  static const BorderRadius radius32 = BorderRadius.all(Radius.circular(r32));
  static const BorderRadius radiusCircle = BorderRadius.all(Radius.circular(rCircle));

  // ─────────────────────────────────────────────────────────
  // Card Borders & Heights
  // ─────────────────────────────────────────────────────────
  static const double cardBorderWidth = 1.0;
  static const double flipClockHeight = 84.0;
  static const double passCardHeight = 82.0;
  static const double slideToUnlockHeight = 64.0;

  // ─────────────────────────────────────────────────────────
  // Card Elevation Presets
  // ─────────────────────────────────────────────────────────
  static const double elevationNone = 0.0;
  static const double elevationSubtle = 1.0; // Subtle lift for list items
  static const double elevationCard = 2.0; // Standard card elevation
  static const double elevationRaised = 4.0; // Raised FABs, prominent cards
  static const double elevationModal = 8.0; // Modal sheets, dialogs
  static const double elevationOverlay = 16.0; // Dropdown menus, tooltips
  static const double elevationNavigation = 24.0; // Navigation bars, app bars

  // ─────────────────────────────────────────────────────────
  // Bottom Sheet Corner Radii
  // ─────────────────────────────────────────────────────────
  static const double bottomSheetRadiusSmall = 16.0;
  static const double bottomSheetRadiusMedium = 24.0;
  static const double bottomSheetRadiusLarge = 32.0;

  static const BorderRadius bottomSheetBorderSmall = BorderRadius.vertical(
    top: Radius.circular(16.0),
  );
  static const BorderRadius bottomSheetBorderMedium = BorderRadius.vertical(
    top: Radius.circular(24.0),
  );
  static const BorderRadius bottomSheetBorderLarge = BorderRadius.vertical(
    top: Radius.circular(32.0),
  );

  /// Drag handle pill dimensions for bottom sheets
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;
  static const BorderRadius dragHandleRadius = BorderRadius.all(Radius.circular(2.0));

  // ─────────────────────────────────────────────────────────
  // Animation Durations
  // ─────────────────────────────────────────────────────────
  /// 100ms — micro-interactions: tap feedback, opacity toggle
  static const Duration durationInstant = Duration(milliseconds: 100);
  /// 150ms — fast: button presses, icon state changes, ripple effects
  static const Duration durationFast = Duration(milliseconds: 150);
  /// 200ms — quick: tooltip show/hide, small element transitions
  static const Duration durationQuick = Duration(milliseconds: 200);
  /// 300ms — normal: card transitions, most UI state changes
  static const Duration durationNormal = Duration(milliseconds: 300);
  /// 400ms — medium: page transitions, bottom sheet open/close
  static const Duration durationMedium = Duration(milliseconds: 400);
  /// 500ms — slow: hero animations, complex enter transitions
  static const Duration durationSlow = Duration(milliseconds: 500);
  /// 700ms — dramatic: splash animations, celebration effects
  static const Duration durationDramatic = Duration(milliseconds: 700);
  /// 1000ms — stagger base: staggered list animation total
  static const Duration durationStagger = Duration(milliseconds: 1000);

  // ─────────────────────────────────────────────────────────
  // Spring Physics Constants (Impeller-optimized)
  // ─────────────────────────────────────────────────────────
  /// Snappy spring for button presses and small movements
  static const SpringDescription springSnappy = SpringDescription(
    mass: 1.0,
    stiffness: 400.0,
    damping: 28.0,
  );

  /// Responsive spring for card transitions and list reorder
  static const SpringDescription springResponsive = SpringDescription(
    mass: 1.0,
    stiffness: 300.0,
    damping: 22.0,
  );

  /// Bouncy spring for playful micro-interactions (add-to-cart bounce)
  static const SpringDescription springBouncy = SpringDescription(
    mass: 1.0,
    stiffness: 350.0,
    damping: 15.0,
  );

  /// Gentle spring for modal sheets and large surface animations
  static const SpringDescription springGentle = SpringDescription(
    mass: 1.0,
    stiffness: 200.0,
    damping: 20.0,
  );

  /// Critical spring for smooth settle without overshoot (page transitions)
  static const SpringDescription springCritical = SpringDescription(
    mass: 1.0,
    stiffness: 250.0,
    damping: 25.0,
  );

  // ─────────────────────────────────────────────────────────
  // Stagger Delay
  // ─────────────────────────────────────────────────────────
  /// Per-item stagger delay for list animations (50ms between items)
  static const Duration staggerItemDelay = Duration(milliseconds: 50);
  /// Maximum stagger delay cap (don't stagger beyond 8 items)
  static const int staggerMaxItems = 8;
}
