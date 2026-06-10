import 'package:cloud_firestore/cloud_firestore.dart';

class Group {
  final String groupId;
  final String name;
  final String joinCode;
  final String createdBy;
  final DateTime createdAt;

  Group({
    required this.groupId,
    required this.name,
    required this.joinCode,
    required this.createdBy,
    required this.createdAt,
  });

  // De Firestore (Map) a objeto Group
  factory Group.fromMap(String groupId, Map<String, dynamic> data) {
    return Group(
      groupId: groupId,
      name: data['name'] as String,
      joinCode: data['joinCode'] as String,
      createdBy: data['createdBy'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // De objeto Group a Firestore (Map)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'joinCode': joinCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
