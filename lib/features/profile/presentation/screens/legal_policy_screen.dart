import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/obsidian_card.dart';

class LegalPolicyScreen extends StatelessWidget {
  const LegalPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(RouteNames.storefront);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.obsidianBackground,
        appBar: AppBar(
          title: Text(
            'Purchases & Privacy',
            style: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(RouteNames.storefront);
              }
            },
          ),
        ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.p16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Purchases', style: AppTypography.displayMedium),
            const SizedBox(height: AppDimensions.p16),

            _buildClauseCard(
              title: 'Pass purchases are unavailable',
              content: 'You can browse passes, but this version does not take payments or confirm a purchase.',
            ),
            const SizedBox(height: AppDimensions.p12),

            _buildClauseCard(
              title: 'Allergy & Consumption Notice',
              content:
                  'Food items are packaged in food-grade breathable covers and may contain nuts (groundnut chutney), peanuts, gluten, and dairy. '
                  'Tiffins must be consumed within 90 minutes of delivery.',
            ),

            const SizedBox(height: AppDimensions.p24),
            Text('Privacy', style: AppTypography.displayMedium),
            const SizedBox(height: AppDimensions.p16),

            _buildClauseCard(
              title: 'Customer profile',
              content: 'Hungr uses Firebase to verify your phone number. Your customer profile stores your '
                  'name, verified number and selected delivery gate.',
            ),
            const SizedBox(height: AppDimensions.p12),

            _buildClauseCard(
              title: 'Signing out and account deletion',
              content: 'Signing out ends your session on this device. It does not erase your account or '
                  'records held by the service. In-app account deletion is unavailable in this version.',
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildClauseCard({required String title, required String content}) {
    return ObsidianCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMedium.copyWith(color: AppColors.electricSaffron)),
          const SizedBox(height: 6),
          Text(content, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
