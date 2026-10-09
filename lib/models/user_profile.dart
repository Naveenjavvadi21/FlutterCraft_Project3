import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String displayName;
  final String bio;
  final String avatarUrl;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final DateTime createdAt;

  const UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    this.bio = '',
    this.avatarUrl = '',
    this.followersCount = 0,
    this.followingCount = 0,
    this.postsCount = 0,
    required this.createdAt,
  });

  /// Factory constructor to parse from Firestore snapshot
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserProfile.fromMap(data, uid: doc.id);
  }

  /// Factory constructor to parse from Map
  factory UserProfile.fromMap(Map<String, dynamic> map, {String? uid}) {
    DateTime parsedCreatedAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is Timestamp) {
      parsedCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return UserProfile(
      uid: uid ?? map['uid'] as String? ?? '',
      username: map['username'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      avatarUrl: map['avatarUrl'] as String? ?? '',
      followersCount: (map['followersCount'] as num?)?.toInt() ?? 0,
      followingCount: (map['followingCount'] as num?)?.toInt() ?? 0,
      postsCount: (map['postsCount'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
    );
  }

  /// Convert model to Firestore document map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'bio': bio,
      'avatarUrl': avatarUrl,
      'followersCount': followersCount,
      'followingCount': followingCount,
      'postsCount': postsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  UserProfile copyWith({
    String? uid,
    String? username,
    String? displayName,
    String? bio,
    String? avatarUrl,
    int? followersCount,
    int? followingCount,
    int? postsCount,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          uid == other.uid;

  @override
  int get hashCode => uid.hashCode;
}
