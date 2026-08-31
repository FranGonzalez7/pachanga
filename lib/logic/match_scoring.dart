import '../models/match.dart';

// Reglas de puntuación de un partido.
//
// Agrupa todos los números del sistema de puntos en un solo sitio. Hoy se usan
// los valores por defecto (ScoringRules.standard), pero como el cálculo lee de
// aquí, en el futuro se podría guardar un ScoringRules distinto por grupo y
// tener puntuaciones configurables sin tocar el cálculo.
class ScoringRules {
  final int winPoints; // puntos por ganar
  final int lossPoints; // puntos por perder (negativo)
  final int drawPoints; // puntos por empatar
  final int cleanSheetBonus; // bonus del portero si el rival marca 0
  final Map<String, int> goalPointsByPosition; // puntos por gol según posición

  const ScoringRules({
    required this.winPoints,
    required this.lossPoints,
    required this.drawPoints,
    required this.cleanSheetBonus,
    required this.goalPointsByPosition,
  });

  // Reglas actuales de Pachanga (las cerradas en el diseño).
  static const ScoringRules standard = ScoringRules(
    winPoints: 10,
    lossPoints: -10,
    drawPoints: 0,
    cleanSheetBonus: 3,
    goalPointsByPosition: {
      'Portero': 3,
      'Defensa': 3,
      'Central': 2,
      'Lateral': 2,
      'Delantero': 1,
    },
  );

  // Puntos por gol de una posición. Si no está en el mapa (dato raro o posición
  // futura sin configurar), 1 por defecto: nunca rompe.
  int goalPointsFor(String position) {
    return goalPointsByPosition[position] ?? 1;
  }
}

// Calcula los puntos que saca cada jugador en un partido.
//
// Función pura: recibe un Match y unas reglas y devuelve {playerId: puntos}. No
// toca Firestore, no muta nada, no depende de fuera; fácil de razonar y testear.
//
// Devuelve los puntos de este partido (aquí pueden ser negativos). El suelo de 0
// no se aplica aquí, sino al sumarlos al total de la membresía, porque el suelo
// es sobre el acumulado, no sobre un partido suelto.
Map<String, int> calculateMatchPoints(
  Match match, {
  ScoringRules rules = ScoringRules.standard,
}) {
  final result = <String, int>{};

  final scoreA = match.teamAScore;
  final scoreB = match.teamBScore;

  for (final slot in match.slots) {
    final playerId = slot.playerId;
    if (playerId == null) continue; // hueco vacío: no puntúa nadie

    // Puntos por el resultado del equipo de este jugador.
    final isTeamA = slot.team == Match.teamA;
    final myScore = isTeamA ? scoreA : scoreB;
    final rivalScore = isTeamA ? scoreB : scoreA;

    int points;
    if (myScore > rivalScore) {
      points = rules.winPoints;
    } else if (myScore < rivalScore) {
      points = rules.lossPoints;
    } else {
      points = rules.drawPoints;
    }

    // Puntos por los goles que metió, según su posición.
    final goalsScored = match.goals[playerId] ?? 0;
    points += goalsScored * rules.goalPointsFor(slot.position);

    // Bonus de portería a cero: solo porteros, solo si el rival marcó 0
    // (rivalScore ya incluye los goles en propia).
    if (slot.position == 'Portero' && rivalScore == 0) {
      points += rules.cleanSheetBonus;
    }

    result[playerId] = points;
  }

  return result;
}
