import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/business_rules.dart';
import '../../../../core/services/local_storage_service.dart';
import '../../../../core/utils/date_time_utils.dart';
import '../../../onboarding/domain/cluster_model.dart';
import '../../../ticket_calendar/domain/meal_ticket_model.dart';
import '../widgets/pass_card_3d.dart';

class CustomerDashboardState {
  final bool hasActivePass;
  final PassTierType? activeTier;
  final int mealsRemaining;
  final int totalMeals;
  final String tomorrowCombo; // 'A' or 'B'
  final Set<String> activeAddons;
  final DeliveryCluster selectedCluster;
  final List<MealTicket> tickets;
  final bool isRenewAlertActive;

  const CustomerDashboardState({
    required this.hasActivePass,
    required this.activeTier,
    required this.mealsRemaining,
    required this.totalMeals,
    required this.tomorrowCombo,
    required this.activeAddons,
    required this.selectedCluster,
    required this.tickets,
    required this.isRenewAlertActive,
  });

  CustomerDashboardState copyWith({
    bool? hasActivePass,
    PassTierType? activeTier,
    int? mealsRemaining,
    int? totalMeals,
    String? tomorrowCombo,
    Set<String>? activeAddons,
    DeliveryCluster? selectedCluster,
    List<MealTicket>? tickets,
    bool? isRenewAlertActive,
  }) {
    return CustomerDashboardState(
      hasActivePass: hasActivePass ?? this.hasActivePass,
      activeTier: activeTier ?? this.activeTier,
      mealsRemaining: mealsRemaining ?? this.mealsRemaining,
      totalMeals: totalMeals ?? this.totalMeals,
      tomorrowCombo: tomorrowCombo ?? this.tomorrowCombo,
      activeAddons: activeAddons ?? this.activeAddons,
      selectedCluster: selectedCluster ?? this.selectedCluster,
      tickets: tickets ?? this.tickets,
      isRenewAlertActive: isRenewAlertActive ?? this.isRenewAlertActive,
    );
  }
}

class CustomerDashboardViewModel extends StateNotifier<CustomerDashboardState> {
  final LocalStorageService _storage;
  final DateTime Function() _clock;
  bool _clusterConfirmed = false;

  CustomerDashboardViewModel({LocalStorageService? storage, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now,
        _storage = storage ?? LocalStorageService.instance,
        super(
          const CustomerDashboardState(
            hasActivePass: false,
            activeTier: null,
            mealsRemaining: 0,
            totalMeals: 0,
            tomorrowCombo: 'A',
            activeAddons: {},
            selectedCluster: DeliveryCluster(
              id: 'cluster_01',
              name: 'Sri Sai Boys Hostel Gate',
              addressZone: 'Bypass Road, Khammam',
              landmark: 'Near Bus Stand, Khammam',
              currentSubscribers: 36,
              maxCapacity: 50,
              latitude: 17.2473,
              longitude: 80.1514,
            ),
            tickets: [],
            isRenewAlertActive: false,
          ),
        ) {
    _loadSavedCluster();
  }

  // A gate preference can be restored locally. Pass counts from older clients
  // came from simulated purchases, not an account's verified entitlements.
  Future<void> _loadSavedCluster() async {
    final gate = await _storage.getSavedGate();
    if (mounted && !_clusterConfirmed && gate != null) {
      state = state.copyWith(selectedCluster: gate);
    }
  }

  // The dashboard action targets the first ticket; the calendar targets its own row.
  int get skipsLeft => state.tickets.isEmpty ? BusinessRules.maxSkipsPerPass : skipsLeftFor(state.tickets.first);

  int skipsLeftFor(MealTicket target) {
    final used = state.tickets.where((t) => t.status == TicketStatusType.skipped &&
        t.passId == target.passId && t.userId == target.userId).length;
    return used >= BusinessRules.maxSkipsPerPass ? 0 : BusinessRules.maxSkipsPerPass - used;
  }

  bool togglePauseTicket(String ticketId) {
    final index = state.tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return false;

    final updatedTickets = List<MealTicket>.from(state.tickets);
    final target = updatedTickets[index];

    if (target.status == TicketStatusType.scheduled) {
      if (!DateTimeUtils.canSkipMeal(target.deliveryDate, instant: _clock()) ||
          skipsLeftFor(target) == 0) {
        return false;
      }
      updatedTickets[index] = target.copyWith(status: TicketStatusType.skipped);
      final lastDate = updatedTickets.last.deliveryDate;
      final appendedDate = lastDate.add(const Duration(days: 1));

      final replacementTicket = MealTicket(
        ticketId: 't_pause_${target.ticketId}',
        passId: target.passId,
        userId: target.userId,
        clusterId: target.clusterId,
        clusterName: target.clusterName,
        deliveryDate: appendedDate,
        comboSelection: target.comboSelection,
        addOns: target.addOns,
        slot: target.slot,
        status: TicketStatusType.scheduled,
      );
      updatedTickets.add(replacementTicket);
    } else if (target.status == TicketStatusType.skipped) {
      // Resuming re-adds the meal to that day's kitchen order, so it closes at the same cutoff.
      if (!DateTimeUtils.canSkipMeal(target.deliveryDate, instant: _clock())) return false;
      // Only remove the ticket created by this local pause, never a server replacement.
      final replacementIndex = updatedTickets.indexWhere((t) =>
          t.ticketId == 't_pause_${target.ticketId}' && t.status == TicketStatusType.scheduled);
      if (replacementIndex < 0) return false;
      updatedTickets[index] = target.copyWith(status: TicketStatusType.scheduled);
      updatedTickets.removeAt(replacementIndex);
    } else {
      return false;
    }

    state = state.copyWith(tickets: updatedTickets);
    return true;
  }

  void switchTicketCombo(String ticketId, String newCombo) {
    final index = state.tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1 || state.tickets[index].status != TicketStatusType.scheduled) return;

    final updatedTickets = List<MealTicket>.from(state.tickets);
    updatedTickets[index] = updatedTickets[index].copyWith(comboSelection: newCombo);

    if (index == 0) {
      state = state.copyWith(tomorrowCombo: newCombo, tickets: updatedTickets);
    } else {
      state = state.copyWith(tickets: updatedTickets);
    }
  }

  void switchTomorrowCombo(String newCombo) {
    if (state.tickets.isNotEmpty && state.tickets.first.status != TicketStatusType.scheduled) return;
    if (!DateTimeUtils.canModifyTomorrowMeal()) {
      throw Exception('403_CUTOFF_PASSED: Cannot switch meal after 9:00 PM IST.');
    }

    final updatedTickets = List<MealTicket>.from(state.tickets);
    if (updatedTickets.isNotEmpty) {
      updatedTickets[0] = updatedTickets[0].copyWith(comboSelection: newCombo);
    }

    state = state.copyWith(
      tomorrowCombo: newCombo,
      tickets: updatedTickets,
    );
  }

  bool skipTomorrow() {
    if (state.tickets.isEmpty || state.tickets.first.status != TicketStatusType.scheduled) return false;
    return togglePauseTicket(state.tickets.first.ticketId);
  }

  void updateCluster(DeliveryCluster newCluster) {
    // Auth has persisted this gate. A startup read may still be in flight.
    _clusterConfirmed = true;
    state = state.copyWith(selectedCluster: newCluster);
  }
}

final customerDashboardProvider =
    StateNotifierProvider<CustomerDashboardViewModel, CustomerDashboardState>((ref) {
  return CustomerDashboardViewModel();
});
