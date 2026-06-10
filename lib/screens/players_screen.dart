import 'package:flutter/material.dart';

class PlayersScreen extends StatelessWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jugadores')),
      body: const Center(child: Text('Jugadores (próximamente)')),
    );
  }
}
