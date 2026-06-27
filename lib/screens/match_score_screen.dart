import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
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

  // Quien mira es el capitán del grupo.
  bool get _isCaptain => widget.currentMembership.role == 'captain';

  // Se pueden tocar los controles solo si el partido está en juego
  // Y quien mira es el capitán. Un jugador no-capitán solo visualiza.
  bool get _canEdit => _isInProgress && _isCaptain;

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
                _buildTeamSection('Equipo Rojo', teamA, Colors.red),
                _buildTeamSection('Equipo Azul', teamB, Colors.blue),
              ],
            ),
          ),
          _buildScoreboard(),
          // Botón de terminar: solo mientras el partido está en juego.
          if (_canEdit)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.flag),
                  label: const Text('Terminar partido'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
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
        const Divider(),
      ],
    );
  }

  Widget _buildPlayerRow(Slot slot, Color color) {
    final goals = _goalsOf(slot.playerId!);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Text(
          _initials(slot.playerName ?? '?'),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
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
  // -N en rojo, 0 en gris. Es el delta crudo (antes del suelo de 0).
  Widget _buildPointsDelta(String playerId) {
    final delta = _pointsAwarded[playerId] ?? 0;

    final Color color;
    final String text;
    if (delta > 0) {
      color = Colors.green[700]!;
      text = '+$delta';
    } else if (delta < 0) {
      color = Colors.red[700]!;
      text = '$delta'; // el signo - ya viene en el número
    } else {
      color = Colors.grey;
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

  Widget _buildScoreboard() {
    final extraA = _match.teamAExtraGoals;
    final extraB = _match.teamBExtraGoals;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment:
                CrossAxisAlignment.start, // alineamos por arriba
            children: [
              _scoreSide(
                label: 'Rojo',
                score: _match.teamAScore,
                color: Colors.red,
                extra: extraA,
                onAdd: (_isSaving || !_canEdit)
                    ? null
                    : () => _changeTeamExtra('A', 1),
                onRemove: (_isSaving || !_canEdit || extraA == 0)
                    ? null
                    : () => _changeTeamExtra('A', -1),
              ),
              // El guión vive en su propia columna, con un hueco arriba del
              // tamaño de la etiqueta, para que caiga a la altura del número.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 20,
                  ), // ~altura de la etiqueta de equipo
                  Text(
                    '-',
                    style: TextStyle(
                      fontSize: 36, // mismo tamaño que el número
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              _scoreSide(
                label: 'Azul',
                score: _match.teamBScore,
                color: Colors.blue,
                extra: extraB,
                onAdd: (_isSaving || !_canEdit)
                    ? null
                    : () => _changeTeamExtra('B', 1),
                onRemove: (_isSaving || !_canEdit || extraB == 0)
                    ? null
                    : () => _changeTeamExtra('B', -1),
              ),
            ],
          ),
          if (extraA > 0 || extraB > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'El marcador incluye goles en propia o ajustes del capitán.',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
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
