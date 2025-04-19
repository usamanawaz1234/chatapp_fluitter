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
      'lastSeen': lastSeen.toIso8601String(),
      'isOnline': isOnline,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      name: map['name'],
      profilePicture: map['profilePicture'],
      lastSeen: DateTime.parse(map['lastSeen']),
      isOnline: map['isOnline'],
    );
  }
}
