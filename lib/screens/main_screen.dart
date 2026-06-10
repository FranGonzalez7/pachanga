import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'matches_screen.dart';
import 'players_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Pestaña activa: 0 = Partidos, 1 = Home, 2 = Jugadores
  int _selectedIndex = 1; // arrancamos en Home (centro)

  // Las tres pantallas, en el mismo orden que las pestañas
  final List<Widget> _screens = const [
    MatchesScreen(),
    HomeScreen(),
    PlayersScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_soccer),
            label: 'Partidos',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Jugadores'),
        ],
      ),
    );
  }
}
