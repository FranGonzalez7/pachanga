import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/group.dart';
import '../models/membership.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

// Pantalla de perfil: quién eres tú. Separada de Ajustes, que es
// configuración de la app. Aquí viven tu foto (bloque B), tu nombre y
// tus datos personales.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  // No es 'final': tras editar el nombre lo reasignamos para recargar.
  late Future<({Membership membership, Group group, AppUser? user})?>
  _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfile();
  }

  Future<({Membership membership, Group group, AppUser? user})?>
  _loadProfile() async {
    final uid = _authService.currentUser!.uid;
    final data = await _firestoreService.getUserMembershipAndGroup(uid);
    if (data == null) return null;
    final user = await _firestoreService.getUser(uid);
    return (membership: data.membership, group: data.group, user: user);
  }

  void _reload() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  // Diálogo para cambiar el nombre propio. Mismo patrón que el de los
  // fantasmas, para no inventar una interacción nueva.
  Future<void> _editName(Membership membership) async {
    final controller = TextEditingController(text: membership.displayName);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cambiar mi nombre'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu nombre se actualizará también en los partidos '
              'en los que apareces.',
              style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return; // no permitimos nombre vacío
              Navigator.of(context).pop(text);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    // Canceló, vacío, o el mismo nombre de antes: nada que hacer.
    if (newName == null || newName.isEmpty) return;
    if (newName == membership.displayName) return;

    try {
      await _firestoreService.updateUserName(
        userId: membership.userId,
        groupId: membership.groupId,
        newName: newName,
      );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cambiar el nombre.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body:
          FutureBuilder<({Membership membership, Group group, AppUser? user})?>(
            future: _profileFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(
                  child: Text('No se pudieron cargar tus datos.'),
                );
              }

              final membership = snapshot.data!.membership;
              final group = snapshot.data!.group;
              final user = snapshot.data!.user;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // --- Avatar (placeholder; la foto llega en el bloque B) ---
                    _buildAvatar(membership.displayName),
                    const SizedBox(height: 16),
                    Text(
                      membership.displayName,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      membership.role == 'captain' ? 'Capitán' : 'Jugador',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.kInkSoft,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // --- Datos ---
                    Card(
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.person_outline,
                              color: AppTheme.kGreen,
                            ),
                            title: const Text('Nombre'),
                            subtitle: Text(membership.displayName),
                            trailing: const Icon(Icons.edit_outlined, size: 20),
                            onTap: () => _editName(membership),
                          ),
                          if (user != null)
                            ListTile(
                              leading: const Icon(
                                Icons.mail_outline,
                                color: AppTheme.kGreen,
                              ),
                              title: const Text('Correo'),
                              subtitle: Text(user.email),
                            ),
                          ListTile(
                            leading: const Icon(
                              Icons.groups_outlined,
                              color: AppTheme.kGreen,
                            ),
                            title: const Text('Grupo'),
                            subtitle: Text(group.name),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  // Avatar circular: borde verde, interior crema, inicial en verde.
  // Mismo lenguaje visual que el avatar del Home.
  Widget _buildAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.kCreamCard,
        border: Border.all(color: AppTheme.kGreen, width: 4),
        boxShadow: [
          BoxShadow(
            color: AppTheme.kInk.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          color: AppTheme.kGreen,
        ),
      ),
    );
  }
}
