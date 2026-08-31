import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Chip de estado de un partido, compartido entre pantallas (Home, Matches...).
// Los colores salen de la paleta del tema:
//   Programado -> verde (activo)
//   En juego   -> ámbar (está pasando ahora)
//   Jugado     -> tinta suave (neutro, terminado)
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;

    switch (status) {
      case 'inProgress':
        label = 'En juego';
        color = AppTheme.kAmber;
        break;
      case 'played':
        label = 'Jugado';
        color = AppTheme.kInkSoft;
        break;
      case 'scheduled':
      default:
        label = 'Programado';
        color = AppTheme.kGreen;
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
}
