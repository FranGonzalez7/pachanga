import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../logic/match_scoring.dart';

class FirestoreService {
  // Referencia a la base de datos
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Crea (o sobrescribe) el documento de un usuario en la colección 'users'
  Future<void> createUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Lee el documento de un usuario por su uid; devuelve null si no existe
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  // Genera un código aleatorio de 6 caracteres (letras mayúsculas y números)
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Crea un grupo nuevo y hace al creador capitán del mismo
  Future<Group> createGroup(String groupName, AppUser creator) async {
    // Referencia a un nuevo documento en 'groups' (genera el ID automáticamente)
    final groupRef = _db.collection('groups').doc();

    final group = Group(
      groupId: groupRef.id,
      name: groupName,
      joinCode: _generateJoinCode(),
      createdBy: creator.uid,
      createdAt: DateTime.now(),
    );

    // Guarda el grupo
    await groupRef.set(group.toMap());

    // Crea la membresía del creador como capitán
    final membership = Membership(
      userId: creator.uid,
      groupId: group.groupId,
      role: 'captain',
      displayName: creator.displayName,
      points: 100,
      goals: 0,
      wins: 0,
      losses: 0,
      matchesPlayed: 0,
      joinedAt: DateTime.now(),
    );

    await _db
        .collection('memberships')
        .doc('${creator.uid}_${group.groupId}')
        .set(membership.toMap());

    return group;
  }

  // Lee un grupo por su ID; devuelve null si no existe
  Future<Group?> getGroup(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromMap(doc.id, doc.data()!);
  }

  // Busca un grupo por su código y une al usuario como jugador.
  // Devuelve el grupo si se unió con éxito, o null si el código no existe.
  Future<Group?> joinGroupByCode(String joinCode, AppUser user) async {
    // Consulta: busca en 'groups' el documento cuyo joinCode coincida
    final query = await _db
        .collection('groups')
        .where('joinCode', isEqualTo: joinCode)
        .limit(1)
        .get();

    // Si no hay resultados, el código no existe
    if (query.docs.isEmpty) {
      return null;
    }

    // Reconstruimos el grupo a partir del documento encontrado
    final doc = query.docs.first;
    final group = Group.fromMap(doc.id, doc.data());

    // Creamos la membresía del usuario como jugador
    final membership = Membership(
      userId: user.uid,
      groupId: group.groupId,
      role: 'player',
      displayName: user.displayName,
      points: 100,
      goals: 0,
      wins: 0,
      losses: 0,
      matchesPlayed: 0,
      joinedAt: DateTime.now(),
    );

    await _db
        .collection('memberships')
        .doc('${user.uid}_${group.groupId}')
        .set(membership.toMap());

    return group;
  }

  // Devuelve la primera membresía del usuario, o null si no tiene ninguna.
  Future<Membership?> getUserMembership(String uid) async {
    final query = await _db
        .collection('memberships')
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return Membership.fromMap(query.docs.first.data());
  }

  // Obtiene la membresía del usuario y su grupo de una vez
  Future<({Membership membership, Group group})?> getUserMembershipAndGroup(
    String uid,
  ) async {
    final membership = await getUserMembership(uid);
    if (membership == null) return null;

    final group = await getGroup(membership.groupId);
    if (group == null) return null;

    return (membership: membership, group: group);
  }

  // Devuelve todas las membresías de un grupo (sus jugadores)
  Future<List<Membership>> getGroupMembers(String groupId) async {
    final query = await _db
        .collection('memberships')
        .where('groupId', isEqualTo: groupId)
        .get();

    return query.docs.map((doc) => Membership.fromMap(doc.data())).toList();
  }

  // Crea un partido nuevo en el grupo y devuelve el partido creado
  Future<Match> createMatch({
    required String groupId,
    required String type,
    required int teamSize,
    required DateTime scheduledAt,
    required String createdBy,
  }) async {
    final matchRef = _db.collection('matches').doc();

    final match = Match(
      matchId: matchRef.id,
      groupId: groupId,
      type: type,
      teamSize: teamSize,
      status: 'scheduled',
      createdBy: createdBy,
      scheduledAt: scheduledAt,
      createdAt: DateTime.now(),
      slots: _generateEmptySlots(teamSize),
      goals: {}, // inicialmente no hay goles registrados
    );

    await matchRef.set(match.toMap());
    return match;
  }

