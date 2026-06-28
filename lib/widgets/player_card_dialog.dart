import 'package:flutter/material.dart';
import '../models/membership.dart';
import '../models/app_user.dart';
import '../services/firestore_service.dart';

// Diálogo con las cartas de jugador, deslizables horizontalmente.
// Recibe la lista (en el orden actual) y el índice por el que empezar.
class PlayerCardDialog extends StatefulWidget {
  final List<Membership> players;
  final int initialIndex;

  const PlayerCardDialog({
    super.key,
    required this.players,
    required this.initialIndex,
  });

  // Helper para abrir el diálogo cómodamente desde cualquier pantalla.
  static Future<void> show(
    BuildContext context, {
    required List<Membership> players,
    required int initialIndex,
  }) {
    return showDialog(
      context: context,
      builder: (_) =>
          PlayerCardDialog(players: players, initialIndex: initialIndex),
    );
  }

  @override
  State<PlayerCardDialog> createState() => _PlayerCardDialogState();
}

class _PlayerCardDialogState extends State<PlayerCardDialog> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    // viewportFraction < 1 deja asomar las cartas vecinas a los lados.
    _pageController = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: 0.92,
    );
  }

  @override
  void dispose() {
    _pageController.dispose(); // los controllers hay que cerrarlos
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, // el fondo lo pone cada carta
      insetPadding: const EdgeInsets.symmetric(vertical: 40),
      child: SizedBox(
        height: 560, // alto fijo del cromo (forma vertical)
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.players.length,
          itemBuilder: (context, index) {
            return _PlayerCard(player: widget.players[index]);
          },
        ),
      ),
    );
  }
}

// Una carta individual. Pinta al instante lo que viene de Membership
// (nombre, puntos, stats) y lee el AppUser para foto y posiciones.
class _PlayerCard extends StatelessWidget {
  final Membership player;
  _PlayerCard({required this.player});

  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final isCaptain = player.role == 'captain';

    return Padding(
      // Separación entre cartas para que el "asomar" tenga aire.
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- Zona foto (placeholder por ahora) ---
              _buildAvatar(),
              const SizedBox(height: 16),

              // --- Nombre + rol ---
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
                isCaptain ? 'Capitán' : 'Jugador',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // --- Puntos (dato estrella) ---
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

              // --- Posiciones preferidas (leídas del AppUser) ---
              _buildPreferredPositions(),
              const Divider(height: 28),

              // --- Stats ---
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
      ),
    );
  }

  // Avatar: placeholder con iniciales (la foto vendrá del AppUser).
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
        // Sin foto: círculo con iniciales.
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

  // Posiciones preferidas del AppUser; placeholder si no hay.
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

        // Pequeños chips con cada posición preferida.
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
}
