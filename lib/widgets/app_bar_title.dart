import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Título de AppBar con el balón de Pachanga delante del texto.
// Reutilizable: cada pantalla le pasa su propio texto (nombre del grupo,
// "Partidos", "Jugadores"...) y el balón es común a todas. El color del
// texto lo hereda del appBarTheme; el balón lo fijamos en verde de marca.
class AppBarTitle extends StatelessWidget {
  final String text;

  const AppBarTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.sports_soccer, color: AppTheme.kGreen, size: 24),
        const SizedBox(width: 8),
        // Flexible + ellipsis: si el nombre del grupo es largo, no desborda.
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
