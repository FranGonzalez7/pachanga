class Slot {
  final String team;
  final String position;
  final String? playerId;
  final String? playerName;
  // Foto del jugador que ocupa el slot. Desnormalizada aquí (como playerName)
  // para pintar las burbujas/hileras sin buscar la membresía de cada uno.
  final String? photoUrl;

  Slot({
    required this.team,
    required this.position,
    this.playerId,
    this.playerName,
    this.photoUrl,
  });

  factory Slot.fromMap(Map<String, dynamic> data) {
    return Slot(
      team: data['team'] as String,
      position: data['position'] as String,
      playerId: data['playerId'] as String?,
      playerName: data['playerName'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'team': team,
      'position': position,
      'playerId': playerId,
      'playerName': playerName,
      'photoUrl': photoUrl,
    };
  }

  // Devuelve una copia del slot cambiando solo los campos indicados
  Slot copyWith({
    String? team,
    String? position,
    String? playerId,
    String? playerName,
    String? photoUrl,
    bool clearPlayer = false,
  }) {
    return Slot(
      team: team ?? this.team,
      position: position ?? this.position,
      playerId: clearPlayer ? null : (playerId ?? this.playerId),
      playerName: clearPlayer ? null : (playerName ?? this.playerName),
      // clearPlayer también limpia la foto: si se va el jugador, se va todo.
      photoUrl: clearPlayer ? null : (photoUrl ?? this.photoUrl),
    );
  }
}
