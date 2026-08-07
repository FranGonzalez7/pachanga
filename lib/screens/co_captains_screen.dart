import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';

// Pantalla donde EL capitán nombra o retira co-capitanes con un switch.
// Solo se llega aquí desde Ajustes, y la entrada solo la ve el capitán.
class CoCaptainsScreen extends StatefulWidget {
  final Membership captainMembership;

  const CoCaptainsScreen({super.key, required this.captainMembership});

  @override
  State<CoCaptainsScreen> createState() => _CoCaptainsScreenState();
}

class _CoCaptainsScreenState extends State<CoCaptainsScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  List<Membership> _candidates = [];
  bool _loading = true;
  // Ids con guardado en curso: bloquea SU switch mientras escribe (evita
  // dobles toques), sin congelar la pantalla entera.
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  // Carga los miembros y se queda con los candidatos a co-capitán:
  // fuera el propio capitán (no se auto-nombra) y fuera los fantasmas
  // (sin cuenta no hay quien ejerza el rol). Orden alfabético: en una
  // lista de gestión se busca por nombre, no por puntos.
  Future<void> _loadCandidates() async {
    final members = await _firestoreService.getGroupMembers(
      widget.captainMembership.groupId,
    );
    final candidates = members.where((m) => !m.isCaptain && !m.isGhost).toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
    if (mounted) {
      setState(() {
        _candidates = candidates;
        _loading = false;
      });
    }
  }

  // Cambia el rol de un miembro: co-capitán (on) o jugador (off).
  Future<void> _setCoCaptain(Membership member, bool makeCoCaptain) async {
    setState(() => _saving.add(member.userId));

    final newRole = makeCoCaptain
        ? Membership.roleCoCaptain
        : Membership.rolePlayer;

    await _firestoreService.setMemberRole(
      userId: member.userId,
      groupId: member.groupId,
      role: newRole,
    );

    // Recargamos la lista para pintar el estado real guardado en Firestore
    // (fuente de verdad), no el que creemos tener en memoria.
    final members = await _firestoreService.getGroupMembers(
      widget.captainMembership.groupId,
    );
    final candidates = members.where((m) => !m.isCaptain && !m.isGhost).toList()
      ..sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );

    if (mounted) {
      setState(() {
        _candidates = candidates;
        _saving.remove(member.userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nombrar co-capitanes')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _candidates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay jugadores con cuenta a los que nombrar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.kInkSoft),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Explicación breve de qué implica el rol.
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Los co-capitanes pueden gestionar partidos y jugadores '
                    'como tú, pero no nombrar a otros co-capitanes.',
                    style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
                  ),
                ),
                ..._candidates.map(_buildCandidateTile),
              ],
            ),
    );
  }

  Widget _buildCandidateTile(Membership member) {
    final isSaving = _saving.contains(member.userId);

    return SwitchListTile(
      value: member.isCoCaptain,
      // null desactiva el switch mientras se guarda (evita dobles toques).
      onChanged: isSaving ? null : (value) => _setCoCaptain(member, value),
      secondary: PlayerAvatar(
        photoUrl: member.photoUrl,
        name: member.displayName,
        size: 44,
        borderColor: AppTheme.kGreen,
      ),
      title: Text(member.displayName),
      // La estrella de plata asoma ya aquí: feedback inmediato del rol.
      subtitle: member.isCoCaptain
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Co-capitán'),
                SizedBox(width: 4),
                Icon(Icons.star, size: 14, color: Color(0xFFC0C0C0)),
              ],
            )
          : const Text('Jugador'),
      activeThumbColor: AppTheme.kGreen,
    );
  }
}
