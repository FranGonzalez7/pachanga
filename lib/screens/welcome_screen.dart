import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGroupJoined;
  const WelcomeScreen({super.key, required this.onGroupJoined});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _joinCodeController = TextEditingController();

  bool _isLoading = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Crea un grupo nuevo con el nombre introducido
  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      _showMessage('Escribe un nombre para el grupo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _authService.currentUser!.uid;
      final appUser = await _firestoreService.getUser(uid);
      await _firestoreService.createGroup(groupName, appUser!);
      widget.onGroupJoined(); // avisa al AuthGate para que refresque
      // No navegamos a mano: el AuthGate detectará el cambio (lo vemos luego)
    } catch (e) {
      _showMessage('No se pudo crear el grupo. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Une al usuario a un grupo existente mediante el código
  Future<void> _joinGroup() async {
    final code = _joinCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showMessage('Escribe el código del grupo.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uid = _authService.currentUser!.uid;
      final appUser = await _firestoreService.getUser(uid);
      final group = await _firestoreService.joinGroupByCode(code, appUser!);

      if (group == null) {
        _showMessage('No existe ningún grupo con ese código.');
      } else {
        widget.onGroupJoined(); // avisa al AuthGate para que refresque
      }
      // Si group no es null, el AuthGate detectará la nueva membresía
    } catch (e) {
      _showMessage('No se pudo unir al grupo. Inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bienvenido a Pachanga'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              // Mismo patrón que el login: forzamos la Column a ocupar toda
              // la altura disponible y centramos con Spacers. Centro estable
              // y, a la vez, scroll cuando el teclado reduce el espacio.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight -
                            64, // menos el padding vertical
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Spacer(),

                            // --- Crear un grupo ---
                            Text(
                              'Crear un grupo',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _groupNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre del grupo',
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _createGroup,
                              child: const Text('Crear grupo'),
                            ),

                            // --- Separador reforzado, con mucho aire ---
                            const SizedBox(height: 48),
                            Row(
                              children: [
                                Expanded(
                                  child: Divider(
                                    thickness: 1.5,
                                    color: AppTheme.kInk.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Icon(
                                    Icons.sports_soccer,
                                    size: 22,
                                    color: AppTheme.kGreen,
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    thickness: 1.5,
                                    color: AppTheme.kInk.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),

                            // --- Unirse a un grupo ---
                            Text(
                              'Unirse a un grupo',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _joinCodeController,
                              decoration: const InputDecoration(
                                labelText: 'Código del grupo',
                              ),
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _joinGroup,
                              child: const Text('Unirse'),
                            ),

                            const Spacer(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
