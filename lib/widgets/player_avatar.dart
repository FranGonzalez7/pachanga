import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// Avatar de jugador reutilizable. Se ocupa SOLO de decidir qué pintar:
// la foto (si hay photoUrl) o la inicial del nombre (si no).
//
// NO decide la forma: rellena un cuadrado de lado [size]. Quien lo use lo
// envuelve en la forma que quiera (ClipOval para círculos, ClipRRect para
// la carta...). Así el mismo widget sirve en el Home, la lista, las burbujas
// y la carta de jugador, tenga cada una la forma que tenga.
//
// El placeholder (sin foto) es configurable: cada sitio pasa sus colores
// para respetar su estilo. El tamaño de la inicial se calcula solo a partir
// de [size], salvo que se pase [fontSize] a mano. Si se pasa [borderColor],
// el avatar se dibuja circular con ese borde (el caso más común); si no, se
// devuelve "desnudo" para que quien lo use le dé la forma que quiera.
class PlayerAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final double size;

  // Colores del placeholder (cuando no hay foto).
  final Color backgroundColor;
  final Color initialColor;

  // Si no se pasa, la inicial se dimensiona como una fracción del tamaño.
  final double? fontSize;

  // Si se pasa, el avatar se recorta en círculo con este borde. Si es null,
  // el avatar se devuelve sin forma ni borde (quien lo use lo envuelve).
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
    // El contenido en bruto (foto o inicial), que rellena el cuadrado.
    final content = _buildContent();

    // Sin borde: se devuelve tal cual, para que quien lo use le dé forma.
    if (borderColor == null) return content;

    // Con borde: círculo recortado + borde por FUERA del recorte (envolver
    // el ClipOval en un Container con borde; si el borde fuera dentro del
    // clip, el recorte se comería parte y quedaría irregular).
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

    // Con foto: la imagen rellena el cuadrado, recortando para no deformar.
    if (url != null && url.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          // Mientras carga, un fondo neutro para que no "parpadee".
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(color: backgroundColor);
          },
          // Si la foto falla (URL rota, sin red), caemos a la inicial en
          // vez de mostrar el icono de imagen rota.
          errorBuilder: (context, error, stack) => _buildInitial(),
        ),
      );
    }

    // Sin foto: la inicial sobre el fondo del placeholder.
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
