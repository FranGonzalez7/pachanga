import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../logic/formations.dart';
import '../models/match.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
import 'match_score_screen.dart';

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

class _MatchFieldScreenState extends State<MatchFieldScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  late Match _match;
  bool _isSaving = false;
  Membership? _selectedPlayer; // jugador que el capitán va a colocar

  List<Membership> _groupMembers = []; // todos los miembros del grupo

  late TabController _tabController;

  static const List<String> _positions = [
    'Portero',
    'Defensa',
    'Central',
    'Lateral',
    'Delantero',
  ];

  bool get _isCaptain => widget.currentMembership.role == 'captain';

  // Equipo de la tab activa (para el selector de formación del capitán)
  String get _activeTeam =>
      _tabController.index == 0 ? Match.teamA : Match.teamB;

  String get _activeTeamLabel => _activeTeam == Match.teamA ? 'Rojo' : 'Azul';

  String get _activeFormationName =>
      _activeTeam == Match.teamA ? _match.formationA : _match.formationB;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Repinta la AppBar al cambiar de tab (el botón muestra la formación activa)
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _match = widget.match;
    _reloadMatch();
    if (_isCaptain) {
      _loadGroupMembers(); // solo el capitán necesita la lista
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    // Caso capitán: hay un jugador seleccionado y la burbuja está vacía
    if (_isCaptain && _selectedPlayer != null && slot.playerId == null) {
      await _placeSelectedPlayer(slotIndex);
      return;
    }

    // Caso capitán: toca la burbuja de OTRO jugador -> ofrecer quitarlo
    if (_isCaptain && slot.playerId != null && slot.playerId != _myUid) {
      final confirm = await _confirmRemovePlayer(
        slot.playerName ?? 'este jugador',
      );
      if (confirm != true) return;

      setState(() => _isSaving = true);
      await _firestoreService.leaveSlot(
        matchId: _match.matchId,
        slotIndex: slotIndex,
      );
      await _reloadMatch();
      if (mounted) setState(() => _isSaving = false);
      return;
    }

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

  // El capitán toca un jugador de la barra para seleccionarlo/deseleccionarlo
  void _onPlayerSelected(Membership player) {
    setState(() {
      // Si tocas el que ya estaba seleccionado, lo deseleccionas
      if (_selectedPlayer?.userId == player.userId) {
        _selectedPlayer = null;
      } else {
        _selectedPlayer = player;
      }
    });
  }

  // Coloca al jugador seleccionado en un hueco concreto
  Future<void> _placeSelectedPlayer(int slotIndex) async {
    final player = _selectedPlayer;
    if (player == null) return;

    final position = await _askPosition();
    if (position == null) return; // canceló el modal de posición

    setState(() => _isSaving = true);
    await _firestoreService.joinSlot(
      matchId: _match.matchId,
      slotIndex: slotIndex,
      playerId: player.userId,
      playerName: player.displayName,
      position: position,
    );
    await _reloadMatch();
    if (mounted) {
      setState(() {
        _isSaving = false;
        _selectedPlayer = null; // limpiamos la selección tras colocar
      });
    }
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

  // El capitán elige formación para el equipo de la tab activa.
  // Si hay jugadores colocados en ese equipo, avisa: cambiarla los quita.
  Future<void> _askFormation() async {
    final team = _activeTeam;
    final currentName = _activeFormationName;
    final formations = formationsByType[_match.type] ?? [];

    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Formación del equipo $_activeTeamLabel',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...formations.map(
              (f) => ListTile(
                title: Text(f.name),
                trailing: f.name == currentName
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.of(context).pop(f.name),
              ),
            ),
          ],
        ),
      ),
    );

    // Canceló, o eligió la que ya estaba: nada que hacer.
    if (selected == null || selected == currentName) return;

    // ¿Cuántos jugadores colocados tiene ESTE equipo? (el otro no se toca)
    final occupied = _match.slots
        .where((s) => s.team == team && s.playerId != null)
        .length;

    if (occupied > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar formación'),
          content: Text(
            'Cambiar la formación quitará a los $occupied jugadores '
            'colocados del equipo $_activeTeamLabel. ¿Continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Cambiar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);
    await _firestoreService.setTeamFormation(
      matchId: _match.matchId,
      team: team,
      formation: selected,
    );
    await _reloadMatch();
    if (mounted) setState(() => _isSaving = false);
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

  // Confirmación para que el capitán quite a otro jugador
  Future<bool?> _confirmRemovePlayer(String playerName) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quitar jugador'),
        content: Text('¿Quitar a $playerName del partido?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearField() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Vaciar el campo'),
        content: const Text(
          '¿Quitar a todos los jugadores del partido? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    await _firestoreService.clearAllSlots(_match.matchId);
    await _reloadMatch();
    if (mounted) {
      setState(() {
        _isSaving = false;
        _selectedPlayer = null; // por si había alguien seleccionado
      });
    }
  }

  // El capitán comienza el partido (pasa a 'inProgress')
  Future<void> _startMatch() async {
    // Comprobamos si quedan huecos vacíos
    final emptySlots = _match.slots.where((s) => s.playerId == null).length;

    if (emptySlots > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Comenzar partido'),
          content: Text(
            'Quedan $emptySlots huecos sin jugador. ¿Comenzar de todas formas?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Comenzar'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isSaving = true);
    await _firestoreService.updateMatchStatus(_match.matchId, 'inProgress');
    await _reloadMatch();
    if (mounted) {
      setState(() => _isSaving = false);
      // pushReplacement en vez de push: una vez empezado el partido, el campo
      // ya no pinta nada en la pila. Sustituimos en lugar de apilar, para que
      // la flecha "atrás" de la puntuación lleve a la lista, no de vuelta al campo.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MatchScoreScreen(
            match: _match,
            currentMembership: widget.currentMembership,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_match.type),
        actions: [
          // Selector de formación del equipo activo (solo capitán, solo scheduled)
          if (_isCaptain && _match.status == 'scheduled')
            TextButton.icon(
              onPressed: _askFormation,
              icon: Text(
                getFormation(_match.type, _activeFormationName).name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              label: const Icon(Icons.arrow_drop_down),
            ),
          if (_isCaptain)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Vaciar el campo',
              onPressed: _clearField,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  controller: _tabController,
                  children: [
                    // Rojo (A) defiende la portería de arriba: espejo.
                    _buildTeamField(Match.teamA, Colors.red, mirror: true),
                    // Azul (B) defiende abajo: coordenadas tal cual.
                    _buildTeamField(Match.teamB, Colors.blue, mirror: false),
                  ],
                ),
                // Selectores de equipo: dos burbujas flotantes flanqueando
                // la portería superior (rojo a la izquierda, azul a la derecha)
                Positioned(
                  top: 10,
                  left: 16,
                  child: _buildTeamTabBubble(0, 'Rojo', Colors.red),
                ),
                Positioned(
                  top: 10,
                  right: 16,
                  child: _buildTeamTabBubble(1, 'Azul', Colors.blue),
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
          if (_isCaptain && _match.status == 'scheduled')
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Comenzar partido'),
                  onPressed: _startMatch,
                ),
              ),
            ),
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
                      final isSelected =
                          _selectedPlayer?.userId == player.userId;
                      return GestureDetector(
                        onTap: () => _onPlayerSelected(player),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: isSelected
                                    ? Colors.green
                                    : null,
                                child: Text(
                                  _initials(player.displayName),
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : null,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                player.displayName,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
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

  // Burbuja flotante para cambiar de equipo (tab). La activa se ve a plena
  // opacidad y con borde grueso; la inactiva, atenuada. El color de equipo
  // es deliberadamente fijo: es identidad del equipo, no un color del tema.
  Widget _buildTeamTabBubble(int tabIndex, String label, Color color) {
    final isActive = _tabController.index == tabIndex;
    return GestureDetector(
      onTap: () => _tabController.animateTo(tabIndex),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isActive ? 1.0 : 0.45,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: isActive ? 3 : 1),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Campo completo de un equipo: SVG de fondo y sus burbujas colocadas
  // según la formación guardada en el partido.
  Widget _buildTeamField(String team, Color teamColor, {required bool mirror}) {
    final slotIndexes = team == Match.teamA ? _teamAIndexes() : _teamBIndexes();
    final formationName = team == Match.teamA
        ? _match.formationA
        : _match.formationB;
    final formation = getFormation(_match.type, formationName);

    // AspectRatio fuerza la proporción exacta del SVG (680x1050): el campo
    // se ve ENTERO siempre, y las coordenadas de formación pasan a mapear
    // sobre el dibujo real, no sobre un recorte. El Container pinta de verde
    // oscuro las bandas que sobren alrededor (el "fuera de campo").
    return Container(
      color: const Color(0xFF1B5E20),
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: 680 / 1050,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // fill ya no deforma: el contenedor tiene la proporción del SVG.
            SvgPicture.asset('assets/field.svg', fit: BoxFit.fill),
            for (int i = 0; i < slotIndexes.length; i++)
              _buildPositionedBubble(
                slotIndex: slotIndexes[i],
                // Contrato del catálogo: la coordenada i va con el slot i del equipo.
                coord: i < formation.positions.length
                    ? formation.positions[i]
                    : const Offset(0.5, 0.5), // red de seguridad: al centro
                teamColor: teamColor,
                mirror: mirror,
              ),
          ],
        ),
      ),
    );
  }

  // Convierte la coordenada relativa (0..1) en un Alignment (-1..1),
  // aplicando el espejo vertical si el equipo defiende la portería de arriba.
  Widget _buildPositionedBubble({
    required int slotIndex,
    required Offset coord,
    required Color teamColor,
    required bool mirror,
  }) {
    final dy = mirror ? 1 - coord.dy : coord.dy;
    return AnimatedAlign(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
      alignment: Alignment(coord.dx * 2 - 1, dy * 2 - 1),
      child: _buildBubble(slotIndex, teamColor),
    );
  }

  // Tamaño de la burbuja (pensado para acoger la foto de perfil en el futuro)
  static const double _bubbleSize = 76;

  Widget _buildBubble(int slotIndex, Color teamColor) {
    final slot = _match.slots[slotIndex];
    final isOccupied = slot.playerId != null;

    return GestureDetector(
      onTap: () => _onBubbleTap(slotIndex),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _bubbleSize,
            height: _bubbleSize,
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
                  fontSize: 22,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (isOccupied)
            Text(
              slot.playerName!,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          if (isOccupied && slot.position.isNotEmpty)
            Text(
              slot.position,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
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
