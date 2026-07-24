import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/group.dart';
import '../models/membership.dart';
import '../models/match.dart';
import '../theme/app_theme.dart';
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
        Divider(height: 28, color: AppTheme.kGreen.withValues(alpha: 0.25)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(Icons.stadium, 'Jugados', '${membership.matchesPlayed}'),
            _statItem(Icons.military_tech, 'Ganados', '${membership.wins}'),
            _statItem(Icons.close, 'Perdidos', '${membership.losses}'),
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

  // Contenido de la tarjeta del próximo partido: caja de fecha a la izquierda,
  // datos del partido a la derecha, y abajo los apuntados con el botón.
  Widget _buildNextMatchContent(Match match, Membership membership) {
    final amIn = match.slots.any((s) => s.playerId == membership.userId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Fila superior: caja de fecha + datos ---
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildDateBox(match.scheduledAt),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1ª línea: tipo de partido con el balón.
                  Row(
                    children: [
                      const Icon(
                        Icons.sports_soccer,
                        size: 22,
                        color: AppTheme.kGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        match.type,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 2ª línea: lugar (solo si lo tiene).
                  if (match.location.isNotEmpty) ...[
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
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.kInkSoft,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  // 3ª línea: hora y, si procede, "Estás apuntado".
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        size: 18,
                        color: AppTheme.kInkSoft,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(match.scheduledAt),
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.kInkSoft,
                        ),
                      ),
                      if (amIn) ...[
                        const Text(
                          '  •  ',
                          style: TextStyle(color: AppTheme.kInkSoft),
                        ),
                        const Icon(
                          Icons.check_circle,
                          size: 15,
                          color: AppTheme.kGreen,
                        ),
                        const SizedBox(width: 4),
                        const Flexible(
                          child: Text(
                            'Estás apuntado',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppTheme.kGreen,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        Divider(height: 28, color: AppTheme.kGreen.withValues(alpha: 0.25)),

        // --- Fila inferior: apuntados + botón ---
        Row(
          children: [
            Expanded(child: _buildSignedUpPlayers(match)),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () => _openMatch(match, membership),
              child: Text(amIn ? 'Ver partido' : 'Apuntarme'),
            ),
          ],
        ),
      ],
    );
  }

  // Caja lateral cuadrada con el día y el mes del partido.
  Widget _buildDateBox(DateTime date) {
    return Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        color: AppTheme.kCream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.kGreen.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _monthAbbr(date.month),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.kGreen,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // Hilera de apuntados: avatares solapados con la inicial, más el recuento.
  // Sale de los slots del partido, sin lecturas extra a Firestore.
  Widget _buildSignedUpPlayers(Match match) {
    final names = match.slots
        .where((s) => s.playerName != null)
        .map((s) => s.playerName!)
        .toList();

    final total = match.slots.length;

    if (names.isEmpty) {
      return const Text(
        'Nadie apuntado aún',
        style: TextStyle(fontSize: 13, color: AppTheme.kInkSoft),
      );
    }

    const maxVisible = 4; // a partir de aquí, se resume con "+N"
    const size = 32.0;
    const step = 23.0; // avance entre avatares (menor que size = se solapan)

    final visible = names.take(maxVisible).toList();
    final extra = names.length - visible.length;
    final bubbles = visible.length + (extra > 0 ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: size,
          width: size + (bubbles - 1) * step,
          child: Stack(
            children: [
              for (int i = 0; i < visible.length; i++)
                Positioned(
                  left: i * step,
                  child: _miniAvatar(text: _initial(visible[i])),
                ),
              if (extra > 0)
                Positioned(
                  left: visible.length * step,
                  child: _miniAvatar(text: '+$extra', muted: true),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${names.length} de $total apuntados',
          style: const TextStyle(fontSize: 12, color: AppTheme.kInkSoft),
        ),
      ],
    );
  }

  // Avatar pequeño de la hilera. Placeholder con inicial; el día de las
  // fotos (plan Blaze) solo cambia el contenido del círculo.
  Widget _miniAvatar({required String text, bool muted = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: muted ? AppTheme.kInkSoft : AppTheme.kGreen,
        // Borde del color de la tarjeta: recorta el avatar de atrás y hace
        // que el solape se lea como "uno delante de otro".
        border: Border.all(color: AppTheme.kCreamCard, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.kCreamCard,
        ),
      ),
    );
  }

  String _initial(String name) => name.isNotEmpty ? name[0].toUpperCase() : '?';

  String _monthAbbr(int month) {
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return months[month - 1];
  }

  String _formatTime(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}h';
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
}
