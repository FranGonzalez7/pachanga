import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

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
}