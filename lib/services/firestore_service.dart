import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'dart:math';
import '../models/group.dart';
import '../models/membership.dart';

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
}
