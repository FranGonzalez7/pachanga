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

  // Marcador autocalculado: suma de goles de cada equipo
  int _teamScore(String team) {
    int total = 0;
    for (final slot in _occupiedSlots(team)) {
      total += _goalsOf(slot.playerId!);
    }
    return total;
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
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const Text('Rojo', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(
            '${_teamScore('A')} - ${_teamScore('B')}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const Text('Azul', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}
