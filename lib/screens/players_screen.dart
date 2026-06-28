import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/membership.dart';
import '../widgets/player_card_dialog.dart';

// Criterios de ordenación disponibles para la lista de jugadores.
enum PlayerSort { points, goals, name }

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late final Future<List<Membership>> _playersFuture;

  // Criterio de orden activo. Por defecto, por puntos.
  PlayerSort _sort = PlayerSort.points;

  @override
  void initState() {
    super.initState();
    _playersFuture = _loadPlayers();
  }

  Future<List<Membership>> _loadPlayers() async {
    final uid = _authService.currentUser!.uid;
    final membership = await _firestoreService.getUserMembership(uid);
    if (membership == null) return [];
    return _firestoreService.getGroupMembers(membership.groupId);
  }

  // Ordena la lista según el criterio activo. Trabaja sobre una copia
  // para no mutar la lista original que viene del Future.
  List<Membership> _sortedPlayers(List<Membership> players) {
    final list = List<Membership>.from(players);
    switch (_sort) {
      case PlayerSort.points:
        // Puntos desc, desempate por goles desc.
        list.sort((a, b) {
          final byPoints = b.points.compareTo(a.points);
          if (byPoints != 0) return byPoints;
          return b.goals.compareTo(a.goals);
        });
        break;
      case PlayerSort.goals:
        list.sort((a, b) => b.goals.compareTo(a.goals));
        break;
      case PlayerSort.name:
        // Alfabético, ignorando mayúsculas/minúsculas.
        list.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        break;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jugadores'),
        actions: [
          PopupMenuButton<PlayerSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (value) {
              setState(() => _sort = value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: PlayerSort.points, child: Text('Puntos')),
              PopupMenuItem(value: PlayerSort.goals, child: Text('Goles')),
              PopupMenuItem(value: PlayerSort.name, child: Text('Nombre')),
            ],
          ),
        ],
      ),
      body: FutureBuilder<List<Membership>>(
        future: _playersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay jugadores todavía.'));
          }

          // Ordenamos en memoria según el criterio activo.
          final players = _sortedPlayers(snapshot.data!);

          return ListView.builder(
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              final isCaptain = player.role == 'captain';

              return ListTile(
                onTap: () => PlayerCardDialog.show(
                  context,
                  players: players,
                  initialIndex: index,
                ),
                leading: CircleAvatar(
                  child: Text(
                    player.displayName.isNotEmpty
                        ? player.displayName[0].toUpperCase()
                        : '?',
                  ),
                ),
                title: Text(player.displayName),
                subtitle: Text(isCaptain ? 'Capitán' : 'Jugador'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${player.points} pts',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${player.goals} ${player.goals == 1 ? "gol" : "goles"}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
