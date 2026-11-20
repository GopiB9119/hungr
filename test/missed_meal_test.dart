import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hungr/core/services/local_storage_service.dart';
import 'package:hungr/features/onboarding/domain/cluster_model.dart';
import 'package:hungr/features/storefront/presentation/viewmodels/customer_dashboard_viewmodel.dart';
import 'package:hungr/features/ticket_calendar/data/ticket_repository.dart';
import 'package:hungr/features/ticket_calendar/domain/meal_ticket_model.dart';

class _NoGate extends Fake implements LocalStorageService {
  @override
  Future<DeliveryCluster?> getSavedGate() async => null;
}

class FixtureDashboard extends CustomerDashboardViewModel {
  FixtureDashboard(List<MealTicket> tickets, {DateTime? instant})
      : super(storage: _NoGate(), clock: () => instant ?? DateTime.utc(2026, 11, 19, 10)) {
    state = state.copyWith(hasActivePass: true, tickets: tickets, totalMeals: 2, mealsRemaining: 2);
  }
  List<MealTicket> get tickets => state.tickets;
}

MealTicket fixtureTicket(String id, String status, {String? replacement, DateTime? day}) => MealTicket.fromMap({
  'ticketId': id, 'passId': 'pass', 'userId': 'user', 'clusterId': 'gate',
  'deliveryDate': day?.toIso8601String() ?? '2026-11-20', 'comboSelection': 'A', 'status': status,
  if (replacement != null) 'replacementTicketId': replacement,
});