  // Genera los huecos vacíos: teamSize por cada equipo (A y B), sin posición
  List<Slot> _generateEmptySlots(int teamSize) {
    final slots = <Slot>[];
    for (final team in ['A', 'B']) {
      for (int i = 0; i < teamSize; i++) {
        slots.add(
          Slot(
            team: team,
            position: '', // vacía hasta que alguien se apunte y la elija
            playerId: null,
            playerName: null,
          ),
        );
      }
    }
    return slots;
  }

  // Apunta a un jugador a un hueco concreto del partido, con una posición
  Future<void> joinSlot({
    required String matchId,
    required int slotIndex,
    required String playerId,
    required String playerName,
    required String position,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final doc = await matchRef.get();
    if (!doc.exists) return;

    final match = Match.fromMap(doc.id, doc.data()!);
    final updatedSlots = List<Slot>.from(match.slots);

    // Primero: quitamos a este jugador de cualquier hueco que ya ocupara
    for (int i = 0; i < updatedSlots.length; i++) {
      if (updatedSlots[i].playerId == playerId) {
        updatedSlots[i] = updatedSlots[i].copyWith(
          clearPlayer: true,
          position: '',
        );
      }
    }

    // Después: lo colocamos en el hueco elegido
    updatedSlots[slotIndex] = updatedSlots[slotIndex].copyWith(
      playerId: playerId,
      playerName: playerName,
      position: position,
    );

    await matchRef.update({
      'slots': updatedSlots.map((slot) => slot.toMap()).toList(),
    });
  }

  // Devuelve los partidos de un grupo, ordenados por fecha
  Future<List<Match>> getGroupMatches(String groupId) async {
    final query = await _db
        .collection('matches')
        .where('groupId', isEqualTo: groupId)
        .orderBy('scheduledAt')
        .get();

    return query.docs.map((doc) => Match.fromMap(doc.id, doc.data())).toList();
  }

  // Igual que getGroupMatches pero en tiempo real: emite la lista entera
  // cada vez que cambia cualquier partido del grupo (estado, goles...).
  Stream<List<Match>> streamGroupMatches(String groupId) {
    return _db
        .collection('matches')
        .where('groupId', isEqualTo: groupId)
        .orderBy('scheduledAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Match.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Lee un partido por su ID
  Future<Match?> getMatch(String matchId) async {
    final doc = await _db.collection('matches').doc(matchId).get();
    if (!doc.exists) return null;
    return Match.fromMap(doc.id, doc.data()!);
  }

  // Saca a quien esté en un hueco (lo vacía)
  Future<void> leaveSlot({
    required String matchId,
    required int slotIndex,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final doc = await matchRef.get();
    if (!doc.exists) return;

    final match = Match.fromMap(doc.id, doc.data()!);
    final updatedSlots = List<Slot>.from(match.slots);
    updatedSlots[slotIndex] = updatedSlots[slotIndex].copyWith(
      clearPlayer: true,
      position: '',
    );

    await matchRef.update({
      'slots': updatedSlots.map((slot) => slot.toMap()).toList(),
    });
  }

  // Vacía todos los huecos de un partido (mantiene la estructura de equipos)
  Future<void> clearAllSlots(String matchId) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final doc = await matchRef.get();
    if (!doc.exists) return;

    final match = Match.fromMap(doc.id, doc.data()!);
    final clearedSlots = match.slots
        .map((slot) => slot.copyWith(clearPlayer: true, position: ''))
        .toList();

    await matchRef.update({
      'slots': clearedSlots.map((slot) => slot.toMap()).toList(),
    });
  }

  // Cambia el estado de un partido (scheduled, inProgress, played)
  Future<void> updateMatchStatus(String matchId, String status) async {
    await _db.collection('matches').doc(matchId).update({'status': status});
  }

  // Devuelve un partido de inProgress a scheduled para corregir la alineación.
  // La puntuación se reinicia, pero mantiene los slots: los jugadores siguen colocados, solo vuelven a ser
  // editables. Operación destructiva: la puntuación registrada se pierde.
  Future<void> revertMatchToScheduled(String matchId) async {
    await _db.collection('matches').doc(matchId).update({
      'status': 'scheduled',
      'goals': {}, // se borra toda la puntuación individual
      'teamAExtraGoals': 0,
      'teamBExtraGoals': 0,
    });
  }

  // Actualiza los goles de un jugador en un partido (cantidad puede ser +1 o -1)
  Future<void> updatePlayerGoals({
    required String matchId,
    required String playerId,
    required int newGoalCount,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    await matchRef.update({'goals.$playerId': newGoalCount});
  }

  // Actualiza los goles "extra" de cada equipo (goles en propia del rival, ajustes de disputa). NO son goles de ningún jugador concreto: solo suben o bajan el marcador del equipo sin tocar los puntos individuales.
  Future<void> updateTeamExtraGoals({
    required String matchId,
    required int teamAExtraGoals,
    required int teamBExtraGoals,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    await matchRef.update({
      'teamAExtraGoals': teamAExtraGoals,
      'teamBExtraGoals': teamBExtraGoals,
    });
  }

  // Termina un partido: calcula los puntos de cada jugador, actualiza sus
  // estadísticas (puntos, goles, victorias/derrotas, partidos jugados) y marca
  // el partido como 'played'. Todo en un batch atómico. Operación irreversible.
  Future<void> finishMatch(Match match) async {
    // Puntos de este partido (lógica pura).
    final pointsPerPlayer = calculateMatchPoints(match);

    final batch = _db.batch();

    // Marcador final, para determinar quién ganó/perdió.
    final scoreA = match.teamAScore;
    final scoreB = match.teamBScore;

    for (final slot in match.slots) {
      final playerId = slot.playerId;
      if (playerId == null) continue; // hueco vacío

      // Resultado de ESTE jugador según su equipo.
      final isTeamA = slot.team == Match.teamA;
      final myScore = isTeamA ? scoreA : scoreB;
      final rivalScore = isTeamA ? scoreB : scoreA;

      final didWin = myScore > rivalScore;
      final didLose = myScore < rivalScore;
      // (empate: ni una cosa ni la otra)

      final goalsScored = match.goals[playerId] ?? 0;
      final matchPoints = pointsPerPlayer[playerId] ?? 0;

      final membershipRef = _db
          .collection('memberships')
          .doc('${playerId}_${match.groupId}');

      final membershipDoc = await membershipRef.get();
      if (!membershipDoc.exists) continue;

      final membership = Membership.fromMap(membershipDoc.data()!);

      // Nuevos totales (puntos con suelo en 0; el resto solo suman).
      final newPoints = (membership.points + matchPoints).clamp(0, 1 << 31);
      final newGoals = membership.goals + goalsScored;
      final newWins = membership.wins + (didWin ? 1 : 0);
      final newLosses = membership.losses + (didLose ? 1 : 0);
      final newMatchesPlayed = membership.matchesPlayed + 1;

      batch.update(membershipRef, {
        'points': newPoints,
        'goals': newGoals,
        'wins': newWins,
        'losses': newLosses,
        'matchesPlayed': newMatchesPlayed,
      });
    }

    // El partido pasa a 'played'.
    final matchRef = _db.collection('matches').doc(match.matchId);
    batch.update(matchRef, {'status': 'played'});

    await batch.commit();
  }

  // Calcula la posición de un usuario en la clasificación del grupo por puntos.
  // Devuelve (posición, total de miembros). Posición 1 = líder.
  Future<({int position, int total})> getUserRanking(
    String userId,
    String groupId,
  ) async {
    final members = await getGroupMembers(groupId);

    // Ordenamos por puntos de mayor a menor.
    members.sort((a, b) => b.points.compareTo(a.points));

    // Buscamos en qué lugar cae el usuario.
    final index = members.indexWhere((m) => m.userId == userId);

    // index es 0-based; la posición para mostrar es index + 1.
    return (position: index + 1, total: members.length);
  }
}
