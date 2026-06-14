import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/match.dart';
import '../models/membership.dart';
import 'create_match_sheet.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Membership? _membership;
  late Future<List<Match>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<List<Match>> _loadMatches() async {
    final uid = _authService.currentUser!.uid;
    final membership = await _firestoreService.getUserMembership(uid);
    if (mounted) {
      setState(() {
        _membership = membership;
      });
    }
    if (membership == null) return [];
    return _firestoreService.getGroupMatches(membership.groupId);
  }

  // Recarga la lista de partidos
  void _refreshMatches() {
    setState(() {
      _matchesFuture = _loadMatches();
    });
  }

  void _openCreateMatch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CreateMatchSheet(
        groupId: _membership!.groupId,
        createdBy: _membership!.userId,
        onMatchCreated: _refreshMatches,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partidos')),
      body: FutureBuilder<List<Match>>(
        future: _matchesFuture,
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
              );
            },
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
    );
  }

  String _formatDate(DateTime d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}  ${two(d.hour)}:${two(d.minute)}';
  }
}
