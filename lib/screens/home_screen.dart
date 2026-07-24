import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';
import '../widgets/app_bar_title.dart';
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
            title: const AppBarTitle('Pachanga'),
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
                // Saludo en dos líneas: nombre (cálido) y grupo (contexto).
                Text(
                  '¡Hola, ${membership.displayName}!',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Bienvenido a ${group.name}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.kInkSoft,
                  ),
                ),
                const SizedBox(height: 28),

                // --- Bloque "tú": stats personales (con avatar superpuesto) ---
                _buildStatsBlock(membership, group.groupId),
                const SizedBox(height: 20),

                // --- Bloque próximo partido ---
                _buildSectionCard(
                  title: 'Próximo partido',
                  child: _buildNextMatchSection(
                    group.groupId,
                    membership,
                    isCaptain,
                  ),
                ),
                const SizedBox(height: 20),

                // --- Bloque "el grupo": top 3 ---
                _buildSectionCard(
                  title: 'Clasificación',
                  child: _buildTopThreeContent(
                    group.groupId,
                    membership.userId,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Molde común de los bloques del Home: una Card con sombra y el título
  // "montado" sobre su borde superior izquierdo (etiqueta flotante estilo
  // fieldset). Unifica los tres bloques: comparten forma, elevación y titulado.
  Widget _buildSectionCard({required String title, required Widget child}) {
    // Fondo del título: colorScheme.surface, que es el color que Material 3
    // pinta DETRÁS del Scaffold. Ojo: NO scaffoldBackgroundColor, que en M3
    // no coincide con el fondo real y deja un rectángulo fantasma. Al tomar
    // el color de la misma fuente que el fondo, el parche es invisible y se
    // adapta solo al tema (modo oscuro incluido).
    final surface = Theme.of(context).colorScheme.surface;

    return Stack(
      clipBehavior: Clip.none, // deja que el título asome fuera de la Card
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            // top algo mayor: el contenido no debe chocar con el título.
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: child,
          ),
        ),
        // El título, a caballo del borde superior izquierdo.
        Positioned(
          top: -10,
          left: 16,
          child: Container(
            color: surface,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
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
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allMatches = matchSnap.data ?? [];
        // Próximo = primer partido PROGRAMADO cuyo día no haya pasado.
        // Los caducados siguen en la lista de Partidos (los limpia el capitán),
        // pero no deben ocupar el hueco de "próximo partido".
        final scheduled = allMatches
            .where((m) => m.status == 'scheduled' && !m.isPast)
            .toList();

        if (scheduled.isEmpty) {
          return _buildEmptyState(isCaptain);
        }

        return _buildNextMatchContent(scheduled.first, membership);
      },
    );
  }

  // Contenido del bloque "tú": puntos grandes, posición en línea y la fila
  // de stats menores. El avatar NO va aquí: lo superpone _buildStatsBlock
  // por encima de la tarjeta. Dejamos un padding derecho para que el número
  // no choque con el avatar que asoma por esa esquina.
  Widget _buildStatsContent(Membership membership, String groupId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          // Reservamos la esquina derecha para el avatar superpuesto.
          padding: const EdgeInsets.only(right: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mis puntos',
                style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
              ),
              Text(
                '${membership.points}',
                style: const TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              // Posición en una línea discreta, para que los puntos brillen.
              FutureBuilder<({int position, int total})>(
                future: _firestoreService.getUserRanking(
                  membership.userId,
                  groupId,
                ),
                builder: (context, rankSnap) {
                  if (!rankSnap.hasData) {
                    return const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final rank = rankSnap.data!;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      const Text(
                        'Posición ',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.kInkSoft,
                        ),
                      ),
                      Text(
                        '${rank.position}º',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' de ${rank.total}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.kInkSoft,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Divider(height: 28, color: AppTheme.kGreen.withValues(alpha: 0.65)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(Icons.stadium, 'Jugados', '${membership.matchesPlayed}'),
            _statItem(
              Icons.check_circle_outlined,
              'Ganados',
              '${membership.wins}',
            ),
            _statItem(Icons.highlight_off, 'Perdidos', '${membership.losses}'),
            _statItem(Icons.sports_soccer, 'Goles', '${membership.goals}'),
          ],
        ),
      ],
    );
  }

  // Envuelve la tarjeta de stats para superponerle el avatar por la esquina
  // superior derecha. El molde _buildSectionCard ya usa un Stack para su
  // título; aquí añadimos OTRA capa por encima solo para este bloque, sin
  // tocar el molde común (que comparten los otros dos bloques).
  Widget _buildStatsBlock(Membership membership, String groupId) {
    return Stack(
      clipBehavior: Clip.none, // deja que el avatar asome fuera de la tarjeta
      children: [
        _buildSectionCard(
          title: 'Mis estadísticas',
          child: _buildStatsContent(membership, groupId),
        ),
        // Avatar superpuesto: asoma un poco por arriba, apoyado en la tarjeta.
        Positioned(
          top: -18,
          right: 16,
          child: _buildAvatar(membership.displayName),
        ),
      ],
    );
  }

  // Avatar circular: borde verde, interior crema, inicial en verde.
  // Placeholder por ahora; el día de las fotos (plan Blaze) solo cambia
  // el contenido del círculo por la imagen.
  Widget _buildAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 112,
      height: 112,
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
          fontSize: 44,
          fontWeight: FontWeight.bold,
          color: AppTheme.kGreen,
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.kInkSoft),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.kInkSoft),
        ),
      ],
    );
  }

  // Contenido del bloque "el grupo": top 3 de la clasificación, tipo podio.
  Widget _buildTopThreeContent(String groupId, String myUserId) {
    return FutureBuilder<List<Membership>>(
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
    );
  }

  // Una fila del podio: medalla según el puesto, nombre, puntos.
  Widget _podiumRow(int index, Membership member, bool isMe) {
    // Medallas oro/plata/bronce: colores semánticos universales, NO de marca.
    // Se quedan hardcodeados a propósito (una medalla de oro es dorada).
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
        // "Esto eres tú": resaltado en ámbar, la seña de la paleta.
        color: isMe ? AppTheme.kAmber.withValues(alpha: 0.15) : null,
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

  // Contenido de la tarjeta del próximo partido: fecha, tipo, huecos, apuntado.
  Widget _buildNextMatchContent(Match match, Membership membership) {
    final amIn = match.slots.any((s) => s.playerId == membership.userId);

    final totalSlots = match.slots.length;
    final occupied = match.slots.where((s) => s.playerId != null).length;
    final freeSlots = totalSlots - occupied;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.sports_soccer, size: 28),
            const SizedBox(width: 10),
            Text(
              match.type,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            StatusChip(status: match.status),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: AppTheme.kInkSoft,
            ),
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
                color: AppTheme.kInkSoft,
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
            const Icon(Icons.group, size: 18, color: AppTheme.kInkSoft),
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
          Row(
            children: [
              Icon(Icons.check_circle, size: 18, color: AppTheme.kGreen),
              const SizedBox(width: 8),
              Text(
                'Estás apuntado',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.kGreen,
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
    );
  }

  Widget _buildEmptyState(bool isCaptain) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.event_busy, size: 48, color: AppTheme.kInkSoft),
            const SizedBox(height: 12),
            Text(
              isCaptain
                  ? 'No hay partidos programados.\nCrea uno desde la pestaña Partidos.'
                  : 'No hay partidos programados.\nTu capitán creará el próximo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.kInkSoft, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
