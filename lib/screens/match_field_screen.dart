import 'package:flutter/material.dart';
import '../models/match.dart';
import '../models/slot.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';

class MatchFieldScreen extends StatefulWidget {
  final Match match;
  final Membership currentMembership;

  const MatchFieldScreen({
    super.key,
    required this.match,
    required this.currentMembership,
  });

  @override
  State<MatchFieldScreen> createState() => _MatchFieldScreenState();
}

class _MatchFieldScreenState extends State<MatchFieldScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late Match _match;
  bool _isSaving = false;

  List<Membership> _groupMembers = []; // todos los miembros del grupo

  static const List<String> _positions = [
    'Portero',
    'Defensa',
    'Central',
    'Lateral',
    'Delantero',
  ];

  bool get _isCaptain => widget.currentMembership.role == 'captain';

  @override
  void initState() {
    super.initState();
    _match = widget.match;
    _reloadMatch();
    if (_isCaptain) {
      _loadGroupMembers(); // solo el capitán necesita la lista
    }
  }

  Future<void> _loadGroupMembers() async {
    final members = await _firestoreService.getGroupMembers(
      widget.currentMembership.groupId,
    );
    if (mounted) {
      setState(() => _groupMembers = members);
    }
  }

  String get _myUid => widget.currentMembership.userId;

  // Devuelve los miembros que AÚN NO están en ningún hueco del partido
  List<Membership> get _availablePlayers {
    final occupiedIds = _match.slots
        .where((s) => s.playerId != null)
        .map((s) => s.playerId)
        .toSet();
    return _groupMembers.where((m) => !occupiedIds.contains(m.userId)).toList();
  }

  // Recarga el partido desde Firestore tras un cambio
  Future<void> _reloadMatch() async {
    final updated = await _firestoreService.getMatch(_match.matchId);
    if (updated != null && mounted) {
      setState(() => _match = updated);
    }
  }

  // Maneja el toque sobre una burbuja
  Future<void> _onBubbleTap(int slotIndex) async {
    final slot = _match.slots[slotIndex];

    if (slot.playerId == null) {
      // Burbuja vacía: me apunto (elijo posición)
      final position = await _askPosition();
      if (position == null) return; // canceló

      setState(() => _isSaving = true);
      await _firestoreService.joinSlot(
        matchId: _match.matchId,
        slotIndex: slotIndex,
        playerId: _myUid,
        playerName: widget.currentMembership.displayName,
        position: position,
      );
      await _reloadMatch();
      if (mounted) setState(() => _isSaving = false);
    } else if (slot.playerId == _myUid) {
      // Mi propia burbuja: me salgo
      final confirm = await _confirmLeave();
      if (confirm != true) return;

      setState(() => _isSaving = true);
      await _firestoreService.leaveSlot(
        matchId: _match.matchId,
        slotIndex: slotIndex,
      );
      await _reloadMatch();
      if (mounted) setState(() => _isSaving = false);
    }
    // Si es la burbuja de otro y no soy capitán: no hago nada (de momento)
  }

  // Modal para elegir posición; devuelve la elegida o null si cancela
  Future<String?> _askPosition() {
    return showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Elige tu posición',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ..._positions.map(
              (pos) => ListTile(
                title: Text(pos),
                onTap: () => Navigator.of(context).pop(pos),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmLeave() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salir del partido'),
        content: const Text('¿Quieres quitarte de este hueco?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_match.type)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF2E7D32),
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildTeamHalf(_teamAIndexes(), Colors.red),
                      ),
                      Container(height: 2, color: Colors.white),
                      Expanded(
                        child: _buildTeamHalf(_teamBIndexes(), Colors.blue),
                      ),
                    ],
                  ),
                ),
                if (_isSaving)
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          if (_isCaptain) _buildAvailablePlayersBar(),
        ],
      ),
    );
  }

  Widget _buildAvailablePlayersBar() {
    final players = _availablePlayers;
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: Colors.grey[200],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              'Jugadores disponibles',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: players.isEmpty
                ? const Center(child: Text('Todos colocados'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 22,
                              child: Text(_initials(player.displayName)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              player.displayName,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<int> _teamAIndexes() {
    final list = <int>[];
    for (int i = 0; i < _match.slots.length; i++) {
      if (_match.slots[i].team == 'A') list.add(i);
    }
    return list;
  }

  List<int> _teamBIndexes() {
    final list = <int>[];
    for (int i = 0; i < _match.slots.length; i++) {
      if (_match.slots[i].team == 'B') list.add(i);
    }
    return list;
  }

  Widget _buildTeamHalf(List<int> slotIndexes, Color teamColor) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.spaceEvenly,
        spacing: 16,
        runSpacing: 16,
        children: slotIndexes
            .map((index) => _buildBubble(index, teamColor))
            .toList(),
      ),
    );
  }

  Widget _buildBubble(int slotIndex, Color teamColor) {
    final slot = _match.slots[slotIndex];
    final isOccupied = slot.playerId != null;

    return GestureDetector(
      onTap: () => _onBubbleTap(slotIndex),
      child: Column(
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
