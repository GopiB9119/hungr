import 'dart:async';
import 'dart:convert';
import 'dart:typed_data' show ByteData;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show StandardMessageCodec, rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hungr/core/router/route_names.dart';
import 'package:hungr/core/services/local_storage_service.dart';
import 'package:hungr/features/onboarding/domain/cluster_model.dart';
import 'package:hungr/features/storefront/domain/tiffin_item_model.dart';
import 'package:hungr/features/storefront/domain/tiffin_shop_model.dart';
import 'package:hungr/features/storefront/presentation/screens/checkout_screen.dart';
import 'package:hungr/features/storefront/presentation/screens/shop_details_screen.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/cart_viewmodel.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/customer_dashboard_viewmodel.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/tiffin_shops_viewmodel.dart';
import 'package:hungr/features/storefront/presentation/widgets/active_pass_dashboard_card.dart';
import 'package:hungr/features/storefront/presentation/widgets/pass_card_3d.dart';
import 'package:hungr/features/subscription/presentation/viewmodels/subscription_history_viewmodel.dart';
import 'package:hungr/features/ticket_calendar/presentation/screens/ticket_calendar_screen.dart';

import 'missed_meal_test.dart' show FixtureDashboard, fixtureTicket;

class _NoPreferences extends Fake implements LocalStorageService {
  @override
  Future<DeliveryCluster?> getSavedGate() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ByteData localFont;
  final allowFetching = GoogleFonts.config.allowRuntimeFetching;

  setUpAll(() async {
    // Test the real cart screen without fetching fonts or relying on a device font cache.
    GoogleFonts.config.allowRuntimeFetching = false;
    localFont = await rootBundle.load('fonts/MaterialIcons-Regular.otf');
  });
  tearDownAll(() => GoogleFonts.config.allowRuntimeFetching = allowFetching);

  setUp(() {
    final assets = {
      for (final family in ['Inter', 'PlusJakartaSans', 'JetBrainsMono'])
        for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'])
          '$family-$weight.otf': <Object?>[],
    };
    final manifest = const StandardMessageCodec().encodeMessage(assets);
    rootBundle.evict('AssetManifest.bin');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
      if (key == 'AssetManifest.bin') return manifest;
      return assets.containsKey(key) ? localFont : null;
    });
  });

  for (final mode in OrderMode.values) {
    testWidgets('${mode.name} checkout keeps the cart without issuing an order', (tester) async {
      final container = ProviderContainer(overrides: [
        customerDashboardProvider.overrideWith((ref) => CustomerDashboardViewModel(storage: _NoPreferences())),
      ]);
      addTearDown(container.dispose);
      final cart = container.read(cartProvider.notifier)..setOrderMode(mode);
      if (mode == OrderMode.singleDay) {
        cart.addItem('item_set_dosa');
        cart.applyCoupon('FIRST50'); // A zero estimate must not become a free order.
      } else {
        cart.selectPassTier(PassTierType.trial3Day);
      }
      final before = container.read(cartProvider);
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: TextButton(
              onPressed: () => context.push(RouteNames.passCheckout),
              child: const Text('Review cart'),
            ),
          ),
        ),
        GoRoute(path: RouteNames.passCheckout, builder: (_, __) => const CheckoutScreen()),
      ]);
      addTearDown(router.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.tap(find.text('Review cart'));
      await tester.pumpAndSettle();
      if (mode == OrderMode.subscriptionPass) {
        expect(find.textContaining('Poori'), findsNothing);
        expect(find.textContaining('Pesarattu'), findsNothing);
        expect(find.textContaining(TiffinItem.findById('item_mysore_bonda')!.name), findsOneWidget);
      }
      final status = find.text('Checkout unavailable • Estimate ₹${before.totalPayable}');
      expect(status, findsOneWidget);
      expect(find.textContaining('Pay ₹'), findsNothing);
      await tester.tap(status);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Review cart'), findsOneWidget);
      expect(container.read(cartProvider), same(before));
      expect(container.read(customerDashboardProvider).hasActivePass, isFalse);
      expect(container.read(customerDashboardProvider).tickets, isEmpty);
      expect(container.read(subscriptionHistoryProvider).orders, isEmpty);
    });
  }

  testWidgets('an unknown or removed kitchen shows a notice, never another kitchen', (tester) async {
    final catalog = StreamController<List<TiffinShop>>();
    addTearDown(catalog.close);
    final container = ProviderContainer(overrides: [
      tiffinShopsProvider.overrideWith((ref) => TiffinShopsViewModel(catalogStream: catalog.stream)),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ShopDetailsScreen(shopId: 'removed_kitchen')),
    ));
    await tester.pump();
    expect(find.text(TiffinShop.standardShops.first.name), findsNothing);
    expect(find.text('This kitchen is not available right now.'), findsOneWidget);
    catalog.add([]); // The live catalog can now be empty.
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('This kitchen is not available right now.'), findsOneWidget);
  });

  testWidgets('a missed source is read-only and not counted as scheduled or paused', (tester) async {
    final container = ProviderContainer(overrides: [
      customerDashboardProvider.overrideWith((ref) => FixtureDashboard([
        fixtureTicket('source', 'MISSED', replacement: 'next'),
        fixtureTicket('next', 'SCHEDULED', day: DateTime.now().add(const Duration(days: 8))),
      ])),
    ]);
    addTearDown(container.dispose);
    Future<void> show(Widget child) async {
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: child)));
      await tester.pumpAndSettle();
    }
    await show(const TicketCalendarScreen());
    expect(find.text('All (2)'), findsOneWidget);
    expect(find.text('Scheduled (1)'), findsOneWidget);
    expect(find.text('Paused (0)'), findsOneWidget);
    expect(find.text('Missed - replacement meal added'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Pause'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    await tester.tap(find.text('Scheduled (1)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Missed'), findsNothing);
    expect(find.text('TOMORROW'), findsNothing);
    await show(const Scaffold(body: ActivePassDashboardCard()));
    expect(find.text('Missed - replacement meal added'), findsOneWidget);
    expect(find.text('Pause'), findsNothing);
    expect(find.text('Switch'), findsNothing);
    expect(find.text('TOMORROW 07:30 AM'), findsNothing);
  });
}
