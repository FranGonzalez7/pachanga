import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/match.dart';
import '../models/membership.dart';
import 'create_match_sheet.dart';
import 'match_field_screen.dart';
import 'match_score_screen.dart';

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

    // DefaultTabController gestiona las dos pestañas por nosotros.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Partidos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Próximos'),
              Tab(text: 'Jugados'),
            ],
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

            // Próximos: scheduled + inProgress, en orden ascendente (ya vienen así).
            final upcoming = allMatches
                .where((m) => m.status != 'played')
                .toList();

            // Jugados: played, invertidos para que el más reciente quede arriba.
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
        floatingActionButton: (_membership?.role == 'captain')
            ? FloatingActionButton.extended(
                onPressed: _openCreateMatch,
                icon: const Icon(Icons.add),
                label: const Text('Crear partido'),
              )
            : null,
      ),
    );
  }

  // Construye una lista de partidos, o un mensaje si está vacía.
  Widget _buildMatchList(List<Match> matches, String emptyMessage) {
    if (matches.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.builder(
      itemCount: matches.length,
      itemBuilder: (context, index) {
        final match = matches[index];
        return ListTile(
          leading: const Icon(Icons.sports_soccer),
          title: Text(match.type),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_formatDate(match.scheduledAt)),
              // El lugar solo aparece si el partido tiene uno.
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
            ],
          ),
          trailing: _statusChip(match.status),
          onTap: () => _openMatch(match),
        );
      },
    );
  }

  Widget _statusChip(String status) {
    late final String label;
    late final Color color;

    switch (status) {
      case 'inProgress':
        label = 'En juego';
        color = Colors.orange;
        break;
      case 'played':
        label = 'Jugado';
        color = Colors.grey;
        break;
      case 'scheduled':
      default:
        label = 'Programado';
        color = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
