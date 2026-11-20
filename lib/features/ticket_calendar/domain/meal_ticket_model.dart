import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

enum TicketStatusType {
  scheduled,
  locked,
  skipped,
  delivered,
  missed,
}

enum MealSlotType {
  morning,
  evening,
}

class MealTicket {
  final String ticketId;
  final String passId;
  final String userId;
  final String clusterId;
  final String clusterName;
  final DateTime deliveryDate;
  final String comboSelection; // 'A' or 'B'
  final List<String> addOns; // ['addon_boiled_eggs', 'addon_filter_coffee']
  final MealSlotType slot;
  final String? assignedVendorId; // 'aunty_1' or 'aunty_2'
  final String? assignedDriverId;
  final TicketStatusType status;
  final String? replacementTicketId;
  final DateTime? missedAt;
  final String? missedPlacement;
  final String? dropProofPath;
  final DateTime? deliveredAt;
  final String bagToken; // e.g. '#SS-04'
  final String? specialtyName; // e.g. 'Rayalaseema Set Dosa'
  final int companionMeals; // Roommate companion meals

  const MealTicket({
    required this.ticketId,
    required this.passId,
    required this.userId,
    required this.clusterId,
    required this.clusterName,
    required this.deliveryDate,
    required this.comboSelection,
    this.addOns = const [],
    this.slot = MealSlotType.morning,
    this.assignedVendorId,
    this.assignedDriverId,
    this.status = TicketStatusType.scheduled,
    this.replacementTicketId,
    this.missedAt,
    this.missedPlacement,
    this.dropProofPath,
    this.deliveredAt,
    this.bagToken = '#TS-04',
    this.specialtyName,
    this.companionMeals = 0,
  });

  String get missedMessage => replacementTicketId?.isNotEmpty == true
      ? 'Missed - replacement meal added'
      : 'Missed';

  MealTicket copyWith({
    TicketStatusType? status,
    String? comboSelection,
    List<String>? addOns,
    String? assignedVendorId,
    String? assignedDriverId,
    String? replacementTicketId,
    DateTime? missedAt,
    String? missedPlacement,
    String? dropProofPath,
    DateTime? deliveredAt,
    String? bagToken,
    String? specialtyName,
    int? companionMeals,
  }) {
    return MealTicket(
      ticketId: ticketId,
      passId: passId,
      userId: userId,
      clusterId: clusterId,
      clusterName: clusterName,
      deliveryDate: deliveryDate,
      comboSelection: comboSelection ?? this.comboSelection,
      addOns: addOns ?? this.addOns,
      slot: slot,
      assignedVendorId: assignedVendorId ?? this.assignedVendorId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      status: status ?? this.status,
      replacementTicketId: replacementTicketId ?? this.replacementTicketId,
      missedAt: missedAt ?? this.missedAt,
      missedPlacement: missedPlacement ?? this.missedPlacement,
      dropProofPath: dropProofPath ?? this.dropProofPath,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      bagToken: bagToken ?? this.bagToken,
      specialtyName: specialtyName ?? this.specialtyName,
      companionMeals: companionMeals ?? this.companionMeals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ticketId': ticketId,
      'passId': passId,
      'userId': userId,
      'clusterId': clusterId,
      'clusterName': clusterName,
      'deliveryDate': deliveryDate.toIso8601String(),
      'comboSelection': comboSelection,
      'addOns': addOns,
      'slot': slot.name.toUpperCase(),
      'assignedVendorId': assignedVendorId,
      'assignedDriverId': assignedDriverId,
      'status': status.name.toUpperCase(),
      if (replacementTicketId != null) 'replacementTicketId': replacementTicketId,
      if (missedAt != null) 'missedAt': missedAt!.toIso8601String(),
      if (missedPlacement != null) 'missedPlacement': missedPlacement,
      'bagToken': bagToken,
      'specialtyName': specialtyName,
      'companionMeals': companionMeals,
      'dropProofPath': dropProofPath,
      'deliveredAt': deliveredAt?.toIso8601String(),
    };
  }

  factory MealTicket.fromMap(Map<String, dynamic> map) {
    return MealTicket(
      ticketId: map['ticketId'] as String,
      passId: map['passId'] as String,
      userId: map['userId'] as String,
      clusterId: map['clusterId'] as String,
      clusterName: (map['clusterName'] as String?) ?? 'Cluster Drop Point',
      deliveryDate: _date(map['deliveryDate']),
      comboSelection: map['comboSelection'] as String,
      addOns: List<String>.from((map['addOns'] as List<dynamic>?) ?? []),
      slot: (map['slot'] as String?) == 'EVENING' ? MealSlotType.evening : MealSlotType.morning,
      assignedVendorId: map['assignedVendorId'] as String?,
      assignedDriverId: map['assignedDriverId'] as String?,
      status: _parseStatus(map['status'] as String?),
      replacementTicketId: map['replacementTicketId'] as String?,
      missedAt: map['missedAt'] == null ? null : _date(map['missedAt']),
      missedPlacement: map['missedPlacement'] as String?,
      bagToken: map['bagToken'] as String? ?? '#TS-04',
      specialtyName: map['specialtyName'] as String?,
      companionMeals: map['companionMeals'] as int? ?? 0,
      dropProofPath: map['dropProofPath'] as String?,
      deliveredAt: map['deliveredAt'] != null ? _date(map['deliveredAt']) : null,
    );
  }

  static DateTime _date(Object? value) => value is Timestamp
      ? value.toDate().toUtc()
      : DateTime.parse(value as String);

  static TicketStatusType _parseStatus(String? statusStr) {
    switch (statusStr?.toUpperCase()) {
      case 'LOCKED':
        return TicketStatusType.locked;
      case 'SKIPPED':
        return TicketStatusType.skipped;
      case 'MISSED':
        return TicketStatusType.missed;
      case 'DELIVERED':
        return TicketStatusType.delivered;
      default:
        return TicketStatusType.scheduled;
    }
  }
}
