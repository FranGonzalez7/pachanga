import 'package:cloud_firestore/cloud_firestore.dart';
import 'slot.dart';
import '../logic/formations.dart';

class Match {
  // Valores que usamos para distinguir equipo en slot.team.
  static const String teamA = 'A';
  static const String teamB = 'B';

  final String matchId;
  final String groupId;
  final String type; // "5v5", "6v6"...
  final int teamSize; // 5, 6...
  final String status;
  final String createdBy;
  final DateTime scheduledAt;
  final DateTime createdAt;
  final String location;
  // Goles "a mano" por equipo: goles en propia del rival, ajustes de disputa...
  // Empiezan en 0. NO confundir con teamAScore (ese es el marcador total).
  final int teamAExtraGoals;
  final int teamBExtraGoals;
  // Formación táctica de cada equipo (nombre del catálogo, ej. "1-2-1").
  // Solo afecta a DÓNDE se dibujan las burbujas, nunca a la puntuación.
  final String formationA;
  final String formationB;
  final List<Slot> slots;
  final Map<String, int> goals; // playerId del jugador -> goles en este partido

  Match({
    required this.matchId,
    required this.groupId,
    required this.type,
    required this.teamSize,
    required this.status,
    required this.createdBy,
    required this.scheduledAt,
    required this.createdAt,
    this.location = '',
    this.teamAExtraGoals = 0,
    this.teamBExtraGoals = 0,
    this.formationA = '',
    this.formationB = '',
    required this.slots,
    required this.goals,
  });

  // --- Marcador DERIVADO: no se almacena, se calcula de los goles + el extra ---

  // Suma de goles de los jugadores de cada equipo (lo "con dueño").
  int get teamAGoalsFromPlayers {
    int total = 0;
    for (final slot in slots) {
      final pid = slot.playerId;
      if (slot.team == teamA && pid != null) {
        total += goals[pid] ?? 0;
      }
    }
    return total;
  }

  int get teamBGoalsFromPlayers {
    int total = 0;
    for (final slot in slots) {
      final pid = slot.playerId;
      if (slot.team == teamB && pid != null) {
        total += goals[pid] ?? 0;
      }
    }
    return total;
  }

  // Marcador final = goles de jugadores + goles "a mano".
  int get teamAScore => teamAGoalsFromPlayers + teamAExtraGoals;
  int get teamBScore => teamBGoalsFromPlayers + teamBExtraGoals;

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
      location: data['location'] as String? ?? '',
      // ?? 0 para que los partidos viejos (sin estos campos) no rompan.
      teamAExtraGoals: data['teamAExtraGoals'] as int? ?? 0,
      teamBExtraGoals: data['teamBExtraGoals'] as int? ?? 0,
      formationA:
          data['formationA'] as String? ??
          defaultFormationByType[data['type'] as String] ??
          '',
      formationB:
          data['formationB'] as String? ??
          defaultFormationByType[data['type'] as String] ??
          '',
      slots: (data['slots'] as List<dynamic>)
          .map((slotData) => Slot.fromMap(slotData as Map<String, dynamic>))
          .toList(),
      goals: Map<String, int>.from(data['goals'] ?? {}),
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
      'location': location,
      // OJO: ya NO escribimos teamAScore/teamBScore, son derivados.
      'teamAExtraGoals': teamAExtraGoals,
      'teamBExtraGoals': teamBExtraGoals,
      'formationA': formationA,
      'formationB': formationB,
      'slots': slots.map((slot) => slot.toMap()).toList(),
      'goals': goals,
    };
  }

  // Devuelve una copia del Match cambiando solo los campos indicados.
  Match copyWith({
    String? matchId,
    String? groupId,
    String? type,
    int? teamSize,
    String? status,
    String? createdBy,
    DateTime? scheduledAt,
    DateTime? createdAt,
    String? location,
    int? teamAExtraGoals,
    int? teamBExtraGoals,
    String? formationA,
    String? formationB,
    List<Slot>? slots,
    Map<String, int>? goals,
  }) {
    return Match(
      matchId: matchId ?? this.matchId,
      groupId: groupId ?? this.groupId,
      type: type ?? this.type,
      teamSize: teamSize ?? this.teamSize,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt ?? this.createdAt,
      location: location ?? this.location,
      teamAExtraGoals: teamAExtraGoals ?? this.teamAExtraGoals,
      teamBExtraGoals: teamBExtraGoals ?? this.teamBExtraGoals,
      formationA: formationA ?? this.formationA,
      formationB: formationB ?? this.formationB,
      slots: slots ?? this.slots,
      goals: goals ?? this.goals,
    );
  }
}
