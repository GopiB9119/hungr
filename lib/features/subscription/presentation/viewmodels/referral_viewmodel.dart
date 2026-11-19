import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReferralFriend {
  final String name;
  final String cluster;
  final String status;
  final bool hasOrdered;

  const ReferralFriend({
    required this.name,
    required this.cluster,
    required this.status,
    required this.hasOrdered,
  });

  ReferralFriend copyWith({
    String? name,
    String? cluster,
    String? status,
    bool? hasOrdered,
  }) {
    return ReferralFriend(
      name: name ?? this.name,
      cluster: cluster ?? this.cluster,
      status: status ?? this.status,
      hasOrdered: hasOrdered ?? this.hasOrdered,
    );
  }
}

class ReferralState {
  final String? referralCode;
  final int targetCount; // Always 3 members
  final bool isRewardClaimed;
  final List<ReferralFriend> friends;

  const ReferralState({
    required this.referralCode,
    this.targetCount = 3,
    required this.isRewardClaimed,
    required this.friends,
  });

  /// Qualified referrals count strictly requires the friend to complete their 1st order
  int get qualifiedOrderCount => friends.where((f) => f.hasOrdered).length;

  /// Total friends who signed up with user's link
  int get totalInvitedCount => friends.length;

  /// Friends who registered but haven't placed their first morning drop yet
  int get pendingOrdersCount => friends.where((f) => !f.hasOrdered).length;

  bool get isRewardUnlocked => qualifiedOrderCount >= targetCount;
  int get remainingOrdersNeeded => (targetCount - qualifiedOrderCount).clamp(0, targetCount);
  double get progressRatio => (qualifiedOrderCount / targetCount).clamp(0.0, 1.0);

  ReferralState copyWith({
    String? referralCode,
    int? targetCount,
    bool? isRewardClaimed,
    List<ReferralFriend>? friends,
  }) {
    return ReferralState(
      referralCode: referralCode ?? this.referralCode,
      targetCount: targetCount ?? this.targetCount,
      isRewardClaimed: isRewardClaimed ?? this.isRewardClaimed,
      friends: friends ?? this.friends,
    );
  }
}

// No account-scoped referral ledger is connected. Older local counters were
// populated by simulation and must never unlock a customer pass.
final referralProvider = Provider<ReferralState>(
  (ref) => const ReferralState(referralCode: null, isRewardClaimed: false, friends: []),
);