void main() {
  test('Calendar pauses enforce the IST service day and cutoff', () {
    final before = DateTime.utc(2026, 11, 20, 15, 29, 59);
    final cutoff = before.add(const Duration(seconds: 1));
    final tomorrow = DateTime.utc(2026, 11, 20, 18, 30); // Midnight IST.
    for (final (now, day, allowed) in [
      (before, tomorrow, true), (cutoff, tomorrow, false),
      (before, tomorrow.subtract(const Duration(seconds: 1)), false),
      (before, DateTime.utc(2026, 11, 19), false),
    ]) {
      final ticket = fixtureTicket('meal', 'SCHEDULED', day: day);
      final vm = FixtureDashboard([ticket], instant: now);
      addTearDown(vm.dispose);
      expect(vm.togglePauseTicket('meal'), allowed, reason: 'now=$now, delivery=$day');
      if (!allowed) expect(vm.tickets, [ticket]);
    }
  });

  test('Skip allowance belongs to the target pass and customer', () {
    final meal = fixtureTicket('meal', 'SCHEDULED');
    final vm = FixtureDashboard([
      for (var i = 0; i < 3; i++)
        MealTicket.fromMap({...fixtureTicket('old$i', 'SKIPPED').toMap(), 'passId': 'other'}),
      for (var i = 0; i < 3; i++)
        MealTicket.fromMap({...fixtureTicket('user$i', 'SKIPPED').toMap(), 'userId': 'other'}),
      meal,
    ]);
    addTearDown(vm.dispose);
    expect(vm.togglePauseTicket('meal'), isTrue);
    expect(vm.skipsLeftFor(meal), 2);
  });

  test('Delivery proof round-trips as a Storage path', () {
    const path = 'delivery_proofs/meal/proof';
    final ticket = MealTicket.fromMap({...fixtureTicket('meal', 'DELIVERED').toMap(), 'dropProofPath': path});
    expect(ticket.copyWith().toMap()['dropProofPath'], path);
  });

  test('MISSED survives map and copy round trips with the server replacement link', () {
    final stamp = Timestamp.fromDate(DateTime.utc(2026, 11, 20, 1, 45));
    final source = MealTicket.fromMap({
      ...fixtureTicket('source', 'SCHEDULED').toMap(), 'status': 'MISSED',
      'replacementTicketId': 'next', 'missedPlacement': 'NEXT_DAY', 'missedAt': stamp,
      'specialtyName': 'Set Dosa', 'bagToken': '#SS-01', 'companionMeals': 1,
    });
    expect(source.status, TicketStatusType.missed);
    expect(source.replacementTicketId, 'next');
    final saved = source.copyWith().toMap();
    expect(saved['status'], 'MISSED');
    expect(saved['replacementTicketId'], 'next');
    final restored = MealTicket.fromMap(saved);
    expect(restored.missedAt!.toUtc(), stamp.toDate().toUtc());
    expect(restored.missedPlacement, 'NEXT_DAY');
    expect(restored.bagToken, '#SS-01');
    expect(restored.specialtyName, 'Set Dosa');
    expect(restored.companionMeals, 1);
    expect(fixtureTicket('next', 'SCHEDULED').replacementTicketId, isNull);
    expect(fixtureTicket('orphan', 'MISSED').missedMessage, 'Missed');
  });

  test('missed meals cannot be paused, resumed, switched or replaced by the client', () async {
    final missed = fixtureTicket('source', 'MISSED', replacement: 'next');
    final next = fixtureTicket('next', 'SCHEDULED');
    final vm = FixtureDashboard([missed, next]);
    addTearDown(vm.dispose);
    expect(vm.togglePauseTicket('source'), isFalse);
    expect(vm.skipTomorrow(), isFalse);
    vm.switchTicketCombo('source', 'B');
    vm.switchTomorrowCombo('B');
    expect(vm.tickets, [missed, next]);
    final repo = TicketRepository();
    await expectLater(repo.skipTomorrowTicket(ticketToSkip: missed,
      passHardExpiryDate: next.deliveryDate, currentQueueLastDate: next.deliveryDate), throwsStateError);
    await expectLater(repo.switchCombo(ticket: missed, newCombo: 'B'), throwsStateError);
  });

  test('resuming a paused meal never removes the replacement for a missed delivery', () {
    final paused = fixtureTicket('paused', 'SKIPPED');
    final missed = fixtureTicket('source', 'MISSED', replacement: 'next');
    final next = fixtureTicket('next', 'SCHEDULED');
    final vm = FixtureDashboard([paused, missed, next]);
    addTearDown(vm.dispose);
    expect(vm.togglePauseTicket('paused'), isFalse);
    expect(vm.tickets, [paused, missed, next]);
  });

  test('two local pauses can be resumed in any order without discarding another replacement', () {
    final one = fixtureTicket('one', 'SCHEDULED');
    final two = fixtureTicket('two', 'SCHEDULED');
    final vm = FixtureDashboard([one, two]);
    addTearDown(vm.dispose);
    expect(vm.togglePauseTicket('one'), isTrue);
    final replacementOne = vm.tickets.last;
    expect(vm.togglePauseTicket('two'), isTrue);
    final replacementTwo = vm.tickets.last;
    expect(vm.togglePauseTicket('one'), isTrue);
    expect(vm.tickets, isNot(contains(replacementOne)));
    expect(vm.tickets, contains(replacementTwo));
    expect(vm.tickets.first.status, TicketStatusType.scheduled);
  });

  test('a pass allows only 3 pauses at a time, like the server', () {
    final meals = [for (var i = 1; i <= 5; i++) fixtureTicket('m$i', 'SCHEDULED', day: DateTime(2026, 11, 20 + i))];
    final vm = FixtureDashboard(meals);
    addTearDown(vm.dispose);
    for (final id in ['m1', 'm2', 'm3']) {
      expect(vm.togglePauseTicket(id), isTrue, reason: id);
    }
    final before = List.of(vm.tickets);
    expect(vm.skipsLeft, 0);
    expect(vm.togglePauseTicket('m4'), isFalse);
    expect(vm.tickets, before);
    expect(vm.togglePauseTicket('m1'), isTrue);
    expect(vm.skipsLeft, 1);
    expect(vm.togglePauseTicket('m4'), isTrue);
  });

  test('resuming a paused meal also closes at the 9 PM IST cutoff', () {
    final paused = fixtureTicket('meal', 'SKIPPED'); // Tomorrow, 20 Nov.
    final replacement = fixtureTicket('t_pause_meal', 'SCHEDULED', day: DateTime(2026, 11, 21));
    final late = FixtureDashboard([paused, replacement], instant: DateTime.utc(2026, 11, 19, 15, 30)); // 21:00 IST.
    addTearDown(late.dispose);
    expect(late.togglePauseTicket('meal'), isFalse);
    expect(late.tickets, [paused, replacement]);
    final early = FixtureDashboard([paused, replacement]);
    addTearDown(early.dispose);
    expect(early.togglePauseTicket('meal'), isTrue);
    expect(early.tickets.single.status, TicketStatusType.scheduled);
  });
}
