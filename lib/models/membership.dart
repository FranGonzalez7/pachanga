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
  // Jugador fantasma: creado por el capitán, sin cuenta propia.
  // Por defecto false (los jugadores normales tienen cuenta).
  final bool isGhost;
  // Foto de perfil del jugador. Desnormalizada aquí (no solo en AppUser)
  // para pintar avatares sin lecturas extra, y para que los fantasmas
  // también puedan tener foto. null = sin foto (se usa el placeholder).
  final String? photoUrl;

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
    this.isGhost = false,
    this.photoUrl,
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
      // ?? false: las membresías viejas (sin el campo) son jugadores normales.
      isGhost: data['isGhost'] as bool? ?? false,
      photoUrl: data['photoUrl'] as String?,
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
      'isGhost': isGhost,
      'photoUrl': photoUrl,
    };
  }
}
