import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final String? photoUrl;
  final List<String> preferredPositions;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    this.photoUrl,
    required this.preferredPositions,
    required this.createdAt,
  });

  // De Firestore (Map) a objeto AppUser
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      displayName: data['displayName'] as String,
      email: data['email'] as String,
      photoUrl: data['photoUrl'] as String?,
      preferredPositions: List<String>.from(data['preferredPositions'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // De objeto AppUser a Firestore (Map)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'photoUrl': photoUrl,
      'preferredPositions': preferredPositions,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
