import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import 'match_field_screen.dart';
import '../logic/match_scoring.dart';

class MatchScoreScreen extends StatefulWidget {
  final Match match;
  final Membership currentMembership; // quién está viendo la pantalla
  const MatchScoreScreen({
    super.key,
    required this.match,
    required this.currentMembership,
  });
  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Match _match;
  bool _isSaving = false;
  // El partido sigue editable solo mientras está en juego.
  // Cuando pasa a 'played', se ocultan los controles de acción.
  bool get _isInProgress => _match.status == 'inProgress';
  // Quien mira puede gestionar (capitán o co-capitán).
  bool get _canManage => widget.currentMembership.canManage;
  // Se pueden tocar los controles solo si el partido está en juego
  // Y quien mira gestiona. Un jugador raso solo visualiza.
  bool get _canEdit => _isInProgress && _canManage;
  // Puntos que saca cada jugador en este partido (delta crudo, puede ser
  // negativo). Solo se usa en modo lectura para mostrar el resultado.
  Map<String, int> _pointsAwarded = {};
  // El partido está cerrado: su resultado (y los puntos) son definitivos.
  bool get _isPlayed => _match.status == 'played';
  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _reloadMatch();
  }

  Future<void> _reloadMatch() async {
    final updated = await _firestoreService.getMatch(_match.matchId);
    if (updated != null && mounted) {
      setState(() {
        _match = updated;
        // Recalculamos los deltas de puntos (barato, en memoria, sin red).
        _pointsAwarded = calculateMatchPoints(updated);
      });
    }
  }

  // Slots ocupados de un equipo
  List<Slot> _occupiedSlots(String team) {
    return _match.slots
        .where((s) => s.team == team && s.playerId != null)
        .toList();
  }

  // Goles de un jugador (0 si no tiene)
  int _goalsOf(String playerId) {
    return _match.goals[playerId] ?? 0;
  }

  // Cambia los goles de un jugador (delta = +1 o -1)
  Future<void> _changeGoals(String playerId, int delta) async {
    final current = _goalsOf(playerId);
    final newCount = current + delta;
    if (newCount < 0) return; // no permitimos goles negativos
    setState(() => _isSaving = true);
    await _firestoreService.updatePlayerGoals(
      matchId: _match.matchId,
      playerId: playerId,
      newGoalCount: newCount,
    );
    await _reloadMatch();
    if (mounted) setState(() => _isSaving = false);
  }

  // Cambia los goles "extra" de un equipo (propias del rival, ajustes).
  // No tocan a ningún jugador: solo suben/bajan el marcador del equipo.
  Future<void> _changeTeamExtra(String team, int delta) async {
    // Calculamos el nuevo extra del equipo que se toca, con suelo en 0:
    // el extra nunca puede ser negativo (el marcador no puede bajar de la
    // suma de goles de los jugadores).
    final currentA = _match.teamAExtraGoals;
    final currentB = _match.teamBExtraGoals;
    final newA = team == 'A' ? (currentA + delta).clamp(0, 99) : currentA;
    final newB = team == 'B' ? (currentB + delta).clamp(0, 99) : currentB;
    // Si no cambia nada (intentábamos bajar de 0), salimos.
    if (newA == currentA && newB == currentB) return;
    setState(() => _isSaving = true);
    await _firestoreService.updateTeamExtraGoals(
      matchId: _match.matchId,
      teamAExtraGoals: newA,
      teamBExtraGoals: newB,
    );
    await _reloadMatch();
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final teamA = _occupiedSlots('A');
    final teamB = _occupiedSlots('B');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Puntuación'),
        actions: [
          // Volver a editar alineación: solo si el partido está en juego.
          if (_canEdit)
            IconButton(
              icon: const Icon(Icons.undo),
              tooltip: 'Volver a editar alineación',
              onPressed: _confirmRevertToScheduled,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                _buildTeamSection('Equipo Rojo', teamA, AppTheme.kTeamRed),
                // Separador verde tenue entre los dos equipos. Va aquí (entre
                // secciones), no dentro de _buildTeamSection, para que no
                // quede uno colgando bajo el último equipo.
                Divider(color: AppTheme.kGreen.withValues(alpha: 0.25)),
                _buildTeamSection('Equipo Azul', teamB, AppTheme.kTeamBlue),
              ],
            ),
          ),
          _buildScoreboard(),
          // Botón de terminar: solo mientras el partido está en juego.
          // Verde del tema (acción principal, como el resto de la app). El
          // aviso de "irreversible" lo da el diálogo de confirmación.
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Terminar partido'),
                  onPressed: _confirmFinishMatch,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamSection(String title, List<Slot> slots, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        ...slots.map((slot) => _buildPlayerRow(slot, color)),
      ],
    );
  }

  Widget _buildPlayerRow(Slot slot, Color color) {
    final goals = _goalsOf(slot.playerId!);
    return ListTile(
      // Avatar con foto (o inicial si no hay), borde del color del equipo.
      // Igual que en el resto de la app, vía PlayerAvatar.
      leading: PlayerAvatar(
        photoUrl: slot.photoUrl,
        name: slot.playerName ?? '?',
        size: 48,
        borderColor: color,
        borderWidth: 2,
        backgroundColor: color,
        initialColor: Colors.white,
      ),
      title: Text(slot.playerName ?? 'Jugador'),
      subtitle: Text(slot.position),
      trailing: _canEdit
          // Modo edición: botones +/- alrededor del número.
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _isSaving
                      ? null
                      : () => _changeGoals(slot.playerId!, -1),
                ),
                Text('$goals', style: const TextStyle(fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _isSaving
                      ? null
                      : () => _changeGoals(slot.playerId!, 1),
                ),
              ],
            )
          // Modo lectura: goles arriba, y el delta de puntos SOLO si el partido
          // ya está jugado (su resultado es definitivo).
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _goalsLabel(goals),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isPlayed) ...[
                  const SizedBox(height: 2),
                  _buildPointsDelta(slot.playerId!),
                ],
              ],
            ),
    );
  }

  // Muestra los puntos que el jugador saca en este partido: +N en verde,
  // -N en teja, 0 en tinta suave. Es el delta crudo (antes del suelo de 0).
  Widget _buildPointsDelta(String playerId) {
    final delta = _pointsAwarded[playerId] ?? 0;
    final Color color;
    final String text;
    if (delta > 0) {
      color = AppTheme.kGreen;
      text = '+$delta';
    } else if (delta < 0) {
      color = AppTheme.kBrick;
      text = '$delta'; // el signo - ya viene en el número
    } else {
      color = AppTheme.kInkSoft;
      text = '0';
    }
    return Text(
      '$text pts',
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
    );
  }

  // Texto del número de goles con singular/plural: "0 goles", "1 gol", "2 goles".
  String _goalsLabel(int goals) {
    return goals == 1 ? '1 gol' : '$goals goles';
  }

  // Padding vertical dentro del marco del campo (marca la separación entre las
  // líneas del campo y el contenido del marcador).
  static const double _scorePadV = 14;
  Widget _buildScoreboard() {
    final extraA = _match.teamAExtraGoals;
    final extraB = _match.teamBExtraGoals;
    return Container(
      padding: const EdgeInsets.all(16),
      // Mismo crema que el fondo de la pantalla: el marcador se funde con el
      // resto y es el borde superior verde lo que lo delimita.
      decoration: const BoxDecoration(
        color: AppTheme.kCream,
        border: Border(top: BorderSide(color: AppTheme.kGreen, width: 1.5)),
      ),
      child: Column(
        children: [
          // El marcador enmarcado como un mini campo: líneas verdes de fondo
          // (marco, línea de medio campo y círculo central) pintadas por
          // detrás; el "-" cae sobre el círculo central, como el punto de saque.
          CustomPaint(
            painter: _PitchLinesPainter(
              lineColor: AppTheme.kGreen.withValues(alpha: 0.55),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: _scorePadV,
              ),
              // Cada lado en un Expanded: ocupa EXACTAMENTE media mitad del
              // campo y centra su contenido ahí. Así "Rojo" queda en el centro
              // de su portería y "Azul" en la suya, en vez de escorados hacia
              // la línea media (que es lo que hacía spaceEvenly con 2 hijos).
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start, // alineamos por arriba
                children: [
                  Expanded(
                    child: _scoreSide(
                      label: 'Rojo',
                      score: _match.teamAScore,
                      color: AppTheme.kTeamRed,
                      extra: extraA,
                      onAdd: (_isSaving || !_canEdit)
                          ? null
                          : () => _changeTeamExtra('A', 1),
                      onRemove: (_isSaving || !_canEdit || extraA == 0)
                          ? null
                          : () => _changeTeamExtra('A', -1),
                    ),
                  ),
                  // El centro queda libre para el círculo del campo (pintado
                  // por detrás); ya no hay guión.
                  Expanded(
                    child: _scoreSide(
                      label: 'Azul',
                      score: _match.teamBScore,
                      color: AppTheme.kTeamBlue,
                      extra: extraB,
                      onAdd: (_isSaving || !_canEdit)
                          ? null
                          : () => _changeTeamExtra('B', 1),
                      onRemove: (_isSaving || !_canEdit || extraB == 0)
                          ? null
                          : () => _changeTeamExtra('B', -1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (extraA > 0 || extraB > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'El marcador incluye goles en propia o ajustes del capitán.',
                style: const TextStyle(fontSize: 11, color: AppTheme.kInkSoft),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  // Una mitad del marcador: etiqueta, número grande y (si se puede editar)
  // los botones +/- del extra. En modo lectura, sin botones.
  Widget _scoreSide({
    required String label,
    required int score,
    required Color color,
    required int extra,
    required VoidCallback? onAdd,
    required VoidCallback? onRemove,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '$score',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
        ),
        // Botones de ajuste: solo si se puede editar. En modo lectura, nada.
        if (_canEdit)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemove,
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: onAdd,
              ),
            ],
          ),
      ],
    );
  }

  // Vuelve el partido a 'scheduled' para reeditar la alineación.
  // Pide confirmación porque borra toda la puntuación registrada.
  Future<void> _confirmRevertToScheduled() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Volver a editar la alineación?'),
        content: const Text(
          'El partido volverá a estado "Programado" y se borrarán todos '
          'los goles y ajustes registrados. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Volver atrás'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _firestoreService.revertMatchToScheduled(_match.matchId);
    // Releemos el partido: ya está en 'scheduled' y sin goles. Se lo pasamos
    // al campo para que abra con la alineación intacta y editable.
    final updated = await _firestoreService.getMatch(_match.matchId);
    if (!mounted || updated == null) return;
    // pushReplacement: sustituimos la puntuación por el campo en un gesto.
    // Así la flecha "atrás" del campo lleva a la lista, no a la puntuación vieja.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MatchFieldScreen(
          match: updated,
          currentMembership: widget.currentMembership,
        ),
      ),
    );
  }

  // Termina el partido: aplica los puntos a las membresías y pasa a 'played'.
  // Es IRREVERSIBLE, por eso la confirmación es explícita.
  Future<void> _confirmFinishMatch() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Terminar el partido?'),
        content: const Text(
          'Se calcularán los puntos definitivos y se sumarán a cada jugador. '
          'El partido quedará cerrado y esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Terminar partido'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    await _firestoreService.finishMatch(_match);
    if (!mounted) return;
    // Releemos el partido ya en 'played' para reflejar el estado final.
    final updated = await _firestoreService.getMatch(_match.matchId);
    if (updated != null && mounted) {
      setState(() {
        _match = updated;
        _isSaving = false;
      });
    }
  }
}

// Pinta las líneas de un campo de fútbol (marco, línea de medio campo y
// círculo central) como fondo decorativo del marcador. Solo trazo verde fino,
// sin rellenos: se lee como las líneas de cal de un campo real sin recargar.
class _PitchLinesPainter extends CustomPainter {
  final Color lineColor;
  _PitchLinesPainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final midX = size.width / 2;
    final midY = size.height / 2;

    // Marco perimetral con esquinas redondeadas (la banda del campo). Se mete
    // 1px hacia dentro para que el trazo no se corte contra el borde.
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, paint);

    // Línea de medio campo (vertical, en el centro). Cruza el círculo central,
    // como la línea de cal de un campo real.
    canvas.drawLine(Offset(midX, 1), Offset(midX, size.height - 1), paint);

    // Círculo central, centrado en el marco.
    canvas.drawCircle(Offset(midX, midY), 26, paint);

    // Porterías: un rectángulo pequeño pegado a cada banda lateral, centrado
    // en vertical y abierto hacia dentro del campo (como visto desde arriba).
    const goalDepth = 14.0; // cuánto entra hacia el campo
    const goalHalf = 24.0; // media altura de la portería
    // Izquierda: pegada a la banda izquierda (x=1).
    canvas.drawRect(
      Rect.fromLTRB(1, midY - goalHalf, 1 + goalDepth, midY + goalHalf),
      paint,
    );
    // Derecha: pegada a la banda derecha (x = width-1).
    canvas.drawRect(
      Rect.fromLTRB(
        size.width - 1 - goalDepth,
        midY - goalHalf,
        size.width - 1,
        midY + goalHalf,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PitchLinesPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor;
}
