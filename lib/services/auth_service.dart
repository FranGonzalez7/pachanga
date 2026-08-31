import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Emite quién está logueado y reacciona a los cambios de sesión.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Usuario actual, o null si no hay sesión.
  User? get currentUser => _auth.currentUser;

  // Crea una cuenta nueva y su documento de usuario en Firestore.
  Future<User?> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      final appUser = AppUser(
        uid: user.uid,
        displayName: displayName,
        email: email,
        photoUrl: null,
        preferredPositions: [],
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(appUser);
    }

    return user;
  }

  // Inicia sesión con una cuenta existente.
  Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  // Cierra la sesión actual.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
