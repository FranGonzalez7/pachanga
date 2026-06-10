import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/membership.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Future<Membership?>? _membershipFuture;
  String? _loadedUid; // de qué usuario es la consulta guardada

  void refresh() {
    setState(() {
      final uid = _authService.currentUser?.uid;
      if (uid != null) {
        _membershipFuture = _firestoreService.getUserMembership(uid);
        _loadedUid = uid;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authSnapshot.hasData) {
          // No hay usuario: limpiamos cualquier consulta previa
          _membershipFuture = null;
          _loadedUid = null;
          return const LoginScreen();
        }

        final uid = authSnapshot.data!.uid;

        // Si la consulta guardada es de otro usuario (o no existe), la rehacemos
        if (_loadedUid != uid) {
          _membershipFuture = _firestoreService.getUserMembership(uid);
          _loadedUid = uid;
        }

        return FutureBuilder<Membership?>(
          future: _membershipFuture,
          builder: (context, membershipSnapshot) {
            if (membershipSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (membershipSnapshot.hasData && membershipSnapshot.data != null) {
              return const HomeScreen();
            } else {
              return WelcomeScreen(onGroupJoined: refresh);
            }
          },
        );
      },
    );
  }
}
