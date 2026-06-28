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
  // (Mismo criterio de enrutamiento que la pantalla de Partidos.)
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
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${membership.displayName} 👋',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                // Bloque "tú": stats personales.
                _buildStatsBlock(membership, group.groupId),
                const SizedBox(height: 24),
                const Text(
                  'Próximo partido',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                // El bloque del próximo partido sí va en vivo: los huecos
                // cambian según la gente se apunta. StreamBuilder anidado.
                // El bloque del próximo partido sí va en vivo: los huecos cambian
                // según la gente se apunta. StreamBuilder anidado.
                StreamBuilder<List<Match>>(
                  stream: _firestoreService.streamGroupMatches(group.groupId),
                  builder: (context, matchSnap) {
                    if (matchSnap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final allMatches = matchSnap.data ?? [];
                    final scheduled = allMatches
                        .where((m) => m.status == 'scheduled')
                        .toList();

                    if (scheduled.isEmpty) {
                      // El caso vacío sí ocupa el resto del espacio (para centrarse).
                      return Expanded(child: _buildEmptyState(isCaptain));
                    }

                    // La tarjeta NO va en Expanded: se ajusta al alto de su contenido.
                    return _buildNextMatchCard(scheduled.first, membership);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tarjeta del próximo partido: fecha, tipo, huecos, si estoy apuntado.
  Widget _buildNextMatchCard(Match match, Membership membership) {
    // ¿Estoy apuntado? Hay algún slot cuyo playerId soy yo.
    final amIn = match.slots.any((s) => s.playerId == membership.userId);

    // Huecos: slots totales vs. ocupados.
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
            // Tipo de partido + estado.
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
            // Fecha.
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
            const SizedBox(height: 10),
            // Huecos.
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
            // Estado de apuntado: chip informativo.
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
            // Botón de acción: lleva al partido.
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

  // Caso sin próximos partidos: mensaje distinto según rol.
  Widget _buildEmptyState(bool isCaptain) {
    return Center(
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
            // Puntos grandes + posición.
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
                // Posición: se calcula con una lectura puntual (foto).
                FutureBuilder<({int position, int total})>(
                  future: _firestoreService.getUserRanking(
                    membership.userId,
                    groupId,
                  ),
                  builder: (context, rankSnap) {
                    if (!rankSnap.hasData) {
                      // Mientras carga, un hueco discreto para no saltar el layout.
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
            // Mini-resumen: jugados, victorias, derrotas, goles.
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

  // Una columna pequeña del mini-resumen: número grande + etiqueta.
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
}
