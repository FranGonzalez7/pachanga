class Slot {
  final String team;
  final String position;
  final String? playerId;
  final String? playerName;

  Slot({
    required this.team,
    required this.position,
    this.playerId,
    this.playerName,
  });

  factory Slot.fromMap(Map<String, dynamic> data) {
    return Slot(
      team: data['team'] as String,
      position: data['position'] as String,
      playerId: data['playerId'] as String?,
      playerName: data['playerName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'team': team,
      'position': position,
      'playerId': playerId,
      'playerName': playerName,
    };
  }

  // Devuelve una copia del slot cambiando solo los campos indicados
  Slot copyWith({
    String? team,
    String? position,
    String? playerId,
    String? playerName,
    bool clearPlayer = false,
  }) {
    return Slot(
      team: team ?? this.team,
      position: position ?? this.position,
      playerId: clearPlayer ? null : (playerId ?? this.playerId),
      playerName: clearPlayer ? null : (playerName ?? this.playerName),
    );
  }
}
