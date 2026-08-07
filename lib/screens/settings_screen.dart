import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'co_captains_screen.dart';
import 'profile_screen.dart';

// Stateful desde el bloque de co-capitanes: Ajustes necesita saber QUIÉN eres
// (tu membresía) para decidir si muestra la entrada "Nombrar co-capitanes",
// que es exclusiva del capitán (ni siquiera de los co-capitanes).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Membership? _membership;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final uid = _authService.currentUser!.uid;
    final membership = await _firestoreService.getUserMembership(uid);
    if (mounted) {
      setState(() => _membership = membership);
    }
  }

  // Cerrar sesión no es destructivo (no se pierde nada), pero está en una
  // lista donde es fácil tocar por error: confirmamos.
  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Cerramos ESTA pantalla antes de salir. El AuthGate cambiará a login
    // al detectar el cierre de sesión, pero Ajustes está apilada encima y
    // taparía el cambio hasta que el usuario retrocediera a mano.
    if (context.mounted) Navigator.of(context).pop();
    await _authService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    // Solo EL capitán ve la entrada de co-capitanes. Mientras la membresía
    // carga, _membership es null y la entrada simplemente no está (aparece
    // al cargar; es un parpadeo mínimo y solo lo nota el capitán).
    final isCaptain = _membership?.isCaptain ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTheme.kGreen),
            title: const Text('Mi perfil'),
            subtitle: const Text('Foto, nombre y datos personales'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          if (isCaptain) ...[
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.workspace_premium_outlined,
                color: AppTheme.kGreen,
              ),
              title: const Text('Nombrar co-capitanes'),
              subtitle: const Text('Reparte la gestión del grupo'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        CoCaptainsScreen(captainMembership: _membership!),
                  ),
                );
              },
            ),
          ],
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión'),
            onTap: () => _confirmSignOut(context),
          ),
        ],
      ),
    );
  }
}
