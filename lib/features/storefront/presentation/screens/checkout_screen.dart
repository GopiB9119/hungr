import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/animations/fluid_gesture_dismissible.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../domain/tiffin_item_model.dart';
import '../../domain/tiffin_shop_model.dart';
import '../viewmodels/tiffin_shops_viewmodel.dart';
import '../viewmodels/cart_viewmodel.dart';
import '../viewmodels/customer_dashboard_viewmodel.dart';
import '../widgets/pass_card_3d.dart';

/// Cart review only. No order placement or payment backend is connected.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final TextEditingController _couponController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String? _couponError;

  @override
  void dispose() {
    _couponController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    final cartNotifier = ref.read(cartViewModelProvider.notifier);
    final success = cartNotifier.applyCoupon(code);
    setState(() {
      if (success) {
        _couponError = null;
        HapticFeedback.lightImpact();
      } else {
        _couponError = 'Invalid promo code. Try FIRST50 or HUNGRFREE';
        HapticFeedback.vibrate();
      }
    });
  }

  void _backToBrowsing() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.storefront);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerState = ref.watch(customerDashboardProvider);
    final cartState = ref.watch(cartProvider);
    final cartNotifier = ref.read(cartViewModelProvider.notifier);

    final bool isSingleDay = cartState.orderMode == OrderMode.singleDay;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToBrowsing();
      },
      child: FluidGestureDismissible(
          onDismiss: _backToBrowsing,
          child: Scaffold(
            backgroundColor: AppColors.obsidianBackground,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
                onPressed: _backToBrowsing,
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSingleDay ? 'Review cart • Single-day meal' : 'Review cart • Morning pass',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Selected gate: ${customerState.selectedCluster.name}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.urgentCrimson),
                  tooltip: 'Clear Cart',
                  onPressed: () {
                    cartNotifier.reset();
                    _backToBrowsing();
                  },
                ),
              ],
            ),
            body: cartState.isEmpty
                ? _buildEmptyState()
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Delivery Gate Location Card (Slot 1: 0ms)
                        _buildGateLocationCard(customerState)
                            .animate()
                            .fadeIn(duration: 200.ms)
                            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 2. Delivery Slot Picker (Slot 2: 50ms)
                        _buildSlotSelector(cartState, cartNotifier)
                            .animate()
                            .fadeIn(delay: 50.ms, duration: 220.ms)
                            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 3. Order Items Summary Card (Slot 3: 100ms)
                        _buildOrderSummaryCard(cartState, cartNotifier)
                            .animate()
                            .fadeIn(delay: 100.ms, duration: 240.ms)
                            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 4. Quick Add-ons Upsell (Slot 4: 140ms)
                        if (isSingleDay) ...[
                          _buildAddonsUpsell(cartState, cartNotifier)
                              .animate()
                              .fadeIn(delay: 140.ms, duration: 250.ms)
                              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 12),
                        ],

                        // 4B. Roommate Split & Save Companion Drop (Slot 4B: 160ms)
                        _buildRoommateCompanionCard(cartState, cartNotifier)
                            .animate()
                            .fadeIn(delay: 160.ms, duration: 250.ms)
                            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 5. Promo Code & Offers (Slot 5: 180ms)
                        _buildPromoSection(cartState, cartNotifier)
                            .animate()
                            .fadeIn(delay: 180.ms, duration: 260.ms)
                            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 6. Delivery Instructions (Slot 6: 220ms)
                        _buildInstructionsCard()
                            .animate()
                            .fadeIn(delay: 220.ms, duration: 270.ms)
                            .slideY(begin: 0.07, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 12),

                        // 8. Detailed Bill Breakdown (Slot 8: 300ms)
                        _buildBillSummary(cartState)
                            .animate()
                            .fadeIn(delay: 300.ms, duration: 300.ms)
                            .slideY(begin: 0.07, end: 0, curve: Curves.easeOutCubic),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
            bottomNavigationBar: cartState.isEmpty
                ? null
                : CheckoutUnavailableFooter(total: cartState.totalPayable),
          ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_bag_outlined, size: 54, color: AppColors.textSubtle),
            ),
            const SizedBox(height: 16),
            Text(
              'Your breakfast cart is empty',
              style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Select hot South Indian tiffin items or choose a weekly pass to save up to ₹360.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _backToBrowsing,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zomatoRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Browse Morning Menu', style: AppTypography.labelLarge.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGateLocationCard(CustomerDashboardState customerState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.zomatoRedSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on_rounded, color: AppColors.zomatoRed, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'HOSTEL GATE DROP',
                      style: AppTypography.monoBadge.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.zomatoRed,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'FREE DROP',
                        style: AppTypography.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonMint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  customerState.selectedCluster.name,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${customerState.selectedCluster.addressZone} • ${customerState.selectedCluster.landmark}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        'Security Desk Drop Only • No floor delivery',
                        style: AppTypography.caption.copyWith(
                          color: const Color(0xFF1E40AF),
                          fontWeight: FontWeight.bold,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push(RouteNames.clusterSelection),
            child: Text(
              'Change',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.zomatoRed,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotSelector(CartState cartState, CartViewModel cartNotifier) {
    const slots = ['07:30 AM – 08:00 AM', '08:00 AM – 08:30 AM'];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: AppColors.goldenAmber),
                  const SizedBox(width: 6),
                  Text(
                    'Preferred morning slot',
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  DateTimeUtils.targetDeliveryLabel(),
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                    color: AppColors.zomatoRed,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: slots.map((slot) {
              final isSelected = cartState.selectedDeliverySlot == slot;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    cartNotifier.selectDeliverySlot(slot);
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: slot == slots.first ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.zomatoRedSurface : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.zomatoRed : AppColors.charcoalBorder,
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        slot,
                        style: AppTypography.labelSmall.copyWith(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? AppColors.zomatoRed : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummaryCard(CartState cartState, CartViewModel cartNotifier) {
    final isSingleDay = cartState.orderMode == OrderMode.singleDay;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSingleDay ? 'Selected Items' : 'Selected Subscription Plan',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                isSingleDay ? '${cartState.totalItemCount} items' : 'Flexible Rollover',
                style: AppTypography.caption.copyWith(color: AppColors.neonMint, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(height: 20, color: AppColors.charcoalBorder),

          if (isSingleDay) ...[
            ...cartState.itemQuantities.entries.map((entry) {
              final item = cartState.itemForKey(entry.key);
              if (item == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: item.isVeg ? AppColors.neonMint : AppColors.urgentCrimson,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: AppTypography.titleSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${item.price} each',
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    // Quantity adjustments
                    Container(
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.zomatoRedSurface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.zomatoRedBorder),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              cartNotifier.removeItem(entry.key);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.remove, size: 14, color: AppColors.zomatoRed),
                            ),
                          ),
                          Text(
                            '${entry.value}',
                            style: AppTypography.labelSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.zomatoRed,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              cartNotifier.addItem(entry.key);
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.add, size: 14, color: AppColors.zomatoRed),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '₹${item.price * entry.value}',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            // Pass Tier Display
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.goldenAmberSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.card_membership_rounded, color: AppColors.goldenAmber, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cartState.selectedPassTier == PassTierType.trial3Day
                            ? '3-Day Starter Pass'
                            : (cartState.selectedPassTier == PassTierType.power15Day
                                ? '15-Day Power Pass'
                                : '7-Day Routine Pass'),
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${cartState.selectedPassDays} Breakfast Meals • Pause anytime before 9 PM',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${cartState.passSubtotal}',
                  style: AppTypography.monoPrice.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            // 1-Tap Smart Pass Menu Auto-Rotation
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.charcoalBorder),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: cartState.autoRotatePassMenu,
                    activeColor: AppColors.zomatoRed,
                    onChanged: (val) {
                      HapticFeedback.selectionClick();
                      cartNotifier.toggleAutoRotatePassMenu(val ?? true);
                    },
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Auto-Rotate Authentic Khammam Variety',
                          style: AppTypography.labelSmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          passRotationItems(ref.watch(tiffinShopsProvider))
                              .map((dish) => dish.name)
                              .join(' • '),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddonsUpsell(CartState cartState, CartViewModel cartNotifier) {
    final addons = [
      TiffinItem.findById('addon_filter_coffee'),
      TiffinItem.findById('addon_boiled_eggs'),
      TiffinItem.findById('addon_badam_milk'),
    ].whereType<TiffinItem>().toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // Amber-50 Soft Morning Glow
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_cafe_rounded, size: 16, color: AppColors.goldenAmber),
              const SizedBox(width: 6),
              Text(
                'Complete Your Morning Breakfast',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: addons.map((addon) {
                final int qty = cartState.itemQuantities[addon.id] ?? 0;
                final bool isAdded = qty > 0;

                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isAdded ? AppColors.zomatoRed : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addon.name,
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${addon.price}',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 28,
                        child: OutlinedButton(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (isAdded) {
                              cartNotifier.removeItem(addon.id);
                            } else {
                              cartNotifier.addItem(addon.id);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isAdded ? AppColors.zomatoRedSurface : Colors.white,
                            side: BorderSide(
                              color: isAdded ? AppColors.zomatoRed : AppColors.charcoalBorder,
                            ),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          child: Text(
                            isAdded ? 'ADDED ($qty)' : '+ ADD',
                            style: AppTypography.caption.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isAdded ? AppColors.zomatoRed : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoommateCompanionCard(CartState cartState, CartViewModel cartNotifier) {
    final bool hasCompanion = cartState.roommateMealCount > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasCompanion ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(
          color: hasCompanion ? const Color(0xFF93C5FD) : AppColors.charcoalBorder,
          width: hasCompanion ? 1.4 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFDBEAFE),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.people_alt_rounded, size: 20, color: Color(0xFF1D4ED8)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Roommate Split & Save',
                      style: AppTypography.titleSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SAVE ₹14',
                        style: AppTypography.caption.copyWith(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Add roommate breakfast for +₹45 (instead of ₹59) • Packed in same gate bag',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!hasCompanion)
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                cartNotifier.addRoommateMeal();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.zomatoRed,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: const Size(0, 32),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                '+ Add (₹45)',
                style: AppTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            )
          else
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      cartNotifier.removeRoommateMeal();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.remove, size: 14, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                  Text(
                    '${cartState.roommateMealCount}',
                    style: AppTypography.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      cartNotifier.addRoommateMeal();
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.add, size: 14, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPromoSection(CartState cartState, CartViewModel cartNotifier) {
    final bool hasCoupon = cartState.appliedCoupon != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.zomatoRed),
              const SizedBox(width: 6),
              Text(
                'Coupons & Discounts',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (hasCoupon) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.neonMint, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        '${cartState.appliedCoupon} Applied (₹${cartState.discountAmount} SAVED)',
                        style: AppTypography.labelSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.neonMint,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      cartNotifier.removeCoupon();
                    },
                    child: Text(
                      'Remove',
                      style: AppTypography.caption.copyWith(color: AppColors.urgentCrimson, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _couponController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Enter coupon (e.g. FIRST50)',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      isDense: true,
                      fillColor: const Color(0xFFF9FAFB),
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textSubtle),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('APPLY', style: AppTypography.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 6),
              Text(
                _couponError!,
                style: AppTypography.caption.copyWith(color: AppColors.urgentCrimson, fontSize: 11),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '💡 Tip: Use FIRST50 for ₹50 off on first orders, or HUNGRFREE for ₹25 off',
              style: AppTypography.caption.copyWith(color: AppColors.textSecondary, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.note_alt_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Gate Drop Instructions',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              hintText: 'e.g. Leave at security desk, hostel block B, call on drop...',
              fillColor: const Color(0xFFF9FAFB),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
              hintStyle: AppTypography.caption.copyWith(color: AppColors.textSubtle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillSummary(CartState cartState) {
    final isSingleDay = cartState.orderMode == OrderMode.singleDay;
    final int subtotal = isSingleDay ? cartState.itemsSubtotal : cartState.passSubtotal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppDimensions.radius16,
        border: Border.all(color: AppColors.charcoalBorder),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bill Summary',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSingleDay ? 'Item Total' : 'Pass Subscription Fee',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 13),
              ),
              Text(
                '₹$subtotal',
                style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gate Drop Delivery', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 13)),
              Row(
                children: [
                  Text('₹30', style: AppTypography.caption.copyWith(decoration: TextDecoration.lineThrough, color: AppColors.textSubtle)),
                  const SizedBox(width: 4),
                  Text('FREE', style: AppTypography.caption.copyWith(color: AppColors.neonMint, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Eco-Friendly Steam Packaging', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 13)),
              Text('FREE', style: AppTypography.caption.copyWith(color: AppColors.neonMint, fontWeight: FontWeight.bold)),
            ],
          ),
          if (cartState.roommateMealCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Roommate Companion (${cartState.roommateMealCount}x)',
                      style: AppTypography.bodySmall.copyWith(color: const Color(0xFF1D4ED8), fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(₹45/meal)',
                      style: AppTypography.caption.copyWith(color: AppColors.textSubtle, fontSize: 10),
                    ),
                  ],
                ),
                Text(
                  '+₹${cartState.roommateSubtotal}',
                  style: AppTypography.titleSmall.copyWith(color: const Color(0xFF1D4ED8), fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Roommate Split Savings',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.neonMint, fontSize: 13),
                ),
                Text(
                  '-₹${cartState.roommateMealCount * 14}',
                  style: AppTypography.titleSmall.copyWith(color: AppColors.neonMint, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          if (cartState.discountAmount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Coupon Discount (${cartState.appliedCoupon})', style: AppTypography.bodySmall.copyWith(color: AppColors.neonMint, fontSize: 13)),
                Text('-₹${cartState.discountAmount}', style: AppTypography.titleSmall.copyWith(color: AppColors.neonMint, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          const Divider(height: 24, color: AppColors.charcoalBorder),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estimated total',
                    style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  Text(
                    'Inclusive of all taxes',
                    style: AppTypography.caption.copyWith(color: AppColors.textSubtle, fontSize: 10),
                  ),
                ],
              ),
              Text(
                '₹${cartState.totalPayable}',
                style: AppTypography.monoPrice.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.zomatoRed,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

}

class CheckoutUnavailableFooter extends StatelessWidget {
  const CheckoutUnavailableFooter({super.key, required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListTile(
        tileColor: Colors.white,
        leading: const Icon(Icons.info_outline),
        title: Text('Checkout unavailable • Estimate ₹$total'),
        subtitle: const Text('You can edit your cart. No payment is taken and no delivery is booked.'),
      ),
    );
  }
}
