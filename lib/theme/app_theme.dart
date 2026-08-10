import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Tema central de Pachanga. Todo el color y la tipografía de la app se
// define AQUÍ, una sola vez. Las pantallas no eligen colores: leen los
// roles del tema (primary, surface, secondary...). Cambiar un color aquí
// cambia la app entera. Es el mismo principio que ScoringRules o el
// catálogo de formaciones: reglas parametrizadas en un único sitio.
class AppTheme {
  AppTheme._(); // constructor privado: esta clase no se instancia, solo agrupa.
  // --- Paleta con nombre -----------------------------------------------
  // Los colores crudos viven aquí, con nombre. Nadie fuera de este archivo
  // debería escribir un hex a mano: si hay que afinar el crema, se toca
  // este bloque y punto.
  static const Color kGreen = Color(0xFF2D6A4F); // verde césped, protagonista
  static const Color kGreenDark = Color(0xFF1B4332); // verde para presionados
  static const Color kAmber = Color(0xFFE4A020); // ámbar, acento
  static const Color kSilver = Color(0xFFC0C0C0);
  static const Color kBrick = Color(
    0xFFB5533C,
  ); // teja/terracota: derrotas y (futuro) errores. Nunca verde para error.
  static const Color kCream = Color(0xFFF3EAD8); // crema de fondo (tostado)
  static const Color kCreamCard = Color(
    0xFFFBF6EC,
  ); // crema de tarjetas (claro)
  static const Color kInk = Color(0xFF2E2A24); // "tinta": texto, marrón oscuro
  static const Color kInkSoft = Color(0xFF7A7566); // texto secundario, apagado
  // --- Métricas compartidas ---------------------------------------------
  // Altura de la cenefa de césped: proporción real del asset recortado
  // (1024x114) al ancho de pantalla, para que las hojas no se deformen.
  // Fuente ÚNICA de verdad: la MainScreen la usa para PINTAR el césped y las
  // pantallas para dejar hueco inferior y que nada quede pisado por él.
  static double grassStripHeight(BuildContext context) =>
      MediaQuery.of(context).size.width * 114 / 1024;
  // --- ColorScheme ------------------------------------------------------
  // Partimos de fromSeed (deriva ~30 colores coherentes del verde) y
  // sobrescribimos solo los roles que queremos controlar a mano. El resto
  // los rellena Material de forma armónica.
  static final ColorScheme _colorScheme =
      ColorScheme.fromSeed(
        seedColor: kGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: kGreen,
        onPrimary: kCreamCard, // texto/iconos sobre verde: crema claro
        secondary: kAmber, // el acento ámbar
        onSecondary: kInk, // texto sobre ámbar: tinta oscura
        surface: kCream, // fondo general (Scaffold usa esto en M3)
        onSurface: kInk, // texto sobre el fondo: tinta, no negro puro
      );
  // --- Tipografía -------------------------------------------------------
  // Poppins en los títulos; el cuerpo se queda en la fuente por defecto
  // (más neutra y legible en textos largos). Si algún día Poppins no
  // convence, se cambia _titleFont y listo.
  static TextTheme _buildTextTheme(TextTheme base) {
    return base.copyWith(
      headlineLarge: GoogleFonts.poppins(
        textStyle: base.headlineLarge,
      ).copyWith(fontWeight: FontWeight.w700, color: kInk),
      headlineMedium: GoogleFonts.poppins(
        textStyle: base.headlineMedium,
      ).copyWith(fontWeight: FontWeight.w700, color: kInk),
      titleLarge: GoogleFonts.poppins(
        textStyle: base.titleLarge,
      ).copyWith(fontWeight: FontWeight.w600, color: kInk),
      titleMedium: GoogleFonts.poppins(
        textStyle: base.titleMedium,
      ).copyWith(fontWeight: FontWeight.w600, color: kInk),
    );
  }

  // --- El tema claro completo ------------------------------------------
  static ThemeData get light {
    final base = ThemeData(
      colorScheme: _colorScheme,
      useMaterial3: true,
      scaffoldBackgroundColor: kCream, // fondo explícito, = surface
    );
    return base.copyWith(
      textTheme: _buildTextTheme(base.textTheme),
      // AppBar: fondo crema, sin sombra, título e iconos en verde. Un borde
      // inferior verde finito la separa del contenido (en vez de sombra).
      appBarTheme: const AppBarTheme(
        backgroundColor: kCream,
        foregroundColor: kGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: Border(bottom: BorderSide(color: kGreen, width: 1.5)),
      ),
      // Tarjetas: crema claro (más claro que el fondo, "flotan" por tono),
      // esquinas redondeadas y una sombra suave.
      cardTheme: CardThemeData(
        color: kCreamCard,
        elevation: 2,
        shadowColor: kInk.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // Botón principal: verde, texto crema, esquinas redondeadas.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kGreen,
          foregroundColor: kCreamCard,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Botones de texto (Cancelar, etc.): verde.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: kGreen),
      ),
      // FAB: mismo verde que el botón principal. "Botón de acción = verde"
      // en toda la app; el ámbar se reserva para señalar, no para accionar.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kGreen,
        foregroundColor: kCreamCard,
      ),
      // Pestañas (TabBar): indicador y texto activo en verde.
      tabBarTheme: const TabBarThemeData(
        labelColor: kGreen,
        unselectedLabelColor: kInkSoft,
        indicatorColor: kGreen,
      ),
      // Barra de navegación inferior: activo en verde.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kCreamCard,
        indicatorColor: kGreen.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, color: kInk),
        ),
      ),
      // Divisores: una línea muy tenue de tinta, no gris genérico.
      dividerTheme: DividerThemeData(
        color: kInk.withValues(alpha: 0.10),
        thickness: 1,
      ),
      // Campos de texto: fondo crema claro, bordes redondeados coherentes
      // con las tarjetas, y borde verde al enfocar. Lo heredan TODOS los
      // TextField de la app (login, crear partido...) sin repetir estilo.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kCreamCard,
        labelStyle: const TextStyle(color: kInkSoft),
        // Borde en reposo: una línea tenue de tinta.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kInk.withValues(alpha: 0.15)),
        ),
        // Borde al enfocar: verde del tema, un poco más grueso.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kGreen, width: 2),
        ),
      ),
    );
  }
}
