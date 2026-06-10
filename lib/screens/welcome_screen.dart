import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Crear un grupo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del grupo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _createGroup,
                    child: const Text('Crear grupo'),
                  ),
                  const SizedBox(height: 32),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('o'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Unirse a un grupo',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _joinCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código del grupo',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _joinGroup,
                    child: const Text('Unirse'),
                  ),
                ],
              ),
            ),
    );
  }
}
