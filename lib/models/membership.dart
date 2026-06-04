import 'package:cloud_firestore/cloud_firestore.dart';

class Membership {
  final String userId;
  final String groupId;
  final String role;
  final String displayName;
  final int points;
  final int goals;
  final int wins;
  final int losses;
  final int matchesPlayed;
  final DateTime joinedAt;

  Membership({
    required this.userId,
    required this.groupId,
    required this.role,
    required this.displayName,
    required this.points,
    required this.goals,
    required this.wins,
    required this.losses,
    required this.matchesPlayed,
    required this.joinedAt,
  });

  // De Firestore (Map) a objeto Membership
  factory Membership.fromMap(Map<String, dynamic> data) {
    return Membership(
      userId: data['userId'] as String,
      groupId: data['groupId'] as String,
      role: data['role'] as String,
      displayName: data['displayName'] as String,
      points: data['points'] as int,
      goals: data['goals'] as int,
      wins: data['wins'] as int,
      losses: data['losses'] as int,
      matchesPlayed: data['matchesPlayed'] as int,
      joinedAt: (data['joinedAt'] as Timestamp).toDate(),
    );
  }

  // De objeto Membership a Firestore (Map)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'groupId': groupId,
      'role': role,
      'displayName': displayName,
      'points': points,
      'goals': goals,
      'wins': wins,
      'losses': losses,
      'matchesPlayed': matchesPlayed,
      'joinedAt': Timestamp.fromDate(joinedAt),
    };
  }
}
