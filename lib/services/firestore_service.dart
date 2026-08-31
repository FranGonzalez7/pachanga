import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../logic/match_scoring.dart';
import '../logic/formations.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Crea o sobrescribe el documento de un usuario.
  Future<void> createUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  // Lee un usuario por su uid; null si no existe.
  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(uid, doc.data()!);
  }

  // Código de invitación: 6 caracteres alfanuméricos en mayúsculas.
  String _generateJoinCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(
      6,
      (index) => chars[random.nextInt(chars.length)],
    ).join();
  }

  // Crea un grupo y hace capitán a su creador.
  Future<Group> createGroup(String groupName, AppUser creator) async {
    final groupRef = _db.collection('groups').doc();

    final group = Group(
      groupId: groupRef.id,
      name: groupName,
      joinCode: _generateJoinCode(),
      createdBy: creator.uid,
      createdAt: DateTime.now(),
    );

    await groupRef.set(group.toMap());

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

  // Lee un grupo por su ID; null si no existe.
  Future<Group?> getGroup(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return Group.fromMap(doc.id, doc.data()!);
  }

  // Une al usuario a un grupo por su código. Devuelve el grupo, o null si el
  // código no existe.
  Future<Group?> joinGroupByCode(String joinCode, AppUser user) async {
    final query = await _db
        .collection('groups')
        .where('joinCode', isEqualTo: joinCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final group = Group.fromMap(doc.id, doc.data());

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

  // Primera membresía del usuario, o null si no tiene ninguna.
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

  // Membresía del usuario y su grupo de una vez.
  Future<({Membership membership, Group group})?> getUserMembershipAndGroup(
    String uid,
  ) async {
    final membership = await getUserMembership(uid);
    if (membership == null) return null;

    final group = await getGroup(membership.groupId);
    if (group == null) return null;

    return (membership: membership, group: group);
  }

  // Todas las membresías de un grupo (sus jugadores).
  Future<List<Membership>> getGroupMembers(String groupId) async {
    final query = await _db
        .collection('memberships')
        .where('groupId', isEqualTo: groupId)
        .get();

    return query.docs.map((doc) => Membership.fromMap(doc.data())).toList();
  }

  // Crea un partido nuevo en el grupo y lo devuelve.
  Future<Match> createMatch({
    required String groupId,
    required String type,
    required int teamSize,
    required DateTime scheduledAt,
    required String createdBy,
    String location = '',
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
      location: location,
      formationA: defaultFormationByType[type] ?? '',
      formationB: defaultFormationByType[type] ?? '',
      slots: _generateEmptySlots(teamSize),
      goals: {},
    );

    await matchRef.set(match.toMap());
    return match;
  }

  // Huecos vacíos: teamSize por equipo (A y B), sin posición asignada.
  List<Slot> _generateEmptySlots(int teamSize) {
    final slots = <Slot>[];
    for (final team in ['A', 'B']) {
      for (int i = 0; i < teamSize; i++) {
        slots.add(
          Slot(team: team, position: '', playerId: null, playerName: null),
        );
      }
    }
    return slots;
  }

  // Coloca a un jugador en un hueco concreto, con su posición.
  Future<void> joinSlot({
    required String matchId,
    required int slotIndex,
    required String playerId,
    required String playerName,
    required String position,
    String? photoUrl,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final doc = await matchRef.get();
    if (!doc.exists) return;

    final match = Match.fromMap(doc.id, doc.data()!);
    final updatedSlots = List<Slot>.from(match.slots);

    // Lo quitamos de cualquier hueco que ya ocupara antes de recolocarlo.
    for (int i = 0; i < updatedSlots.length; i++) {
      if (updatedSlots[i].playerId == playerId) {
        updatedSlots[i] = updatedSlots[i].copyWith(
          clearPlayer: true,
          position: '',
        );
      }
    }

    updatedSlots[slotIndex] = updatedSlots[slotIndex].copyWith(
      playerId: playerId,
      playerName: playerName,
      photoUrl: photoUrl,
      position: position,
    );

    await matchRef.update({
      'slots': updatedSlots.map((slot) => slot.toMap()).toList(),
    });
  }

  // Partidos de un grupo, ordenados por fecha.
  Future<List<Match>> getGroupMatches(String groupId) async {
    final query = await _db
        .collection('matches')
        .where('groupId', isEqualTo: groupId)
        .orderBy('scheduledAt')
        .get();

    return query.docs.map((doc) => Match.fromMap(doc.id, doc.data())).toList();
  }

  // Como getGroupMatches pero en tiempo real: reemite la lista ante cualquier
  // cambio en los partidos del grupo (estado, goles...).
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

  // Lee un partido por su ID.
  Future<Match?> getMatch(String matchId) async {
    final doc = await _db.collection('matches').doc(matchId).get();
    if (!doc.exists) return null;
    return Match.fromMap(doc.id, doc.data()!);
  }

  // Vacía un hueco concreto.
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

  // Vacía todos los huecos de un partido (mantiene la estructura de equipos).
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

  // Cambia la formación de un equipo (el otro nunca se toca). Con keepPlayers
  // en false vacía los huecos de ese equipo en la misma escritura, para no
  // dejar un estado intermedio con la formación nueva y los jugadores en la
  // vieja; con keepPlayers en true los conserva (los slots ya van en orden y el
  // render los recoloca). Solo en partidos scheduled: red de seguridad, ya que
  // la interfaz limita el botón pero el servicio no se fía.
  Future<void> setTeamFormation({
    required String matchId,
    required String team,
    required String formation,
    bool keepPlayers = false,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    final doc = await matchRef.get();
    if (!doc.exists) return;

    final match = Match.fromMap(doc.id, doc.data()!);

    if (match.status != 'scheduled') {
      throw Exception(
        'Solo se puede cambiar la formación de un partido programado.',
      );
    }

    final formationField = team == Match.teamA ? 'formationA' : 'formationB';

    if (keepPlayers) {
      await matchRef.update({formationField: formation});
      return;
    }

    final updatedSlots = match.slots.map((slot) {
      if (slot.team == team) {
        return slot.copyWith(clearPlayer: true, position: '');
      }
      return slot;
    }).toList();

    await matchRef.update({
      formationField: formation,
      'slots': updatedSlots.map((s) => s.toMap()).toList(),
    });
  }

  // Cambia el estado de un partido (scheduled, inProgress, played).
  Future<void> updateMatchStatus(String matchId, String status) async {
    await _db.collection('matches').doc(matchId).update({'status': status});
  }

  // Devuelve un partido de inProgress a scheduled para reeditar la alineación.
  // Conserva los slots pero borra la puntuación: operación destructiva.
  Future<void> revertMatchToScheduled(String matchId) async {
    await _db.collection('matches').doc(matchId).update({
      'status': 'scheduled',
      'goals': {},
      'teamAExtraGoals': 0,
      'teamBExtraGoals': 0,
    });
  }

  // Fija los goles de un jugador en un partido.
  Future<void> updatePlayerGoals({
    required String matchId,
    required String playerId,
    required int newGoalCount,
  }) async {
    final matchRef = _db.collection('matches').doc(matchId);
    await matchRef.update({'goals.$playerId': newGoalCount});
  }

  // Goles "extra" de cada equipo (goles en propia del rival, ajustes de
  // disputa). No pertenecen a ningún jugador: mueven el marcador del equipo
  // sin tocar los puntos individuales.
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
  // estadísticas y marca el partido como 'played'. Todo en un batch atómico e
  // irreversible.
  Future<void> finishMatch(Match match) async {
    final pointsPerPlayer = calculateMatchPoints(match);

    final batch = _db.batch();

    final scoreA = match.teamAScore;
    final scoreB = match.teamBScore;

    for (final slot in match.slots) {
      final playerId = slot.playerId;
      if (playerId == null) continue;

      // Resultado de este jugador según su equipo (empate = ni gana ni pierde).
      final isTeamA = slot.team == Match.teamA;
      final myScore = isTeamA ? scoreA : scoreB;
      final rivalScore = isTeamA ? scoreB : scoreA;

      final didWin = myScore > rivalScore;
      final didLose = myScore < rivalScore;

      final goalsScored = match.goals[playerId] ?? 0;
      final matchPoints = pointsPerPlayer[playerId] ?? 0;

      final membershipRef = _db
          .collection('memberships')
          .doc('${playerId}_${match.groupId}');

      final membershipDoc = await membershipRef.get();
      if (!membershipDoc.exists) continue;

      final membership = Membership.fromMap(membershipDoc.data()!);

      // Puntos con suelo en 0; el resto de totales solo suman.
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

    final matchRef = _db.collection('matches').doc(match.matchId);
    batch.update(matchRef, {'status': 'played'});

    await batch.commit();
  }

  // Posición del usuario en la clasificación del grupo por puntos. Devuelve
  // (posición, total); posición 1 = líder.
  Future<({int position, int total})> getUserRanking(
    String userId,
    String groupId,
  ) async {
    final members = await getGroupMembers(groupId);

    members.sort((a, b) => b.points.compareTo(a.points));

    final index = members.indexWhere((m) => m.userId == userId);

    // index es 0-based; la posición a mostrar es index + 1.
    return (position: index + 1, total: members.length);
  }

  // Miembros del grupo ordenados por puntos (desc), desempatando por goles.
  Future<List<Membership>> getGroupRanking(String groupId) async {
    final members = await getGroupMembers(groupId);

    members.sort((a, b) {
      final byPoints = b.points.compareTo(a.points);
      if (byPoints != 0) return byPoints;
      return b.goals.compareTo(a.goals);
    });

    return members;
  }

  // Crea un jugador fantasma: una membresía sin cuenta que crea el capitán para
  // alguien que no usa la app. Tiene un id propio (no de Auth), la puntuación
  // base y stats a 0.
  Future<Membership> createGhostPlayer({
    required String groupId,
    required String displayName,
  }) async {
    // Id automático de Firestore, ya que no hay uid de Auth.
    final ghostId = _db.collection('memberships').doc().id;

    final membership = Membership(
      userId: ghostId,
      groupId: groupId,
      role: 'player',
      displayName: displayName,
      points: 100,
      goals: 0,
      wins: 0,
      losses: 0,
      matchesPlayed: 0,
      joinedAt: DateTime.now(),
      isGhost: true,
    );

    await _db
        .collection('memberships')
        .doc('${ghostId}_$groupId')
        .set(membership.toMap());

    return membership;
  }

  // Cambia el rol de un miembro entre co-capitán y jugador. Al capitán no se le
  // toca desde aquí, y un fantasma no puede ser co-capitán (no tiene cuenta con
  // la que entrar): red de seguridad más allá de lo que ya limita la interfaz.
  Future<void> setMemberRole({
    required String userId,
    required String groupId,
    required String role,
  }) async {
    if (role != Membership.roleCoCaptain && role != Membership.rolePlayer) {
      throw Exception('Rol no permitido: $role');
    }

    final membershipRef = _db
        .collection('memberships')
        .doc('${userId}_$groupId');

    final doc = await membershipRef.get();
    if (!doc.exists) return;

    final member = Membership.fromMap(doc.data()!);

    if (member.isCaptain) {
      throw Exception('No se puede cambiar el rol del capitán.');
    }
    if (member.isGhost && role == Membership.roleCoCaptain) {
      throw Exception('Un jugador sin cuenta no puede ser co-capitán.');
    }

    await membershipRef.update({'role': role});
  }

  // Cambia el nombre de un usuario con cuenta en los tres sitios donde vive:
  // perfil global (users), membresía del grupo y playerName de los slots de sus
  // partidos. Batch atómico. Hermano de updateGhostName, salvo por el paso del
  // perfil global (un fantasma no lo tiene).
  Future<void> updateUserName({
    required String userId,
    required String groupId,
    required String newName,
  }) async {
    final batch = _db.batch();

    final userRef = _db.collection('users').doc(userId);
    batch.update(userRef, {'displayName': newName});

    final membershipRef = _db
        .collection('memberships')
        .doc('${userId}_$groupId');
    batch.update(membershipRef, {'displayName': newName});

    await _addPlayerNameUpdatesToBatch(
      batch: batch,
      userId: userId,
      groupId: groupId,
      newName: newName,
    );

    await batch.commit();
  }

  // Cambia el nombre de un fantasma en su membresía y en los slots de sus
  // partidos. Batch atómico.
  Future<void> updateGhostName({
    required String userId,
    required String groupId,
    required String newName,
  }) async {
    final batch = _db.batch();

    final membershipRef = _db
        .collection('memberships')
        .doc('${userId}_$groupId');
    batch.update(membershipRef, {'displayName': newName});

    await _addPlayerNameUpdatesToBatch(
      batch: batch,
      userId: userId,
      groupId: groupId,
      newName: newName,
    );

    await batch.commit();
  }

  // Añade a un batch (sin hacer commit) el cambio de playerName de un jugador
  // en los slots de todos sus partidos del grupo. Pieza reutilizable por
  // fantasmas y usuarios con cuenta.
  Future<void> _addPlayerNameUpdatesToBatch({
    required WriteBatch batch,
    required String userId,
    required String groupId,
    required String newName,
  }) async {
    // Todos los partidos, en cualquier estado: el nombre también se actualiza
    // en el histórico.
    final matches = await _db
        .collection('matches')
        .where('groupId', isEqualTo: groupId)
        .get();

    for (final doc in matches.docs) {
      final match = Match.fromMap(doc.id, doc.data());

      final isInMatch = match.slots.any((s) => s.playerId == userId);
      if (!isInMatch) continue;

      final updatedSlots = match.slots.map((slot) {
        if (slot.playerId == userId) {
          return slot.copyWith(playerName: newName);
        }
        return slot;
      }).toList();

      batch.update(doc.reference, {
        'slots': updatedSlots.map((s) => s.toMap()).toList(),
      });
    }
  }

  // Elimina la membresía de un jugador del grupo. Borrado suave: los partidos
  // jugados conservan su rastro; en los scheduled se libera el hueco que
  // ocupaba; los inProgress se dejan en paz (alineación congelada). Batch
  // atómico.
  Future<void> removeMembership({
    required String userId,
    required String groupId,
  }) async {
    final batch = _db.batch();

    final scheduledMatches = await _db
        .collection('matches')
        .where('groupId', isEqualTo: groupId)
        .where('status', isEqualTo: 'scheduled')
        .get();

    // En cada partido scheduled, si ocupa algún slot, lo liberamos.
    for (final doc in scheduledMatches.docs) {
      final match = Match.fromMap(doc.id, doc.data());

      final isInMatch = match.slots.any((s) => s.playerId == userId);
      if (!isInMatch) continue;

      final updatedSlots = match.slots.map((slot) {
        if (slot.playerId == userId) {
          return slot.copyWith(clearPlayer: true, position: '');
        }
        return slot;
      }).toList();

      batch.update(doc.reference, {
        'slots': updatedSlots.map((s) => s.toMap()).toList(),
      });
    }

    final membershipRef = _db
        .collection('memberships')
        .doc('${userId}_$groupId');
    batch.delete(membershipRef);

    await batch.commit();
  }

  // Elimina un partido, salvo que esté jugado (ya repartió puntos y borrarlo
  // dejaría stats huérfanas). La interfaz ya oculta la opción; esto es la red
  // de seguridad.
  Future<void> deleteMatch(String matchId) async {
    final doc = await _db.collection('matches').doc(matchId).get();
    if (!doc.exists) return;

    final status = doc.data()!['status'] as String;
    if (status == 'played') {
      throw Exception('No se puede eliminar un partido ya jugado.');
    }

    await _db.collection('matches').doc(matchId).delete();
  }

  // Actualiza lugar, fecha y hora de un partido. Solo si está scheduled.
  Future<void> updateMatchDetails({
    required String matchId,
    required DateTime scheduledAt,
    required String location,
  }) async {
    final doc = await _db.collection('matches').doc(matchId).get();
    if (!doc.exists) return;

    final status = doc.data()!['status'] as String;
    if (status != 'scheduled') {
      throw Exception('Solo se pueden editar partidos programados.');
    }

    await _db.collection('matches').doc(matchId).update({
      'scheduledAt': Timestamp.fromDate(scheduledAt),
      'location': location,
    });
  }

  // Sube una foto de perfil a Storage y guarda su URL en el Membership. Recibe
  // el archivo ya elegido por la UI. Ruta fija avatars/{userId}/avatar.jpg: cada
  // foto nueva sobrescribe la anterior, así no se acumula basura.
  Future<String> uploadProfilePhoto({
    required String userId,
    required String groupId,
    required File imageFile,
  }) async {
    final ref = _storage.ref().child('avatars/$userId/avatar.jpg');

    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));

    final downloadUrl = await ref.getDownloadURL();

    final membershipRef = _db
        .collection('memberships')
        .doc('${userId}_$groupId');
    await membershipRef.update({'photoUrl': downloadUrl});

    return downloadUrl;
  }
}
