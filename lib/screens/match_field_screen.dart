import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/slot.dart';

class MatchFieldScreen extends StatefulWidget {
  final Match match;
  const MatchFieldScreen({super.key, required this.match});

  @override
  State<MatchFieldScreen> createState() => _MatchFieldScreenState();
}

class _MatchFieldScreenState extends State<MatchFieldScreen> {
  late Match _match;

  @override
  void initState() {
    super.initState();
    _match = widget.match;
  }

  @override
  Widget build(BuildContext context) {
    // Separamos los huecos por equipo
    final teamA = _match.slots.where((s) => s.team == 'A').toList();
    final teamB = _match.slots.where((s) => s.team == 'B').toList();

    return Scaffold(
      appBar: AppBar(title: Text(_match.type)),
      body: Container(
        color: const Color(0xFF2E7D32), // verde césped
        child: Column(
          children: [
            // Mitad superior: equipo A
            Expanded(child: _buildTeamHalf(teamA, Colors.red)),
            // Línea central
            Container(height: 2, color: Colors.white),
            // Mitad inferior: equipo B
            Expanded(child: _buildTeamHalf(teamB, Colors.blue)),
          ],
        ),
      ),
    );
  }

  // Dibuja una mitad del campo con las burbujas de un equipo
  Widget _buildTeamHalf(List<Slot> slots, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.spaceEvenly,
        spacing: 16,
        runSpacing: 16,
        children: slots.map((slot) => _buildBubble(slot, teamColor)).toList(),
      ),
    );
  }

  // Dibuja una burbuja (hueco), vacía u ocupada
  Widget _buildBubble(Slot slot, Color teamColor) {
    final isOccupied = slot.playerId != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOccupied ? teamColor : Colors.white24,
            border: Border.all(color: teamColor, width: 3),
          ),
          child: Center(
            child: Text(
              isOccupied ? _initials(slot.playerName!) : '+',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (isOccupied)
          Text(
            slot.playerName!,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        if (isOccupied && slot.position.isNotEmpty)
          Text(
            slot.position,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
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
