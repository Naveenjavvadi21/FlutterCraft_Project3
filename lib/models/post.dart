import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String text;
  final String? imageUrl;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final bool isLikedByCurrentUser;

  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar = '',
    required this.text,
    this.imageUrl,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
    this.isLikedByCurrentUser = false,
  });

  /// Factory constructor to parse from Firestore snapshot
  factory Post.fromFirestore(DocumentSnapshot doc, {bool isLiked = false}) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Post.fromMap(data, id: doc.id, isLiked: isLiked);
  }

  /// Factory constructor to parse from Map
  factory Post.fromMap(
    Map<String, dynamic> map, {
    String? id,
    bool isLiked = false,
  }) {
    DateTime parsedCreatedAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is Timestamp) {
      parsedCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Post(
      id: id ?? map['id'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'Anonymous',
      authorAvatar: map['authorAvatar'] as String? ?? '',
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      likesCount: (map['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (map['commentsCount'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
      isLikedByCurrentUser: isLiked || (map['isLikedByCurrentUser'] == true),
    );
  }

  /// Convert model to Firestore document map
  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'text': text,
      'imageUrl': imageUrl,
      'likesCount': likesCount,
      'commentsCount': commentsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    String? text,
    String? imageUrl,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    bool? isLikedByCurrentUser,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      isLikedByCurrentUser: isLikedByCurrentUser ?? this.isLikedByCurrentUser,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
