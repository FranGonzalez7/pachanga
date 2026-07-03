import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import 'settings_screen.dart';
import 'match_field_screen.dart';
import 'match_score_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  late final Future<({Membership membership, Group group})?> _dataFuture;

  @override
  void initState() {
    super.initState();
    final uid = _authService.currentUser!.uid;
    _dataFuture = _firestoreService.getUserMembershipAndGroup(uid);
  }

  void _showInviteCode(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código de invitación'),
        content: Text(
          'Comparte este código para que se unan al grupo:\n\n$code',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // Abre un partido en la pantalla que toque según su estado.
  void _openMatch(Match match, Membership membership) {
    final Widget destination;
    switch (match.status) {
      case 'inProgress':
      case 'played':
        destination = MatchScoreScreen(
          match: match,
          currentMembership: membership,
        );
        break;
      case 'scheduled':
      default:
        destination = MatchFieldScreen(
          match: match,
          currentMembership: membership,
        );
        break;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => destination));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({Membership membership, Group group})?>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            body: Center(child: Text('No se pudieron cargar los datos.')),
          );
        }

        final membership = snapshot.data!.membership;
        final group = snapshot.data!.group;
        final isCaptain = membership.role == 'captain';

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              if (isCaptain)
                IconButton(
                  icon: const Icon(Icons.person_add),
                  tooltip: 'Invitar',
                  onPressed: () => _showInviteCode(group.joinCode),
                ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Ajustes',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
            ],
          ),
          // SingleChildScrollView: el Home scrollea cuando el contenido
          // no cabe (tres bloques + saludo pueden pasarse en pantallas
          // pequeñas). Adiós a los Expanded, que no conviven con el scroll.
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${membership.displayName} 👋',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                // --- Bloque "tú": stats personales ---
                _buildStatsBlock(membership, group.groupId),
                const SizedBox(height: 24),

                // --- Bloque próximo partido ---
                const Text(
                  'Próximo partido',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildNextMatchSection(group.groupId, membership, isCaptain),
                const SizedBox(height: 24),

                // --- Bloque "el grupo": top 3 ---
                _buildTopThreeBlock(group.groupId, membership.userId),
              ],
            ),
          ),
        );
      },
    );
  }

  // Sección del próximo partido: stream en vivo (los huecos cambian).
  Widget _buildNextMatchSection(
    String groupId,
    Membership membership,
    bool isCaptain,
  ) {
    return StreamBuilder<List<Match>>(
      stream: _firestoreService.streamGroupMatches(groupId),
      builder: (context, matchSnap) {
        if (matchSnap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allMatches = matchSnap.data ?? [];
        // Próximo = primer partido PROGRAMADO (los que admiten apuntarse).
        final scheduled = allMatches
            .where((m) => m.status == 'scheduled')
            .toList();

        if (scheduled.isEmpty) {
          return _buildEmptyState(isCaptain);
        }

        return _buildNextMatchCard(scheduled.first, membership);
      },
    );
  }

  // Bloque "tú": puntos, posición en la clasificación y resumen personal.
  Widget _buildStatsBlock(Membership membership, String groupId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tus puntos',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    Text(
                      '${membership.points}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FutureBuilder<({int position, int total})>(
                  future: _firestoreService.getUserRanking(
                    membership.userId,
                    groupId,
                  ),
                  builder: (context, rankSnap) {
                    if (!rankSnap.hasData) {
                      return const SizedBox(
                        width: 60,
                        height: 40,
                        child: Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final rank = rankSnap.data!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Posición',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        Text(
                          '${rank.position}º',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'de ${rank.total}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem('Jugados', '${membership.matchesPlayed}'),
                _statItem('Ganados', '${membership.wins}'),
                _statItem('Perdidos', '${membership.losses}'),
                _statItem('Goles', '${membership.goals}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  // Bloque "el grupo": top 3 de la clasificación, tipo podio.
  Widget _buildTopThreeBlock(String groupId, String myUserId) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Clasificación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Membership>>(
              future: _firestoreService.getGroupRanking(groupId),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final ranking = snap.data!;
                if (ranking.isEmpty) {
                  return const Text('Aún no hay jugadores.');
                }

                final top = ranking.take(3).toList();

                return Column(
                  children: [
                    for (int i = 0; i < top.length; i++)
                      _podiumRow(i, top[i], top[i].userId == myUserId),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Una fila del podio: medalla según el puesto, nombre, puntos.
  Widget _podiumRow(int index, Membership member, bool isMe) {
    final medalColors = [
      const Color(0xFFFFD700), // oro
      const Color(0xFFC0C0C0), // plata
      const Color(0xFFCD7F32), // bronce
    ];
    final medalColor = medalColors[index];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: medalColor, size: 26),
          const SizedBox(width: 12),
          Text(
            '${index + 1}º',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${member.points} pts',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // Tarjeta del próximo partido: fecha, tipo, huecos, si estoy apuntado.
  Widget _buildNextMatchCard(Match match, Membership membership) {
    final amIn = match.slots.any((s) => s.playerId == membership.userId);

    final totalSlots = match.slots.length;
    final occupied = match.slots.where((s) => s.playerId != null).length;
    final freeSlots = totalSlots - occupied;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_soccer, size: 28),
                const SizedBox(width: 10),
                Text(
                  match.type,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                _statusChip(match.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _formatDate(match.scheduledAt),
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            // Lugar del partido, solo si tiene uno.
            if (match.location.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      match.location,
                      style: const TextStyle(fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.group, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  freeSlots > 0
                      ? '$freeSlots ${freeSlots == 1 ? "hueco libre" : "huecos libres"} de $totalSlots'
                      : 'Completo ($totalSlots jugadores)',
                  style: const TextStyle(fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (amIn)
              const Row(
                children: [
                  Icon(Icons.check_circle, size: 18, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Estás apuntado',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(amIn ? Icons.visibility : Icons.how_to_reg),
                label: Text(amIn ? 'Ver partido' : 'Apuntarme'),
                onPressed: () => _openMatch(match, membership),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isCaptain) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              isCaptain
                  ? 'No hay partidos programados.\nCrea uno desde la pestaña Partidos.'
                  : 'No hay partidos programados.\nTu capitán creará el próximo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    late final String label;
    late final Color color;
    switch (status) {
      case 'inProgress':
        label = 'En juego';
        color = Colors.orange;
        break;
      case 'played':
        label = 'Jugado';
        color = Colors.grey;
        break;
      case 'scheduled':
      default:
        label = 'Programado';
        color = Colors.green;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
