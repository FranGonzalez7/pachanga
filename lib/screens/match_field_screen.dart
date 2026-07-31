import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../logic/formations.dart';
import '../models/match.dart';
import '../models/membership.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_avatar.dart';
import 'match_score_screen.dart';

// Resultado del diálogo de cambio de formación cuando hay jugadores colocados:
// mantenerlos en la nueva formación o vaciar el equipo.
enum _FormationChangeChoice { keep, reset }

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

  // Colores de equipo (algo apagados para que peguen con la crema). Se usan
  // tanto en las burbujas del campo como en las pestañas, para que el mapeo
  // color -> equipo sea consistente en toda la pantalla.
  static const Color _teamRed = Color(0xFFD32F2F);
  static const Color _teamBlue = Color(0xFF1976D2);

  // Meses en español para el diálogo de información (sin depender de intl).
  static const List<String> _monthNames = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
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
    // Repinta la AppBar al cambiar de tab (el botón de formación y el color de
    // las pestañas dependen del equipo activo).
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
        photoUrl: widget.currentMembership.photoUrl,
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
      photoUrl: player.photoUrl,
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

  // El capitán elige una formación desde el desplegable del AppBar. Si el
  // equipo activo tiene jugadores colocados, pregunta si mantenerlos en la
  // nueva formación (se recolocan) o vaciar el equipo.
  Future<void> _onFormationSelected(String selected) async {
    final team = _activeTeam;
    final currentName = _activeFormationName;

    // Eligió la que ya estaba: nada que hacer.
    if (selected == currentName) return;

    // ¿Cuántos jugadores colocados tiene ESTE equipo? (el otro no se toca)
    final occupied = _match.slots
        .where((s) => s.team == team && s.playerId != null)
        .length;

    // Equipo vacío: no hay a quién mantener, cambiamos directamente.
    bool keepPlayers = false;

    if (occupied > 0) {
      final choice = await showDialog<_FormationChangeChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cambiar formación'),
          content: Text(
            'El equipo $_activeTeamLabel tiene $occupied jugadores colocados. '
            '¿Quieres mantenerlos en la nueva formación o vaciar el equipo?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_FormationChangeChoice.reset),
              child: const Text('Vaciar'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_FormationChangeChoice.keep),
              child: const Text('Mantener'),
            ),
          ],
        ),
      );

      // Cerró sin elegir (Cancelar o toque fuera): no hacemos nada.
      if (choice == null) return;
      keepPlayers = choice == _FormationChangeChoice.keep;
    }

    setState(() => _isSaving = true);
    await _firestoreService.setTeamFormation(
      matchId: _match.matchId,
      team: team,
      formation: selected,
      keepPlayers: keepPlayers,
    );
    await _reloadMatch();
    if (mounted) setState(() => _isSaving = false);
  }

  // Diálogo centrado con la información del partido (fecha, hora y lugar).
  // Disponible para todos: no roba espacio al campo, está a un toque.
  Future<void> _showMatchInfo() {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Información del partido'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow(Icons.event, _formatDate(_match.scheduledAt)),
            _infoRow(Icons.schedule, _formatTime(_match.scheduledAt)),
            _infoRow(
              Icons.place,
              _match.location.trim().isEmpty
                  ? 'Sin lugar indicado'
                  : _match.location,
            ),
          ],
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

  // Fila icono + texto para el diálogo de información.
  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.kGreen),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day} de ${_monthNames[d.month - 1]} de ${d.year}';

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

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
    // Color del equipo activo (para el subrayado y el label de las pestañas).
    final activeColor = _activeTeam == Match.teamA ? _teamRed : _teamBlue;

    return Scaffold(
      appBar: AppBar(
        title: Text(_match.type),
        actions: [
          // Selector de formación del equipo activo (solo capitán, solo
          // scheduled). Desplegable anclado aquí mismo: al tocar, la lista
          // de formaciones cae justo debajo del botón.
          if (_isCaptain && _match.status == 'scheduled')
            PopupMenuButton<String>(
              tooltip: 'Cambiar formación',
              onSelected: _onFormationSelected,
              itemBuilder: (context) {
                final formations = formationsByType[_match.type] ?? [];
                final current = _activeFormationName;
                return formations
                    .map(
                      (f) => PopupMenuItem<String>(
                        value: f.name,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                f.name,
                                style: TextStyle(
                                  fontWeight: f.name == current
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: f.name == current
                                      ? AppTheme.kGreen
                                      : AppTheme.kInk,
                                ),
                              ),
                            ),
                            if (f.name == current)
                              const Icon(
                                Icons.check,
                                color: AppTheme.kGreen,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    )
                    .toList();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      getFormation(_match.type, _activeFormationName).name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.kGreen,
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: AppTheme.kGreen),
                  ],
                ),
              ),
            ),
          // Información del partido (fecha, hora, lugar). Para todos.
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Información del partido',
            onPressed: _showMatchInfo,
          ),
          if (_isCaptain)
            IconButton(
              icon: const Icon(Icons.cleaning_services),
              tooltip: 'Vaciar el campo',
              onPressed: _clearField,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // El subrayado toma el color del equipo activo: refuerza el mapeo
          // color -> equipo.
          indicatorColor: activeColor,
          labelColor: activeColor,
          unselectedLabelColor: AppTheme.kInkSoft,
          tabs: [
            _buildTeamTab('Equipo Rojo', _teamRed),
            _buildTeamTab('Equipo Azul', _teamBlue),
          ],
        ),
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
                    _buildTeamField(Match.teamA, _teamRed, mirror: true),
                    // Azul (B) defiende abajo: coordenadas tal cual.
                    _buildTeamField(Match.teamB, _teamBlue, mirror: false),
                  ],
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

  // Pestaña de equipo: puntito de color (siempre visible, no depende del
  // estado activo) + etiqueta. El puntito es una ayuda de accesibilidad: el
  // equipo se distingue aunque no se perciba bien el color del texto.
  Widget _buildTeamTab(String label, Color color) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildAvailablePlayersBar() {
    final players = _availablePlayers;
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      color: AppTheme.kCream,
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
                              // Avatar del jugador: foto o inicial. Borde
                              // verde si está seleccionado (señal de "elegido
                              // para colocar"), tinta suave si no.
                              PlayerAvatar(
                                photoUrl: player.photoUrl,
                                name: player.displayName,
                                size: 44,
                                borderColor: isSelected
                                    ? AppTheme.kGreen
                                    : AppTheme.kInkSoft,
                                borderWidth: isSelected ? 3 : 1,
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

  // Campo completo de un equipo: SVG de fondo y sus burbujas colocadas
  // según la formación guardada en el partido.
  Widget _buildTeamField(String team, Color teamColor, {required bool mirror}) {
    final slotIndexes = team == Match.teamA ? _teamAIndexes() : _teamBIndexes();
    final formationName = team == Match.teamA
        ? _match.formationA
        : _match.formationB;
    final formation = getFormation(_match.type, formationName);

    // AspectRatio fuerza la proporción del SVG (680x1050): el campo se ve
    // ENTERO, centrado, sin que BoxFit.cover lo agrande y lo recorte por los
    // lados. Con la proporción ya fijada, BoxFit.fill no deforma. El fondo
    // crema cubre las bandas que sobren (el "fuera de campo"), para integrarse
    // con el resto de la app. Un poco de padding da aire entre campo y bordes.
    return Container(
      color: AppTheme.kCream,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: AspectRatio(
        aspectRatio: 680 / 1050,
        child: Stack(
          fit: StackFit.expand,
          children: [
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
  //
  // Usa AnimatedAlign (no Align) para que, al cambiar de formación, la burbuja
  // se DESLICE a su nueva posición en vez de reaparecer de golpe. La animación
  // solo ocurre si Flutter reutiliza el mismo elemento entre reconstrucciones;
  // la ValueKey por slot lo garantiza (el número y orden de slots no cambian al
  // cambiar de formación, así que cada burbuja conserva su identidad).
  Widget _buildPositionedBubble({
    required int slotIndex,
    required Offset coord,
    required Color teamColor,
    required bool mirror,
  }) {
    final dy = mirror ? 1 - coord.dy : coord.dy;
    return AnimatedAlign(
      key: ValueKey('bubble_$slotIndex'),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: Alignment(coord.dx * 2 - 1, dy * 2 - 1),
      child: _buildBubble(slotIndex, teamColor),
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
          // Vacío: círculo semitransparente con "+". Ocupado: PlayerAvatar
          // (foto o inicial) con el borde del color del equipo.
          isOccupied
              ? PlayerAvatar(
                  photoUrl: slot.photoUrl,
                  name: slot.playerName ?? '?',
                  size: 70, // 76 total con el borde de 3
                  borderColor: teamColor,
                  borderWidth: 3,
                  // Placeholder sin foto: fondo del color de equipo, inicial
                  // blanca, como era la burbuja rellena de antes.
                  backgroundColor: teamColor,
                  initialColor: Colors.white,
                )
              : Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                    border: Border.all(color: teamColor, width: 3),
                  ),
                  child: const Center(
                    child: Text(
                      '+',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                ),
          // Etiqueta en cápsula tinta semitransparente: legible sobre el verde
          // del césped o sobre la crema del "fuera de campo", sin depender del
          // fondo. Nombre arriba, posición debajo (más apagada).
          if (isOccupied) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.kInk.withOpacity(0.75),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    slot.playerName!,
                    style: const TextStyle(
                      color: AppTheme.kCream,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (slot.position.isNotEmpty)
                    Text(
                      slot.position,
                      style: TextStyle(
                        color: AppTheme.kCream.withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
