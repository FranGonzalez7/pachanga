import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/membership.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/player_avatar.dart';
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

  late final String _myUid;
  Membership? _myMembership; // mi membresía, para saber si soy capitán
  late Future<List<Membership>> _playersFuture;

  // Criterio de orden activo. Por defecto, por puntos.
  PlayerSort _sort = PlayerSort.points;

  bool get _isCaptain => _myMembership?.role == 'captain';

  @override
  void initState() {
    super.initState();
    _myUid = _authService.currentUser!.uid;
    _playersFuture = _loadPlayers();
  }

  Future<List<Membership>> _loadPlayers() async {
    final membership = await _firestoreService.getUserMembership(_myUid);
    if (mounted) {
      setState(() => _myMembership = membership);
    }
    if (membership == null) return [];
    return _firestoreService.getGroupMembers(membership.groupId);
  }

  // Recarga la lista (tras crear un fantasma, por ejemplo).
  void _refreshPlayers() {
    setState(() {
      _playersFuture = _loadPlayers();
    });
  }

  // Ordena la lista según el criterio activo. Trabaja sobre una copia
  // para no mutar la lista original que viene del Future.
  List<Membership> _sortedPlayers(List<Membership> players) {
    final list = List<Membership>.from(players);
    switch (_sort) {
      case PlayerSort.points:
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
        list.sort(
          (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
        );
        break;
    }
    return list;
  }

  // Diálogo para crear un jugador fantasma: pide el nombre.
  Future<void> _openCreateGhost() async {
    final controller = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo jugador sin cuenta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Crea un jugador para alguien que no usa la app. '
              'Podrás colocarlo en los partidos como a cualquier otro.',
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
              if (text.isEmpty) return; // no creamos sin nombre
              Navigator.of(context).pop(text);
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;
    if (_myMembership == null) return;

    await _firestoreService.createGhostPlayer(
      groupId: _myMembership!.groupId,
      displayName: name,
    );

    _refreshPlayers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle('Jugadores'),
        actions: [
          PopupMenuButton<PlayerSort>(
            icon: const Icon(Icons.sort),
            tooltip: 'Ordenar',
            initialValue: _sort,
            onSelected: (value) {
              setState(() => _sort = value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: PlayerSort.points,
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Puntos'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: PlayerSort.goals,
                child: Row(
                  children: [
                    Icon(Icons.sports_soccer, size: 20),
                    SizedBox(width: 12),
                    Text('Goles'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: PlayerSort.name,
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, size: 20),
                    SizedBox(width: 12),
                    Text('Nombre'),
                  ],
                ),
              ),
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

          final players = _sortedPlayers(snapshot.data!);

          return ListView.builder(
            // 88 despeja el FAB; + la cenefa para que el último jugador no
            // quede pisado. La lista pasa por detrás al scrollear.
            padding: EdgeInsets.only(
              bottom: 88 + AppTheme.grassStripHeight(context),
            ),
            itemCount: players.length,
            itemBuilder: (context, index) {
              final player = players[index];
              final isCaptain = player.role == 'captain';
              final isMe = player.userId == _myUid;

              return Container(
                // "Esto eres tú": resaltado en ámbar, coherente con el podio.
                color: isMe ? AppTheme.kAmber.withValues(alpha: 0.15) : null,
                child: ListTile(
                  onTap: () => PlayerCardDialog.show(
                    context,
                    players: players,
                    initialIndex: index,
                    myUserId: _myUid,
                    viewerIsCaptain: _isCaptain,
                    onChanged: _refreshPlayers,
                  ),
                  // Avatar circular con borde verde, 10% mayor que antes.
                  // El borde lo dibuja el propio PlayerAvatar.
                  leading: PlayerAvatar(
                    photoUrl: player.photoUrl,
                    name: player.displayName,
                    size: 48,
                    borderColor: AppTheme.kGreen,
                  ),
                  title: Text(player.displayName),
                  subtitle: _buildSubtitle(player, isCaptain),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.kInkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: _isCaptain
          ? Padding(
              // Subimos el FAB por encima de la cenefa de césped.
              padding: EdgeInsets.only(
                bottom: AppTheme.grassStripHeight(context),
              ),
              child: FloatingActionButton.extended(
                onPressed: _openCreateGhost,
                icon: const Icon(Icons.person_add),
                label: const Text('Añadir jugador'),
              ),
            )
          : null,
    );
  }

  // Subtítulo de la fila: distingue capitán (con estrella), jugador y fantasma.
  Widget _buildSubtitle(Membership player, bool isCaptain) {
    if (player.isGhost) {
      return const Text('Sin cuenta');
    }
    if (isCaptain) {
      // "Capitán" con una estrella ámbar detrás.
      return Row(
        children: [
          const Text('Capitán'),
          const SizedBox(width: 4),
          Icon(Icons.star, size: 14, color: AppTheme.kAmber),
        ],
      );
    }
    return const Text('Jugador');
  }
}
