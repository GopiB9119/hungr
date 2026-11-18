import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../viewmodels/cart_viewmodel.dart';
import 'pass_card_3d.dart';

/// Flagship Glassmorphic Floating Cart Pill Bar
/// Features:
/// - Smooth spring slide-up and fade-in when non-empty
/// - Frosted dark glassmorphism (16px blur)
/// - AnimatedSwitcher for fluid price counter transitions
/// - Savings badge highlight with neon mint glow
/// - Pulse-ready checkout CTA with directional micro-animation
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartProvider);
    final bool isVisible = !cartState.isEmpty;

    final isSingleDay = cartState.orderMode == OrderMode.singleDay;
    final int total = cartState.totalPayable;
    final String label = isSingleDay
        ? '${cartState.totalItemCount} ITEM${cartState.totalItemCount > 1 ? 'S' : ''}'
        : (cartState.selectedPassTier == PassTierType.trial3Day
            ? '3-DAY STARTER'
            : (cartState.selectedPassTier == PassTierType.power15Day
                ? '15-DAY POWER'
                : '7-DAY ROUTINE'));

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: SafeArea(
        child: AnimatedSlide(
          offset: isVisible ? Offset.zero : const Offset(0, 1.8),
          duration: AppDimensions.durationMedium,
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: AppDimensions.durationNormal,
            curve: Curves.easeOut,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: AppDimensions.radius20,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xE6111827), // 90% Frosted Dark Slate
                      borderRadius: AppDimensions.radius20,
                      border: Border.all(
                        color: const Color(0x33FFFFFF), // Crisp glass edge
                        width: 1.0,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x38000000),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left: Item Count, Savings & Total Price
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: AppColors.zomatoRed,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        label,
                                        style: AppTypography.monoBadge.copyWith(
                                          color: Colors.white,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    if (cartState.savingsAmount > 0) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0x26059669),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Saved ₹${cartState.savingsAmount}',
                                          style: AppTypography.caption.copyWith(
                                            color: const Color(0xFF34D399),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 220),
                                    transitionBuilder: (child, animation) => SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, 0.3),
                                        end: Offset.zero,
                                      ).animate(animation),
                                      child: FadeTransition(opacity: animation, child: child),
                                    ),
                                    child: Text(
                                      '₹$total',
                                      key: ValueKey('cart_total_$total'),
                                      style: AppTypography.monoPrice.copyWith(
                                        color: Colors.white,
                                        fontSize: 18.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'all-inclusive',
                                    style: AppTypography.caption.copyWith(
                                      color: const Color(0xFF9CA3AF),
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right: Interactive Checkout Button
                        ElevatedButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            context.push(RouteNames.passCheckout);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.zomatoRed,
                            foregroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: AppColors.zomatoRedGlow,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View Cart',
                                style: AppTypography.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
