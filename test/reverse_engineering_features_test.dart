import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hungr/core/utils/date_time_utils.dart';
import 'package:hungr/core/utils/whatsapp_link_helper.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/cart_viewmodel.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/tiffin_shops_viewmodel.dart';
import 'package:hungr/features/storefront/domain/tiffin_shop_model.dart';
import 'package:hungr/features/storefront/data/shop_sync_service.dart';

void main() {
  group('1. Cutoff Rollover Engine & Bag Token Generator', () {
    test('delivery and countdown roll over at exactly 21:00 IST', () {
      final cutoff = DateTime.utc(2026, 12, 31, 15, 30);
      final before = cutoff.subtract(const Duration(seconds: 1));
      expect(DateTimeUtils.isAfterCutoffToday(instant: before), isFalse);
      expect(
        DateTimeUtils.timeRemainingUntilCutoff(instant: before),
        const Duration(seconds: 1),
      );
      expect(
        DateTimeUtils.targetDeliveryDate(instant: before),
        DateTime(2027, 1, 1),
      );
      expect(DateTimeUtils.isAfterCutoffToday(instant: cutoff), isTrue);
      expect(
        DateTimeUtils.targetDeliveryDate(instant: cutoff),
        DateTime(2027, 1, 2),
      );
      expect(
        DateTimeUtils.nextCutoffIst(instant: cutoff),
        DateTime.utc(2027, 1, 1, 15, 30),
      );
      final midnightInIndia = DateTime.utc(2027, 1, 1, 18, 30);
      expect(
        DateTimeUtils.targetDeliveryDate(instant: midnightInIndia),
        DateTime(2027, 1, 3),
      );
    });

    test('urgency starts at 20:30 IST, not one second earlier', () {
      final start = DateTime.utc(2026, 11, 12, 15);
      expect(
        DateTimeUtils.isCutoffUrgent(
          instant: start.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(DateTimeUtils.isCutoffUrgent(instant: start), isTrue);
    });

    test('bag labels include cluster initials and a two-digit bag number', () {
      expect(DateTimeUtils.generateBagToken('Sri Sai PG', 3), '#SS-04');
      expect(
        DateTimeUtils.generateBagToken('Kakatiya Girls Hostel', 8),
        '#KG-09',
      );
    });
  });

  group('2. WhatsApp Deep Link & Gate Alert Formatter', () {
    test('ticket and drop links use the app scheme', () {
      final ticketLink = WhatsAppLinkHelper.getTicketDeepLink('tkt_999');
      expect(ticketLink, equals('hungr://ticket/tkt_999'));

      final dropLink = WhatsAppLinkHelper.getBagTokenDeepLink('#SS-04');
      expect(dropLink, equals('hungr://drop/SS-04'));
    });

    test('gate message includes recipient, bag, shelf and ticket link', () {
      final message = WhatsAppLinkHelper.formatGateDropMessage(
        customerName: 'Rahul',
        bagToken: '#SS-04',
        clusterName: 'Sri Sai PG Watchman Desk',
        shelfDetail: 'Shelf 4',
        ticketId: 'tkt_12345',
      );

      expect(message.contains('#SS-04'), isTrue);
      expect(message.contains('Sri Sai PG Watchman Desk'), isTrue);
      expect(message, contains('Rahul'));
      expect(message, contains('Shelf 4'));
      expect(message.contains('hungr://ticket/tkt_12345'), isTrue);
    });
  });

  group('3. Cart & Roommate Companion Meal Engine', () {
    test(
      'companion meal additions update total and calculate fuel-consolidation savings',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final cartNotifier = container.read(cartViewModelProvider.notifier);
        expect(container.read(cartProvider).roommateMealCount, equals(0));

        cartNotifier.addRoommateMeal();
        cartNotifier.addRoommateMeal();
        final state = container.read(cartProvider);
        expect(state.roommateMealCount, equals(2));
        expect(state.totalPayable, equals(90)); // 2 * 45
        expect(state.savingsAmount, equals(28)); // 2 * 14
      },
    );

    test('toggleAutoRotatePassMenu updates state correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final cartNotifier = container.read(cartViewModelProvider.notifier);
      expect(container.read(cartProvider).autoRotatePassMenu, isTrue);

      cartNotifier.toggleAutoRotatePassMenu(false);
      expect(container.read(cartProvider).autoRotatePassMenu, isFalse);

      cartNotifier.toggleAutoRotatePassMenu(true);
      expect(container.read(cartProvider).autoRotatePassMenu, isTrue);
    });
  });

  group('4. In-memory catalog updates (no Firestore connection)', () {
    ProviderContainer offlineCatalog() => ProviderContainer(
          overrides: [
            tiffinShopsProvider.overrideWith(
              (_) => TiffinShopsViewModel(
                catalogStream: const Stream<List<TiffinShop>>.empty(),
              ),
            ),
          ],
        );

    test(
      'ShopSyncService updates shop status and emits live ops event',
      () async {
        final container = offlineCatalog();
        addTearDown(container.dispose);

        final syncService = container.read(shopSyncServiceProvider);
        final nextEvent = syncService.eventStream.first;

        // Verify initial state
        final shopsInitial = container.read(tiffinShopsProvider);
        final balaCorner = shopsInitial.firstWhere(
          (s) => s.id == 'shop_bala_corner',
        );
        expect(balaCorner.status, equals(ShopStatus.closedToday));

        // Ops Admin marks shop OPEN
        syncService.applyShopStatusUpdate(
          shopId: 'shop_bala_corner',
          status: ShopStatus.open,
        );

        final shopsUpdated = container.read(tiffinShopsProvider);
        final balaUpdated = shopsUpdated.firstWhere(
          (s) => s.id == 'shop_bala_corner',
        );
        expect(balaUpdated.status, equals(ShopStatus.open));
        expect(balaUpdated.isOpen, isTrue);

        final event = await nextEvent;
        expect(event.action, equals(OpsSyncAction.statusChange));
        expect(event.description, contains('Open'));
      },
    );

    test('ShopSyncService updates item price dynamically', () async {
      final container = offlineCatalog();
      addTearDown(container.dispose);

      final syncService = container.read(shopSyncServiceProvider);
      syncService.applyDishPriceUpdate(
        shopId: 'shop_venkateshwara',
        itemId: 'item_set_dosa',
        newPrice: 55,
      );

      final shops = container.read(tiffinShopsProvider);
      final venkateshwara = shops.firstWhere(
        (s) => s.id == 'shop_venkateshwara',
      );
      final setDosa = venkateshwara.menuItems.firstWhere(
        (i) => i.id == 'item_set_dosa',
      );
      expect(setDosa.price, equals(55));
    });
  });
}
