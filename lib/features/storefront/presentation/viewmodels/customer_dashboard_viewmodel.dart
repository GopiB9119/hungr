import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _clusterConfirmed = false;

  CustomerDashboardViewModel({LocalStorageService? storage})
      : _storage = storage ?? LocalStorageService.instance,
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

  bool togglePauseTicket(String ticketId) {
    final index = state.tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return false;

    final updatedTickets = List<MealTicket>.from(state.tickets);
    final target = updatedTickets[index];

    if (target.status == TicketStatusType.scheduled) {
      updatedTickets[index] = target.copyWith(status: TicketStatusType.skipped);
      final lastDate = updatedTickets.last.deliveryDate;
      final appendedDate = lastDate.add(const Duration(days: 1));

      final replacementTicket = MealTicket(
        ticketId: 't_rep_${DateTime.now().millisecondsSinceEpoch}',
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
      updatedTickets[index] = target.copyWith(status: TicketStatusType.scheduled);
      if (updatedTickets.length > state.totalMeals) {
        updatedTickets.removeLast();
      }
    }

    state = state.copyWith(tickets: updatedTickets);
    return true;
  }

  void switchTicketCombo(String ticketId, String newCombo) {
    final index = state.tickets.indexWhere((t) => t.ticketId == ticketId);
    if (index == -1) return;

    final updatedTickets = List<MealTicket>.from(state.tickets);
    updatedTickets[index] = updatedTickets[index].copyWith(comboSelection: newCombo);

    if (index == 0) {
      state = state.copyWith(tomorrowCombo: newCombo, tickets: updatedTickets);
    } else {
      state = state.copyWith(tickets: updatedTickets);
    }
  }

  void switchTomorrowCombo(String newCombo) {
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
    if (!DateTimeUtils.canModifyTomorrowMeal()) {
      return false; // Cutoff passed
    }

    if (state.tickets.isEmpty) return false;

    final updatedTickets = List<MealTicket>.from(state.tickets);
    final skipped = updatedTickets[0].copyWith(status: TicketStatusType.skipped);
    updatedTickets[0] = skipped;

    // Append new ticket at the tail
    final lastDate = updatedTickets.last.deliveryDate;
    final appendedDate = lastDate.add(const Duration(days: 1));

    final newTicket = MealTicket(
      ticketId: 't_${DateTime.now().millisecondsSinceEpoch}',
      passId: skipped.passId,
      userId: skipped.userId,
      clusterId: skipped.clusterId,
      clusterName: skipped.clusterName,
      deliveryDate: appendedDate,
      comboSelection: skipped.comboSelection,
      addOns: skipped.addOns,
      slot: skipped.slot,
      status: TicketStatusType.scheduled,
    );

    updatedTickets.add(newTicket);

    state = state.copyWith(
      tickets: updatedTickets,
    );
    return true;
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
