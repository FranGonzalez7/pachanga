import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'co_captains_screen.dart';
import 'profile_screen.dart';

// Stateful desde el bloque de co-capitanes: Ajustes necesita saber QUIÉN eres
// (tu membresía) para decidir si muestra las entradas exclusivas del capitán
// (nombrar co-capitanes, reglas y resetear puntuación).
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

  // Aviso breve al tocar una opción que aún no está lista.
  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Disponible pronto'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Solo EL capitán ve las entradas de gestión del grupo. Mientras la
    // membresía carga, _membership es null y esas entradas no están (aparecen
    // al cargar; es un parpadeo mínimo y solo lo nota el capitán).
    final isCaptain = _membership?.isCaptain ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // --- Cuenta ---
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

          // --- Gestión del grupo (solo capitán) ---
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
            _buildComingSoon(
              icon: Icons.tune,
              title: 'Cambiar reglas de puntuación',
              captainOnly: true,
            ),
            _buildComingSoon(
              icon: Icons.restart_alt,
              title: 'Resetear puntuación',
              captainOnly: true,
              // Acción destructiva: se marca en tono de peligro (teja) ya desde
              // ahora, para que se lea como "seria" cuando exista.
              danger: true,
            ),
          ],

          // --- Preferencias (futuras) ---
          const Divider(),
          _buildComingSoon(
            icon: Icons.dark_mode_outlined,
            title: 'Modo oscuro',
          ),
          _buildComingSoon(icon: Icons.language, title: 'Cambiar idioma'),
          _buildComingSoon(
            icon: Icons.notifications_outlined,
            title: 'Notificaciones',
          ),

          // --- Información (futura) ---
          const Divider(),
          _buildComingSoon(icon: Icons.info_outline, title: 'Acerca de'),

          // --- Sesión ---
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

  // Opción "próximamente": atenuada (icono y texto en tinta suave), subtítulo
  // que lo avisa, sin flecha ">" (no lleva a ningún sitio todavía), y un
  // SnackBar al tocarla. Así se distingue de un vistazo de las que ya funcionan.
  // danger: la pinta en tono teja (para acciones destructivas futuras).
  // captainOnly: añade la coletilla "Solo capitán" al subtítulo.
  Widget _buildComingSoon({
    required IconData icon,
    required String title,
    bool captainOnly = false,
    bool danger = false,
  }) {
    final color = danger ? AppTheme.kBrick : AppTheme.kInkSoft;
    final subtitle = captainOnly
        ? 'Próximamente · Solo capitán'
        : 'Próximamente';
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.kInkSoft),
      ),
      onTap: _showComingSoon,
    );
  }
}
