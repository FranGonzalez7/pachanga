import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

// Diálogo con las cartas de jugador, deslizables horizontalmente.
class PlayerCardDialog extends StatefulWidget {
  final List<Membership> players;
  final int initialIndex;
  final String myUserId;
  final bool viewerIsCaptain;
  final VoidCallback? onChanged;

  const PlayerCardDialog({
    super.key,
    required this.players,
    required this.initialIndex,
    required this.myUserId,
    required this.viewerIsCaptain,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Membership> players,
    required int initialIndex,
    required String myUserId,
    required bool viewerIsCaptain,
    VoidCallback? onChanged,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PlayerCardDialog(
        players: players,
        initialIndex: initialIndex,
        myUserId: myUserId,
        viewerIsCaptain: viewerIsCaptain,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<PlayerCardDialog> createState() => _PlayerCardDialogState();
}

class _PlayerCardDialogState extends State<PlayerCardDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.92,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Confirma y elimina a un jugador. La llama la carta desde su botón.
  Future<void> _confirmDelete(Membership player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar jugador'),
        content: Text(
          '¿Seguro que quieres eliminar a ${player.displayName} del grupo? '
          'Sus estadísticas se perderán. Los partidos ya jugados no se '
          'modifican. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _firestoreService.removeMembership(
      userId: player.userId,
      groupId: player.groupId,
    );

    if (!mounted) return;
    // Cerramos el diálogo entero y avisamos a la lista para que refresque.
    Navigator.of(context).pop();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(vertical: 40),
      child: SizedBox(
        height: 560,
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.players.length,
          itemBuilder: (context, index) {
            final player = widget.players[index];
            // El capitán puede borrar a otros (no a sí mismo).
            final canDelete =
                widget.viewerIsCaptain && player.userId != widget.myUserId;
            return _PlayerCard(
              player: player,
              canDelete: canDelete,
              onDelete: () => _confirmDelete(player),
            );
          },
        ),
      ),
    );
  }
}

// Una carta individual. Muestra los datos del jugador y, si procede,
// un botón de borrar en la esquina superior derecha.
class _PlayerCard extends StatelessWidget {
  final Membership player;
  final bool canDelete;
  final VoidCallback onDelete;

  _PlayerCard({
    required this.player,
    required this.canDelete,
    required this.onDelete,
  });

  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Stack: la carta debajo, el botón de borrar flotando en la esquina.
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAvatar(),
                  const SizedBox(height: 16),
                  Text(
                    player.displayName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _roleLabel(),
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${player.points}',
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    'puntos',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildPreferredPositions(),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('Jugados', '${player.matchesPlayed}'),
                      _stat('Ganados', '${player.wins}'),
                      _stat('Perdidos', '${player.losses}'),
                      _stat('Goles', '${player.goals}'),
                    ],
                  ),
                ],
              ),
            ),
            // Botón de borrar, solo si el capitán mira a otro jugador.
            if (canDelete)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Eliminar jugador',
                  onPressed: onDelete,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return FutureBuilder<AppUser?>(
      future: _firestoreService.getUser(player.userId),
      builder: (context, snap) {
        final photoUrl = snap.data?.photoUrl;
        if (photoUrl != null && photoUrl.isNotEmpty) {
          return CircleAvatar(
            radius: 44,
            backgroundImage: NetworkImage(photoUrl),
          );
        }
        return CircleAvatar(
          radius: 44,
          child: Text(
            _initials(player.displayName),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }

  Widget _buildPreferredPositions() {
    return FutureBuilder<AppUser?>(
      future: _firestoreService.getUser(player.userId),
      builder: (context, snap) {
        final positions = snap.data?.preferredPositions ?? [];

        if (positions.isEmpty) {
          return Text(
            'Sin posiciones preferidas',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: positions
              .map(
                (pos) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(pos, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _roleLabel() {
    if (player.isGhost) return 'Sin cuenta';
    return player.role == 'captain' ? 'Capitán' : 'Jugador';
  }
}