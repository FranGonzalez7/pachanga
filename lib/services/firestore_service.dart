import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import '../models/slot.dart';

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
      teamAScore: null,
      teamBScore: null,
      slots: _generateEmptySlots(teamSize),
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
}
