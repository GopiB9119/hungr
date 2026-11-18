import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_dimensions.dart';
import '../constants/app_typography.dart';

/// Flagship Morning Porcelain & Crimson ThemeData configuring Impeller-optimized visuals.
/// Enhanced with page transitions, elevated button themes, input decoration themes,
/// bottom sheet themes, snackbar themes, chip themes, and premium polish.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.obsidianBackground,
      primaryColor: AppColors.zomatoRed,
      splashColor: AppColors.tapRipplePrimary,
      highlightColor: Colors.transparent,
      splashFactory: InkSparkle.splashFactory, // Premium ripple effect

      colorScheme: const ColorScheme.light(
        primary: AppColors.zomatoRed,
        onPrimary: Colors.white,
        primaryContainer: AppColors.zomatoRedSurface,
        onPrimaryContainer: AppColors.zomatoRedDark,
        secondary: AppColors.neonMint,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.neonMintSurface,
        onSecondaryContainer: AppColors.neonMint,
        tertiary: AppColors.goldenAmber,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.goldenAmberSurface,
        onTertiaryContainer: AppColors.goldenAmber,
        surface: AppColors.matteCharcoal,
        onSurface: AppColors.textPrimary,
        surfaceContainerHighest: AppColors.surfaceVariant,
        error: AppColors.urgentCrimson,
        onError: Colors.white,
        errorContainer: AppColors.urgentCrimsonSurface,
        onErrorContainer: AppColors.urgentCrimson,
        outline: AppColors.charcoalBorder,
        outlineVariant: AppColors.surfaceHighlight,
        scrim: AppColors.modalScrim,
      ),

      // ─── Page Transitions ──────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      // ─── Card Theme ────────────────────────────────────────
      cardTheme: const CardThemeData(
        color: AppColors.matteCharcoal,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radius16,
          side: BorderSide(
            color: AppColors.charcoalBorder,
            width: AppDimensions.cardBorderWidth,
          ),
        ),
      ),

      // ─── App Bar ───────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.matteCharcoal,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        iconTheme: const IconThemeData(
          color: AppColors.textPrimary,
          size: 24,
        ),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textMutedSlate,
          size: 24,
        ),
        titleTextStyle: AppTypography.headlineMedium.copyWith(color: AppColors.textPrimary),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: AppColors.matteCharcoal,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // ─── Elevated Buttons ──────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.zomatoRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.charcoalBorder,
          disabledForegroundColor: AppColors.textSubtle,
          elevation: AppDimensions.elevationCard,
          shadowColor: AppColors.zomatoRedGlow,
          textStyle: AppTypography.buttonOnPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.radius12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.p24,
            vertical: AppDimensions.p16,
          ),
          minimumSize: const Size(88, 52),
          animationDuration: AppDimensions.durationFast,
        ),
      ),

      // ─── Filled Buttons ────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.zomatoRed,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.surfaceVariant,
          disabledForegroundColor: AppColors.textSubtle,
          textStyle: AppTypography.buttonOnPrimary,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.radius12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.p24,
            vertical: AppDimensions.p16,
          ),
          minimumSize: const Size(88, 52),
        ),
      ),

      // ─── Outlined Buttons ──────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.zomatoRed,
          side: const BorderSide(color: AppColors.zomatoRedBorder, width: 1.5),
          textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.radius12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.p20,
            vertical: AppDimensions.p16,
          ),
          minimumSize: const Size(88, 52),
          animationDuration: AppDimensions.durationFast,
        ),
      ),

      // ─── Text Buttons ──────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.zomatoRed,
          textStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600),
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.radius8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.p16,
            vertical: AppDimensions.p8,
          ),
        ),
      ),

      // ─── Icon Buttons ──────────────────────────────────────
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          highlightColor: AppColors.tapRippleNeutral,
          shape: const RoundedRectangleBorder(
            borderRadius: AppDimensions.radius12,
          ),
        ),
      ),

      // ─── Floating Action Button ────────────────────────────
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.zomatoRed,
        foregroundColor: Colors.white,
        elevation: AppDimensions.elevationRaised,
        focusElevation: AppDimensions.elevationModal,
        hoverElevation: AppDimensions.elevationRaised,
        highlightElevation: AppDimensions.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radius16,
        ),
      ),

      // ─── Input Decoration (Phone Auth, OTP, Form fields) ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.p16,
          vertical: AppDimensions.p16,
        ),
        hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSubtle),
        labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        floatingLabelStyle: AppTypography.labelMedium.copyWith(color: AppColors.zomatoRed),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.urgentCrimson),
        helperStyle: AppTypography.bodySmall.copyWith(color: AppColors.textSubtle),
        prefixIconColor: AppColors.textMutedSlate,
        suffixIconColor: AppColors.textSubtle,
        border: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.charcoalBorder, width: 1.0),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.charcoalBorder, width: 1.0),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.zomatoRed, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.urgentCrimson, width: 1.0),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.urgentCrimson, width: 1.5),
        ),
        disabledBorder: const OutlineInputBorder(
          borderRadius: AppDimensions.radius12,
          borderSide: BorderSide(color: AppColors.surfaceHighlight, width: 1.0),
        ),
      ),

      // ─── Bottom Sheet Theme ────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.elevationModal,
        modalElevation: AppDimensions.elevationModal,
        clipBehavior: Clip.antiAlias,
        dragHandleColor: AppColors.charcoalBorder,
        dragHandleSize: Size(AppDimensions.dragHandleWidth, AppDimensions.dragHandleHeight),
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.r24)),
        ),
        constraints: BoxConstraints(maxWidth: 640), // Tablet-safe
      ),

      // ─── Dialog Theme ──────────────────────────────────────
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.elevationModal,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radius20,
        ),
      ),

      // ─── Snackbar Theme ────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTypography.bodyMedium.copyWith(color: Colors.white),
        actionTextColor: AppColors.zomatoRedLight,
        behavior: SnackBarBehavior.floating,
        elevation: AppDimensions.elevationRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimensions.radius12,
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.p16,
          vertical: AppDimensions.p12,
        ),
        dismissDirection: DismissDirection.horizontal,
      ),

      // ─── Chip Theme ────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.zomatoRedSurface,
        disabledColor: AppColors.surfaceHighlight,
        labelStyle: AppTypography.labelMedium,
        secondaryLabelStyle: AppTypography.labelSmall,
        side: const BorderSide(color: AppColors.charcoalBorder, width: 1.0),
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimensions.radius8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.p12,
          vertical: AppDimensions.p4,
        ),
        showCheckmark: false,
      ),

      // ─── Tab Bar Theme ─────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.zomatoRed,
        unselectedLabelColor: AppColors.textMutedSlate,
        labelStyle: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.labelLarge,
        indicatorColor: AppColors.zomatoRed,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),

      // ─── Badge Theme ───────────────────────────────────────
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.zomatoRed,
        textColor: Colors.white,
        smallSize: 8,
        largeSize: 16,
      ),

      // ─── Switch Theme ──────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textSubtle;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.zomatoRed;
          return AppColors.surfaceHighlight;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return AppColors.charcoalBorder;
        }),
      ),

      // ─── Checkbox Theme ────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.zomatoRed;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.charcoalBorder, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.r4),
        ),
      ),

      // ─── Radio Theme ───────────────────────────────────────
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.zomatoRed;
          return AppColors.textSubtle;
        }),
      ),

      // ─── Progress Indicator ────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.zomatoRed,
        linearTrackColor: AppColors.zomatoRedSurface,
        circularTrackColor: AppColors.zomatoRedSurface,
      ),

      // ─── Tooltip Theme ─────────────────────────────────────
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: AppDimensions.radius8,
        ),
        textStyle: AppTypography.bodySmall.copyWith(color: Colors.white),
        waitDuration: AppDimensions.durationSlow,
      ),

      // ─── Divider ───────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.charcoalBorder,
        thickness: 1.0,
        space: 1.0,
      ),

      // ─── Bottom Navigation Bar ─────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.zomatoRed,
        unselectedItemColor: AppColors.textSubtle,
        type: BottomNavigationBarType.fixed,
        elevation: AppDimensions.elevationRaised,
        showUnselectedLabels: true,
      ),

      // ─── Navigation Bar (Material 3) ──────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: AppDimensions.elevationRaised,
        indicatorColor: AppColors.zomatoRedSurface,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSmall.copyWith(
              color: AppColors.zomatoRed,
              fontWeight: FontWeight.w700,
            );
          }
          return AppTypography.labelSmall.copyWith(color: AppColors.textSubtle);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.zomatoRed, size: 24);
          }
          return const IconThemeData(color: AppColors.textSubtle, size: 24);
        }),
      ),

      // ─── List Tile Theme ───────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(
          horizontal: AppDimensions.p16,
          vertical: AppDimensions.p4,
        ),
        minVerticalPadding: AppDimensions.p8,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.radius12,
        ),
      ),
    );
  }

  // Backwards compatibility alias
  static ThemeData get darkTheme => lightTheme;

  // ─────────────────────────────────────────────────────────
  // Reusable BoxShadow Glows
  // ─────────────────────────────────────────────────────────
  static List<BoxShadow> get saffronGlowShadow => const [
        BoxShadow(
          color: AppColors.saffronGlow,
          blurRadius: 20,
          spreadRadius: 2,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get mintGlowShadow => const [
        BoxShadow(
          color: AppColors.neonMintGlow,
          blurRadius: 18,
          spreadRadius: 1,
          offset: Offset(0, 3),
        ),
      ];

  static List<BoxShadow> get urgentCrimsonGlowShadow => const [
        BoxShadow(
          color: AppColors.urgentCrimsonGlow,
          blurRadius: 20,
          spreadRadius: 2,
          offset: Offset(0, 4),
        ),
      ];

  // ─────────────────────────────────────────────────────────
  // Premium Elevation Shadows (for custom containers)
  // ─────────────────────────────────────────────────────────

  /// Subtle shadow for flat cards needing slight lift
  static List<BoxShadow> get shadowSubtle => const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  /// Standard card shadow
  static List<BoxShadow> get shadowCard => const [
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 8,
          spreadRadius: 0,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 4,
          offset: Offset(0, 1),
        ),
      ];

  /// Raised shadow for prominent elements (FABs, sticky headers)
  static List<BoxShadow> get shadowRaised => const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          spreadRadius: 0,
          offset: Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];

  /// Modal overlay shadow
  static List<BoxShadow> get shadowModal => const [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 32,
          spreadRadius: 0,
          offset: Offset(0, 8),
        ),
        BoxShadow(
          color: Color(0x0A000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
}
