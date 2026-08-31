import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Avatar de jugador reutilizable. Solo decide qué pintar: la foto (si hay
// photoUrl) o la inicial del nombre (si no).
//
// No decide la forma: rellena un cuadrado de lado [size]. Quien lo use lo
// envuelve en la forma que quiera (ClipOval para círculos, ClipRRect para la
// carta...), así el mismo widget sirve en el Home, la lista, las burbujas y la
// carta de jugador.
//
// El placeholder (sin foto) es configurable: cada sitio pasa sus colores. El
// tamaño de la inicial se calcula a partir de [size], salvo que se pase
// [fontSize]. Si se pasa [borderColor], el avatar se dibuja circular con ese
// borde (el caso más común); si no, se devuelve "desnudo" para que quien lo use
// le dé la forma.
class PlayerAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;

  // Colores del placeholder (cuando no hay foto).
  final Color backgroundColor;
  final Color initialColor;

  // Si no se pasa, la inicial se dimensiona como fracción del tamaño.
  final double? fontSize;

  // Si se pasa, el avatar se recorta en círculo con este borde. Si es null, se
  // devuelve sin forma ni borde (quien lo use lo envuelve).
  final Color? borderColor;
  final double borderWidth;

  const PlayerAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    required this.size,
    this.backgroundColor = AppTheme.kCreamCard,
    this.initialColor = AppTheme.kGreen,
    this.fontSize,
    this.borderColor,
    this.borderWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    // Sin borde: se devuelve tal cual para que quien lo use le dé forma.
    if (borderColor == null) return content;

    // Con borde: el borde va por fuera del recorte (Container con borde
    // envolviendo el ClipOval); si fuera dentro del clip, el recorte se comería
    // parte y quedaría irregular.
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor!, width: borderWidth),
      ),
      child: ClipOval(child: content),
    );
  }

  Widget _buildContent() {
    final url = photoUrl;

    // Con foto: rellena el cuadrado recortando para no deformar.
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          // Fondo neutro mientras carga, para que no parpadee.
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(color: backgroundColor);
          },
          // Si la foto falla (URL rota, sin red), caemos a la inicial en vez del
          // icono de imagen rota.
          errorBuilder: (context, error, stack) => _buildInitial(),
        ),
      );
    }

    return _buildInitial();
  }

  Widget _buildInitial() {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: fontSize ?? size * 0.45,
          fontWeight: FontWeight.bold,
          color: initialColor,
        ),
      ),
    );
  }
}