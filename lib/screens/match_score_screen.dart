import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../services/firestore_service.dart';

class MatchScoreScreen extends StatefulWidget {
  final Match match;
  const MatchScoreScreen({super.key, required this.match});

  @override
  State<MatchScoreScreen> createState() => _MatchScoreScreenState();
}

class _MatchScoreScreenState extends State<MatchScoreScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Match _match;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _reloadMatch();
  }

  Future<void> _reloadMatch() async {
    final updated = await _firestoreService.getMatch(_match.matchId);
    if (updated != null && mounted) {
      setState(() => _match = updated);
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
      appBar: AppBar(title: const Text('Puntuación')),
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
      trailing: Row(
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
            onPressed: _isSaving ? null : () => _changeGoals(slot.playerId!, 1),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreboard() {
    // El marcador lo decide el modelo (goles de jugadores + extra).
    // La pantalla solo lo muestra; aquí no se calcula nada.
    final extraA = _match.teamAExtraGoals;
    final extraB = _match.teamBExtraGoals;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- Columna equipo A (Rojo) ---
              _scoreSide(
                label: 'Rojo',
                score: _match.teamAScore,
                color: Colors.red,
                extra: extraA,
                onAdd: _isSaving ? null : () => _changeTeamExtra('A', 1),
                onRemove: (_isSaving || extraA == 0)
                    ? null
                    : () => _changeTeamExtra('A', -1),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '-',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
              ),
              // --- Columna equipo B (Azul) ---
              _scoreSide(
                label: 'Azul',
                score: _match.teamBScore,
                color: Colors.blue,
                extra: extraB,
                onAdd: _isSaving ? null : () => _changeTeamExtra('B', 1),
                onRemove: (_isSaving || extraB == 0)
                    ? null
                    : () => _changeTeamExtra('B', -1),
              ),
            ],
          ),
          // Pista de ayuda: solo aparece si hay algún gol "a mano".
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

  // Una mitad del marcador: etiqueta, número grande y botones +/- del extra.
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
}
