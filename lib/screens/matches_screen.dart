import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/match.dart';
import '../models/membership.dart';
import 'create_match_sheet.dart';
import 'match_field_screen.dart';
import 'match_score_screen.dart';
import '../widgets/status_chip.dart';
import '../widgets/app_bar_title.dart';
import '../theme/app_theme.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Membership? _membership;
  bool _loadingMembership = true;

  bool get _isCaptain => _membership?.canManage ?? false;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final uid = _authService.currentUser!.uid;
    final membership = await _firestoreService.getUserMembership(uid);
    if (mounted) {
      setState(() {
        _membership = membership;
        _loadingMembership = false;
      });
    }
  }

  Future<void> _openMatch(Match match) async {
    final Widget destination;

    switch (match.status) {
      case 'inProgress':
      case 'played':
        destination = MatchScoreScreen(
          match: match,
          currentMembership: _membership!,
        );
        break;
      case 'scheduled':
      default:
        destination = MatchFieldScreen(
          match: match,
          currentMembership: _membership!,
        );
        break;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => destination));
  }

  void _openCreateMatch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreateMatchSheet(
        groupId: _membership!.groupId,
        createdBy: _membership!.userId,
        onMatchCreated: () {},
      ),
    );
  }

  // Abre el formulario en modo EDICIÓN, precargado con el partido.
  void _openEditMatch(Match match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreateMatchSheet(
        groupId: _membership!.groupId,
        createdBy: _membership!.userId,
        onMatchCreated: () {}, // el stream refresca la lista solo
        matchToEdit: match, // <-- esto lo pone en modo editar
      ),
    );
  }

  // Confirma y elimina un partido.
  Future<void> _confirmDeleteMatch(Match match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar partido'),
        content: Text(
          match.status == 'inProgress'
              ? 'Este partido está en juego. Si lo eliminas, se perderá '
                    'junto con su puntuación en curso. Esta acción no se '
                    'puede deshacer.'
              : '¿Seguro que quieres eliminar este partido? '
                    'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteMatch(match.matchId);
      // El stream refresca la lista solo: el partido desaparece.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo eliminar el partido.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingMembership) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_membership == null) {
      return const Scaffold(
        body: Center(child: Text('No perteneces a ningún grupo.')),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppBarTitle('Partidos'),
          shape: const Border(),
          bottom: PreferredSize(
            // Alto reservado = línea (1.5) + alto estándar del TabBar (48).
            preferredSize: const Size.fromHeight(48 + 1.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 1.5, color: AppTheme.kGreen),
                const TabBar(
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: 'Próximos'),
                    Tab(text: 'Jugados'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: StreamBuilder<List<Match>>(
          stream: _firestoreService.streamGroupMatches(_membership!.groupId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(child: Text('Error al cargar los partidos.'));
            }

            final allMatches = snapshot.data ?? [];

            final upcoming = allMatches
                .where((m) => m.status != 'played')
                .toList();

            final playedList = allMatches
                .where((m) => m.status == 'played')
                .toList()
                .reversed
                .toList();

            return TabBarView(
              children: [
                _buildMatchList(upcoming, 'No hay partidos próximos.'),
                _buildMatchList(playedList, 'Aún no hay partidos jugados.'),
              ],
            );
          },
        ),
        floatingActionButton: _isCaptain
            ? Padding(
                // Subimos el FAB por encima de la cenefa de césped.
                padding: EdgeInsets.only(
                  bottom: AppTheme.grassStripHeight(context),
                ),
                child: FloatingActionButton.extended(
                  onPressed: _openCreateMatch,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear partido'),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMatchList(List<Match> matches, String emptyMessage) {
    if (matches.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.builder(
      // 88 despeja el FAB; + la cenefa para que el último partido no quede
      // pisado. La lista pasa por detrás del césped al hacer scroll.
      padding: EdgeInsets.only(bottom: 88 + AppTheme.grassStripHeight(context)),
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return ListTile(
          // Margen estándar del ListTile (16 a los lados), pero recortado a la
          // derecha para que el menú de tres puntos quede más pegado al borde.
          contentPadding: const EdgeInsets.only(left: 16, right: 4),
          leading: _buildLeading(match),
          title: Text(
            _formatDate(match.scheduledAt),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (match.location.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          match.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Huecos ocupados/total: solo tiene sentido en partidos aún por
              // jugar (scheduled). En inProgress/played no se muestra.
              // El tic de "apuntado" vive aquí, junto al recuento: se lee de
              // corrido ("2 de 10 apuntados ✓").
              if (match.status == 'scheduled')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.groups_outlined,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_occupiedCount(match)} de ${match.slots.length} apuntados',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (_isSignedUp(match)) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: Colors.green[600],
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          trailing: _buildTrailing(match),
          onTap: () => _openMatch(match),
        );
      },
    );
  }

  // Columna izquierda de la tarjeta: icono png del estado + tipo debajo.
  Widget _buildLeading(Match match) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(_statusIcon(match.status), width: 32, height: 32),
        const SizedBox(height: 4),
        Text(
          match.type,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // El png que identifica cada estado. Viven en assets/icons/.
  String _statusIcon(String status) {
    switch (status) {
      case 'inProgress':
        return 'assets/icons/marcador.png';
      case 'played':
        return 'assets/icons/noticias.png';
      case 'scheduled':
      default:
        return 'assets/icons/estrategia.png';
    }
  }

  // Cuántos huecos del partido están ocupados (tienen jugador).
  int _occupiedCount(Match match) {
    return match.slots.where((s) => s.playerId != null).length;
  }

  // ¿Estoy yo apuntado a este partido? (alguno de mis slots me tiene a mí)
  bool _isSignedUp(Match match) {
    final myUid = _membership!.userId;
    return match.slots.any((s) => s.playerId == myUid);
  }

  // El trailing: la etiqueta de estado y, para el capitán, el menú de opciones.
  Widget _buildTrailing(Match match) {
    // Opciones disponibles según estado (played no tiene ninguna por ahora).
    final canEdit = match.status == 'scheduled';
    final canDelete = match.status != 'played';
    final hasMenu = _isCaptain && (canEdit || canDelete);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusChip(status: match.status),
        // Menú pegado al borde derecho. Si no hay menú (jugador raso, o played),
        // reservamos el mismo ancho con un hueco para que las chips queden
        // alineadas entre todas las tarjetas.
        if (hasMenu)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') _openEditMatch(match);
              if (value == 'delete') _confirmDeleteMatch(match);
            },
            itemBuilder: (context) => [
              if (canEdit)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Editar'),
                    ],
                  ),
                ),
              if (canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Eliminar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
            ],
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
