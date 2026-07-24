import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  SettingsScreen({super.key});

  final AuthService _authService = AuthService();

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
