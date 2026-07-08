import 'dart:ui';

// Catálogo de formaciones tácticas por tipo de partido.
//
// CONVENCIONES (importantes, el resto del código confía en ellas):
//
// 1. Orden de las coordenadas = orden de los slots del equipo:
//    portero primero, después de atrás hacia adelante, y dentro de
//    cada línea de izquierda a derecha.
//
// 2. Coordenadas relativas entre 0 y 1:
//    x: 0 = borde izquierdo del campo, 1 = borde derecho.
//    y: 0 = borde superior, 1 = borde inferior.
//    Así la formación se adapta a cualquier tamaño de pantalla.
//
// 3. Todas las formaciones están definidas para un equipo que DEFIENDE
//    la portería INFERIOR (portero abajo, ataca hacia arriba). Para el
//    equipo que defiende arriba se aplica el espejo: y' = 1 - y.
//
// Para ajustar una formación (adelantar laterales, abrir delanteros...)
// basta con retocar los números de su lista. Nada más depende de ellos.

class Formation {
  final String name; // etiqueta visible, ej. "1-2-1"
  final List<Offset> positions; // una coordenada por slot (portero incluido)

  const Formation({required this.name, required this.positions});
}

// Formaciones disponibles por tipo de partido.
const Map<String, List<Formation>> formationsByType = {
  '5v5': [
    Formation(
      name: '1-2-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.50, 0.72), // defensa
        Offset(0.25, 0.52), // medio izquierdo
        Offset(0.75, 0.52), // medio derecho
        Offset(0.50, 0.32), // delantero
      ],
    ),
    Formation(
      name: '2-1-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.72), // defensa izquierdo
        Offset(0.70, 0.72), // defensa derecho
        Offset(0.50, 0.52), // medio
        Offset(0.50, 0.32), // delantero
      ],
    ),
    Formation(
      name: '2-2',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.72), // defensa izquierdo
        Offset(0.70, 0.72), // defensa derecho
        Offset(0.30, 0.42), // delantero izquierdo
        Offset(0.70, 0.42), // delantero derecho
      ],
    ),
  ],
  '6v6': [
    Formation(
      name: '2-2-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.74), // defensa izquierdo
        Offset(0.70, 0.74), // defensa derecho
        Offset(0.30, 0.52), // medio izquierdo
        Offset(0.70, 0.52), // medio derecho
        Offset(0.50, 0.32), // delantero
      ],
    ),
    Formation(
      name: '1-2-2',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.50, 0.74), // defensa
        Offset(0.25, 0.54), // medio izquierdo
        Offset(0.75, 0.54), // medio derecho
        Offset(0.30, 0.34), // delantero izquierdo
        Offset(0.70, 0.34), // delantero derecho
      ],
    ),
    Formation(
      name: '2-1-2',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.74), // defensa izquierdo
        Offset(0.70, 0.74), // defensa derecho
        Offset(0.50, 0.54), // medio
        Offset(0.30, 0.34), // delantero izquierdo
        Offset(0.70, 0.34), // delantero derecho
      ],
    ),
  ],
  '7v7': [
    Formation(
      name: '3-1-2',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.22, 0.74), // defensa izquierdo
        Offset(0.50, 0.78), // defensa central
        Offset(0.78, 0.74), // defensa derecho
        Offset(0.50, 0.54), // medio
        Offset(0.30, 0.34), // delantero izquierdo
        Offset(0.70, 0.34), // delantero derecho
      ],
    ),
    Formation(
      name: '2-3-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.76), // defensa izquierdo
        Offset(0.70, 0.76), // defensa derecho
        Offset(0.20, 0.54), // medio izquierdo
        Offset(0.50, 0.52), // medio centro
        Offset(0.80, 0.54), // medio derecho
        Offset(0.50, 0.32), // delantero
      ],
    ),
    Formation(
      name: '3-2-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.22, 0.76), // defensa izquierdo
        Offset(0.50, 0.80), // defensa central
        Offset(0.78, 0.76), // defensa derecho
        Offset(0.30, 0.54), // medio izquierdo
        Offset(0.70, 0.54), // medio derecho
        Offset(0.50, 0.33), // delantero
      ],
    ),
    Formation(
      name: '2-1-2-1',
      positions: [
        Offset(0.50, 0.92), // portero
        Offset(0.30, 0.78), // defensa izquierdo
        Offset(0.70, 0.78), // defensa derecho
        Offset(0.50, 0.60), // medio defensivo
        Offset(0.25, 0.44), // medio ofensivo izquierdo
        Offset(0.75, 0.44), // medio ofensivo derecho
        Offset(0.50, 0.28), // delantero
      ],
    ),
  ],
};

// Formación por defecto de cada tipo (la de un partido recién creado
// o de uno antiguo que aún no tenga formación guardada).
const Map<String, String> defaultFormationByType = {
  '5v5': '1-2-1',
  '6v6': '2-2-1',
  '7v7': '3-1-2',
};

// Devuelve la formación de un tipo por su nombre. Si el nombre no existe
// (dato corrupto, formación retirada del catálogo...), cae a la formación
// por defecto del tipo; si el tipo tampoco existe, a la primera del catálogo.
Formation getFormation(String type, String name) {
  final formations = formationsByType[type] ?? formationsByType.values.first;
  return formations.firstWhere(
    (f) => f.name == name,
    orElse: () => formations.firstWhere(
      (f) => f.name == defaultFormationByType[type],
      orElse: () => formations.first,
    ),
  );
}
