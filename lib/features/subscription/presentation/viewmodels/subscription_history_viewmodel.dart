import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/subscription_order_model.dart';

class SubscriptionHistoryState {
  final List<SubscriptionOrder> orders;

  const SubscriptionHistoryState({required this.orders});
}

// Only account-scoped, verified receipts belong here; cart totals and
// local referral progress are not payment records.
final subscriptionHistoryProvider = Provider<SubscriptionHistoryState>(
  (ref) => const SubscriptionHistoryState(orders: []),
);
