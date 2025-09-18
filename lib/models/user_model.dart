class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String? bio;
  final String? school;
  final String? address;
  final bool showDetails;
  final DateTime createdAt;
  final List<String> following;
  final List<String> followers;

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    this.bio,
    this.school,
    this.address,
    this.showDetails = true,
    required this.createdAt,
    this.following = const [],
    this.followers = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'bio': bio,
      'school': school,
      'address': address,
      'showDetails': showDetails,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'following': following,
      'followers': followers,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'],
      bio: map['bio'],
      school: map['school'],
      address: map['address'],
      showDetails: map['showDetails'] is bool ? map['showDetails'] as bool : true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      following: List<String>.from(map['following'] ?? []),
      followers: List<String>.from(map['followers'] ?? []),
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? bio,
    String? school,
    String? address,
    bool? showDetails,
    DateTime? createdAt,
    List<String>? following,
    List<String>? followers,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      bio: bio ?? this.bio,
      school: school ?? this.school,
      address: address ?? this.address,
      showDetails: showDetails ?? this.showDetails,
      createdAt: createdAt ?? this.createdAt,
      following: following ?? this.following,
      followers: followers ?? this.followers,
    );
  }
}
