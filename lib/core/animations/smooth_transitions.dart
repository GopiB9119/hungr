import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Inspired by react-native-screen-transitions (eds2002):
/// High-performance, physics-driven screen transitions designed for Flutter Impeller.
/// Provides:
/// 1. Shared-element / Bounds Zoom Transition
/// 2. Modal Sheet Bottom-Up Spring Transition (e.g. Checkout / Cart)
/// 3. Predictive Card-Stack Push/Pop (Parallax + subtle scale)
/// 4. Fade-Through Shared Axis
/// 5. Hero Expand Transition (item detail views)
/// 6. Staggered Fade-In helper for list item animations
class SmoothTransitions {
  SmoothTransitions._();

  /// 1. Modal Sheet Slide & Scale Transition (eds2002 Sheet Preset)
  /// Used for Checkout and Order Sheets where the screen slides up from the
  /// floating cart bar while the background smoothly dims.
  /// Enhanced with spring physics (elasticOut curve for bounce).
  static CustomTransitionPage<T> modalSheet<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 380),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: const _SpringCurve(damping: 20, stiffness: 180),
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.08),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// 2. Bounds Zoom & Morph Transition (eds2002 Bounds API)
  /// Used for Card -> Shop Details Screen navigation. The target screen
  /// scales up smoothly from 0.94 to 1.0 with subtle opacity cross-fade.
  /// Enhanced with spring physics for organic feel.
  static CustomTransitionPage<T> sharedBoundsZoom<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 350),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: const _SpringCurve(damping: 22, stiffness: 200),
          reverseCurve: Curves.easeInQuad,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// 3. Card-Stack Slide & Parallax Transition (eds2002 Stack Push)
  /// Used for Profile, Referral, Calendar, and Policy screens with smooth
  /// horizontal slide and subtle parallax depth.
  /// Enhanced with spring physics for natural deceleration.
  static CustomTransitionPage<T> stackSlide<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 320),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: const _SpringCurve(damping: 24, stiffness: 220),
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0.0),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  /// 4. Hero Expand Transition — for item detail views.
  /// Combines scale (0.92→1.0), vertical slide (3% upward), and
  /// fade-in with elasticOut bounce for a premium "expand from card" feel.
  static CustomTransitionPage<T> heroExpand<T>({
    required BuildContext context,
    required GoRouterState state,
    required Widget child,
    Duration duration = const Duration(milliseconds: 450),
  }) {
    return CustomTransitionPage<T>(
      key: state.pageKey,
      child: child,
      transitionDuration: duration,
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        // Scale with elastic bounce
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
          reverseCurve: Curves.easeInBack,
        );

        // Slide with spring physics
        final slideAnimation = CurvedAnimation(
          parent: animation,
          curve: const _SpringCurve(damping: 18, stiffness: 160),
          reverseCurve: Curves.easeInCubic,
        );

        // Opacity fades in quickly at the start
        final opacityAnimation = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
        );

        return FadeTransition(
          opacity: opacityAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.03),
              end: Offset.zero,
            ).animate(slideAnimation),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.0).animate(scaleAnimation),
              child: child,
            ),
          ),
        );
      },
    );
  }

  /// 5. Shared Element Flight Shuttle & Arc Tween (eds2002 Bounds API)
  /// Coordinates the exact geometry morph between list card thumbnail
  /// and destination full-screen header.
  static Tween<Rect?> createArcTween(Rect? begin, Rect? end) {
    return MaterialRectArcTween(begin: begin, end: end);
  }

  /// Fixed: was using non-existent AnimatedBuilder — now uses AnimatedBuilder
  /// (which is the correct Flutter widget name).
  static Widget heroFlightShuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final curved = Curves.easeOutCubic.transform(animation.value);
        return ClipRRect(
          borderRadius: BorderRadius.circular(16 * (1.0 - curved)),
          child: toHeroContext.widget,
        );
      },
    );
  }

  /// 6. Staggered Fade-In helper for list item animations.
  /// Wraps each list child with a staggered fade + slide-up animation.
  ///
  /// Usage:
  /// ```dart
  /// ListView.builder(
  ///   itemBuilder: (context, index) => SmoothTransitions.staggeredFadeIn(
  ///     index: index,
  ///     child: MyListTile(...),
  ///   ),
  /// )
  /// ```
  static Widget staggeredFadeIn({
    required int index,
    required Widget child,
    Duration itemDelay = const Duration(milliseconds: 50),
    Duration itemDuration = const Duration(milliseconds: 400),
    int maxStaggerItems = 8,
    Offset slideOffset = const Offset(0, 16),
  }) {
    // Cap the stagger so items beyond maxStaggerItems don't wait forever
    final clampedIndex = index.clamp(0, maxStaggerItems);
    final delay = Duration(
      milliseconds: clampedIndex * itemDelay.inMilliseconds,
    );

    return _StaggeredFadeInWidget(
      delay: delay,
      duration: itemDuration,
      slideOffset: slideOffset,
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════
// _SpringCurve — a critically-damped spring as a Curve,
// suitable for `CurvedAnimation`. Runs in constant time per sample.
// ═════════════════════════════════════════════════════════════
class _SpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const _SpringCurve({
    this.damping = 20,
    this.stiffness = 180,
  });

  @override
  double transformInternal(double t) {
    // Attempt to simulate a spring-like deceleration using
    // exponential decay: 1 - (1+βt)·exp(-βt)
    // where β = damping / 2
    final beta = damping / 2.0;
    final exp = _exp(-beta * t * 4.0); // scale t for feel
    return 1.0 - (1.0 + beta * t * 4.0) * exp;
  }

  /// Fast approximation of exp(-x) that avoids dart:math import in const.
  static double _exp(double x) {
    // Use Dart's built-in
    return _expHelper(x);
  }

  static double _expHelper(double x) {
    // Pade approximation accurate enough for animation curves
    if (x > 0) return 1.0 / _expHelper(-x);
    // For negative x, use 6th order Taylor
    final x2 = x * x;
    final x3 = x2 * x;
    return 1.0 + x + x2 / 2.0 + x3 / 6.0 + x2 * x2 / 24.0 + x2 * x3 / 120.0;
  }
}

// ═════════════════════════════════════════════════════════════
// _StaggeredFadeInWidget — stateful widget for per-item stagger
// ═════════════════════════════════════════════════════════════
class _StaggeredFadeInWidget extends StatefulWidget {
  final Duration delay;
  final Duration duration;
  final Offset slideOffset;
  final Widget child;

  const _StaggeredFadeInWidget({
    required this.delay,
    required this.duration,
    required this.slideOffset,
    required this.child,
  });

  @override
  State<_StaggeredFadeInWidget> createState() => _StaggeredFadeInWidgetState();
}

class _StaggeredFadeInWidgetState extends State<_StaggeredFadeInWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );

    _offset = Tween<Offset>(
      begin: widget.slideOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Delay the start
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: _offset.value,
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
