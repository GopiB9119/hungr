import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungr/core/services/local_storage_service.dart';
import 'package:hungr/features/onboarding/domain/cluster_model.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/customer_dashboard_viewmodel.dart';
import 'package:hungr/features/subscription/presentation/screens/refer_and_earn_screen.dart';
import 'package:hungr/features/subscription/presentation/viewmodels/referral_viewmodel.dart';
import 'package:hungr/features/subscription/presentation/viewmodels/subscription_history_viewmodel.dart';
import 'package:hungr/features/ticket_calendar/data/ticket_repository.dart';
import 'package:hungr/features/ticket_calendar/presentation/screens/ticket_calendar_screen.dart';

const _cachedGate = DeliveryCluster(
  id: 'fixture-gate', name: 'Selected gate', addressZone: 'Campus', landmark: 'Desk',
  currentSubscribers: 3, maxCapacity: 8, latitude: 1.25, longitude: 2.5,
);

class _LegacyPreferences extends Fake implements LocalStorageService {
  _LegacyPreferences({this.delayedRead});
  final Completer<DeliveryCluster?>? delayedRead;

  @override
  Future<DeliveryCluster?> getSavedGate() => delayedRead?.future ?? Future.value(_cachedGate);

  @override
  Future<Map<String, dynamic>?> getSavedPassState() async => {
    'hasActivePass': true, 'tier': 'routine7Day', 'totalMeals': 7,
    'mealsRemaining': 5, 'tomorrowCombo': 'B',
  };
}

void main() {
  late ProviderContainer container;
  setUp(() {
    container = ProviderContainer(overrides: [
      customerDashboardProvider.overrideWith((ref) => CustomerDashboardViewModel(storage: _LegacyPreferences())),
    ]);
  });
  tearDown(() => container.dispose());

  test('restoring a gate does not restore a simulated pass, tickets or receipts', () async {
    expect(container.read(customerDashboardProvider).hasActivePass, isFalse);
    expect(container.read(customerDashboardProvider).tickets, isEmpty);
    await Future<void>.delayed(Duration.zero);
    final restored = container.read(customerDashboardProvider);
    expect(restored.selectedCluster.toMap(), _cachedGate.toMap());
    expect(restored.hasActivePass, isFalse);
    expect(restored.activeTier, isNull);
    expect(restored.mealsRemaining, 0);
    expect(restored.tickets, isEmpty);
    expect(container.read(subscriptionHistoryProvider).orders, isEmpty);
    await expectLater(container.read(ticketRepositoryProvider).fetchActiveUserTickets('fixture-user'),
        throwsA(isA<UnsupportedError>()));
  });

  test('a late cached gate cannot replace a gate already confirmed by auth', () async {
    final pending = Completer<DeliveryCluster?>();
    final delayed = ProviderContainer(overrides: [
      customerDashboardProvider.overrideWith(
        (ref) => CustomerDashboardViewModel(storage: _LegacyPreferences(delayedRead: pending)),
      ),
    ]);
    addTearDown(delayed.dispose);
    const confirmed = DeliveryCluster(
      id: 'new-gate', name: 'Confirmed gate', addressZone: 'South', landmark: 'New entrance',
      currentSubscribers: 5, maxCapacity: 10, latitude: 4.5, longitude: 5.75,
    );
    delayed.read(customerDashboardProvider.notifier).updateCluster(confirmed);
    pending.complete(_cachedGate);
    await pending.future;
    expect(delayed.read(customerDashboardProvider).selectedCluster.toMap(), confirmed.toMap());
  });

  testWidgets('a ticket or bag link alone cannot verify a drop', (tester) async {
    for (final screen in [
      const TicketCalendarScreen(),
      const TicketCalendarScreen(highlightTicketId: 'fixture-ticket'),
      const TicketCalendarScreen(highlightToken: 'fixture-bag'),
    ]) {
      await tester.pumpWidget(UncontrolledProviderScope(container: container, child: MaterialApp(home: screen)));
      await tester.pumpAndSettle();
      final linked = screen.highlightToken != null || screen.highlightTicketId != null;
      expect(find.text(linked ? 'Delivery cannot be verified from this link.' : 'No verified meal tickets to show'),
          findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Active Pass Schedule'), findsNothing);
    }
  });

  testWidgets('referral screen offers no simulated orders or free-pass claim', (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container, child: const MaterialApp(home: ReferAndEarnScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Referral rewards unavailable'), findsOneWidget);
    expect(find.textContaining('Simulate'), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(container.read(referralProvider).qualifiedOrderCount, 0);
    expect(container.read(referralProvider).isRewardClaimed, isFalse);
    expect(container.read(subscriptionHistoryProvider).orders, isEmpty);
  });
}
