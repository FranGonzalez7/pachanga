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

  // Cargamos la membresía una sola vez: necesitamos su groupId para el stream.
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

  // Decide a qué pantalla abrir un partido según su estado.
  // Como la lista ahora es un stream en vivo, match.status siempre está fresco.
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
    // Ya no refrescamos a mano: el stream mantiene la lista al día sola.
  }

  void _openCreateMatch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreateMatchSheet(
        groupId: _membership!.groupId,
        createdBy: _membership!.userId,
        // El stream añade el partido nuevo solo; no hace falta hacer nada aquí.
        onMatchCreated: () {},
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partidos')),
      body: _buildBody(),
      floatingActionButton: (_membership?.role == 'captain')
          ? FloatingActionButton.extended(
              onPressed: _openCreateMatch,
              icon: const Icon(Icons.add),
              label: const Text('Crear partido'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_loadingMembership) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_membership == null) {
      return const Center(child: Text('No perteneces a ningún grupo.'));
    }

    // StreamBuilder: se suscribe a los partidos del grupo y se redibuja
    // cada vez que cambia algo en Firestore. Adiós a los datos rancios.
    return StreamBuilder<List<Match>>(
      stream: _firestoreService.streamGroupMatches(_membership!.groupId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay partidos programados.'));
        }

        final matches = snapshot.data!;
        return ListView.builder(
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return ListTile(
              leading: const Icon(Icons.sports_soccer),
              title: Text(match.type),
              subtitle: Text(_formatDate(match.scheduledAt)),
              trailing: _statusChip(match.status),
              onTap: () => _openMatch(match),
            );
          },
        );
      },
    );
  }

  // Pequeña etiqueta de color para ver el estado de un vistazo.
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
