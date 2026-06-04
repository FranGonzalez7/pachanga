import 'package:cloud_firestore/cloud_firestore.dart';
import 'slot.dart';

class Match {
  final String matchId;
  final String groupId;
  final String type; // "5v5", "6v6"...
  final int teamSize; // 5, 6...
  final String status; 
  final String createdBy;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final int? teamAScore; 
  final int? teamBScore;
  final List<Slot> slots; 

  Match({
    required this.matchId,
    required this.groupId,
    required this.type,
    required this.teamSize,
    required this.status,
    required this.createdBy,
    required this.scheduledAt,
    required this.createdAt,
    this.teamAScore,
    this.teamBScore,
    required this.slots,
  });

  factory Match.fromMap(String matchId, Map<String, dynamic> data) {
    return Match(
      matchId: matchId,
      groupId: data['groupId'] as String,
      type: data['type'] as String,
      teamSize: data['teamSize'] as int,
      status: data['status'] as String,
      createdBy: data['createdBy'] as String,
      scheduledAt: (data['scheduledAt'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      teamAScore: data['teamAScore'] as int?,
      teamBScore: data['teamBScore'] as int?,
      slots: (data['slots'] as List<dynamic>)
          .map((slotData) => Slot.fromMap(slotData as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'type': type,
      'teamSize': teamSize,
      'status': status,
      'createdBy': createdBy,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'createdAt': Timestamp.fromDate(createdAt),
      'teamAScore': teamAScore,
      'teamBScore': teamBScore,
      'slots': slots.map((slot) => slot.toMap()).toList(),
    };
  }
}
