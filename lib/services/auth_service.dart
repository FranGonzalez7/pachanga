import 'package:firebase_auth/firebase_auth.dart';
import 'firestore_service.dart';
import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // El "canal de radio": emite quién está logueado y reacciona a los cambios
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // El usuario actual ahora mismo (o null si no hay nadie)
  User? get currentUser => _auth.currentUser;

  // REGISTRO: crear una cuenta nueva con nombre, correo y contraseña
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

  // LOGIN: iniciar sesión con una cuenta que ya existe
  Future<User?> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user;
  }

  // LOGOUT: cerrar la sesión actual
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
