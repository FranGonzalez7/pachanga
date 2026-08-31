import 'dart:ui';

// Catálogo de formaciones tácticas por tipo de partido.
//
// Convenciones (el resto del código confía en ellas):
//
// 1. El orden de las coordenadas es el orden de los slots del equipo: portero
//    primero, luego de atrás hacia adelante, y dentro de cada línea de
//    izquierda a derecha.
//
// 2. Coordenadas relativas entre 0 y 1 (x: 0 izquierda, 1 derecha; y: 0 arriba,
//    1 abajo), para que la formación se adapte a cualquier tamaño de pantalla.
//
// 3. Todas están definidas para un equipo que defiende la portería inferior
//    (portero abajo, ataca hacia arriba). El equipo que defiende arriba aplica
//    el espejo: y' = 1 - y.
//
// Ajustar una formación (adelantar laterales, abrir delanteros...) es solo
// retocar los números de su lista; nada más depende de ellos.

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
        Offset(0.50, 0.97), // portero
        Offset(0.50, 0.72), // defensa
        Offset(0.18, 0.50), // medio izquierdo
        Offset(0.82, 0.50), // medio derecho
        Offset(0.50, 0.30), // delantero
      ],
    ),
    Formation(
      name: '2-1-1',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.25, 0.72), // defensa izquierdo
        Offset(0.75, 0.72), // defensa derecho
        Offset(0.50, 0.50), // medio
        Offset(0.50, 0.25), // delantero
      ],
    ),
    Formation(
      name: '2-2',
      positions: [
        Offset(0.50, 0.97), // portero
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
        Offset(0.50, 0.97), // portero
        Offset(0.30, 0.74), // defensa izquierdo
        Offset(0.70, 0.74), // defensa derecho
        Offset(0.30, 0.48), // medio izquierdo
        Offset(0.70, 0.48), // medio derecho
        Offset(0.50, 0.24), // delantero
      ],
    ),
    Formation(
      name: '1-2-2',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.50, 0.72), // defensa
        Offset(0.25, 0.54), // medio izquierdo
        Offset(0.75, 0.54), // medio derecho
        Offset(0.30, 0.28), // delantero izquierdo
        Offset(0.70, 0.28), // delantero derecho
      ],
    ),
    Formation(
      name: '2-1-2',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.30, 0.74), // defensa izquierdo
        Offset(0.70, 0.74), // defensa derecho
        Offset(0.50, 0.50), // medio
        Offset(0.30, 0.28), // delantero izquierdo
        Offset(0.70, 0.28), // delantero derecho
      ],
    ),
  ],
  '7v7': [
    Formation(
      name: '3-1-2',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.20, 0.68), // defensa izquierdo
        Offset(0.50, 0.72), // defensa central
        Offset(0.80, 0.68), // defensa derecho
        Offset(0.50, 0.48), // medio
        Offset(0.30, 0.26), // delantero izquierdo
        Offset(0.70, 0.26), // delantero derecho
      ],
    ),
    Formation(
      name: '2-3-1',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.30, 0.76), // defensa izquierdo
        Offset(0.70, 0.76), // defensa derecho
        Offset(0.18, 0.52), // medio izquierdo
        Offset(0.50, 0.50), // medio centro
        Offset(0.82, 0.52), // medio derecho
        Offset(0.50, 0.26), // delantero
      ],
    ),
    Formation(
      name: '3-2-1',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.20, 0.70), // defensa izquierdo
        Offset(0.50, 0.73), // defensa central
        Offset(0.80, 0.70), // defensa derecho
        Offset(0.30, 0.46), // medio izquierdo
        Offset(0.70, 0.46), // medio derecho
        Offset(0.50, 0.24), // delantero
      ],
    ),
    Formation(
      name: '2-1-2-1',
      positions: [
        Offset(0.50, 0.97), // portero
        Offset(0.28, 0.76), // defensa izquierdo
        Offset(0.72, 0.76), // defensa derecho
        Offset(0.50, 0.56), // medio defensivo
        Offset(0.23, 0.42), // medio ofensivo izquierdo
        Offset(0.77, 0.42), // medio ofensivo derecho
        Offset(0.50, 0.26), // delantero
      ],
    ),
  ],
};

// Formación por defecto de cada tipo (partido recién creado, o antiguo que aún
// no tenga formación guardada).
const Map<String, String> defaultFormationByType = {
  '5v5': '1-2-1',
  '6v6': '2-2-1',
  '7v7': '3-1-2',
};

// Formación de un tipo por su nombre. Si el nombre no existe (dato corrupto,
// formación retirada del catálogo...), cae a la por defecto del tipo; si el
// tipo tampoco existe, a la primera del catálogo.
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
