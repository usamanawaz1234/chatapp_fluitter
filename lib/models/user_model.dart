import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String? profilePicture;
  final DateTime lastSeen;
  final bool isOnline;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    this.profilePicture,
    required this.lastSeen,
    required this.isOnline,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'name': name,
      'profilePicture': profilePicture,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isOnline': isOnline,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final lastSeenData = map['lastSeen'];
    final DateTime lastSeenDateTime;

    if (lastSeenData == null) {
      lastSeenDateTime = DateTime.now();
    } else if (lastSeenData is Timestamp) {
      lastSeenDateTime = lastSeenData.toDate();
    } else {
      lastSeenDateTime = DateTime.now();
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      profilePicture: map['profilePicture'],
      lastSeen: lastSeenDateTime,
      isOnline: map['isOnline'] ?? false,
    );
  }
}
