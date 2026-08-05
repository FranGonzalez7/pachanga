import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
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
    // Altura de la cenefa: proporción REAL del asset recortado (1024x114) al
    // ancho de pantalla, para que las hojas no se deformen.
    final grassHeight = AppTheme.grassStripHeight(context);
    
    return Scaffold(
      // El césped va como overlay SOBRE el contenido (no dentro de la barra),
      // así los huecos entre hojas dejan ver lo que hay detrás.
      body: Stack(
        children: [
          Positioned.fill(child: _screens[_selectedIndex]),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: grassHeight,
            // IgnorePointer: la cenefa es decorativa, los toques atraviesan
            // hasta el contenido de debajo.
            child: IgnorePointer(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Base verde que sella la costura con la barra: evita el
                  // hilillo crema por redondeo de píxeles. Hace de "tierra";
                  // como la barra también es verde, se funde con ella.
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(height: 3, color: AppTheme.kGreen),
                  ),
                  // Cenefa tintada a kGreen (el colorFilter sale del tema, sin
                  // hex suelto). BoxFit.fill sobre una caja que ya respeta la
                  // proporción del asset: llena a lo ancho sin aplastar.
                  SvgPicture.asset(
                    'assets/grass_strip.svg',
                    fit: BoxFit.fill,
                    colorFilter: const ColorFilter.mode(
                      AppTheme.kGreen,
                      BlendMode.srcIn,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Barra invertida: fondo verde, iconos y texto crema. El seleccionado a
      // plena opacidad; los demás, crema atenuado para distinguirlo.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.kGreen,
        selectedItemColor: AppTheme.kCream,
        unselectedItemColor: AppTheme.kCream.withOpacity(0.6),
        elevation: 0, // sin sombra: la cenefa ya es el borde superior
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
