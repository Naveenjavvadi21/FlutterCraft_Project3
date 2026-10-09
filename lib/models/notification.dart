import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  like,
  comment,
  follow;

  String get value {
    switch (this) {
      case NotificationType.like:
        return 'like';
      case NotificationType.comment:
        return 'comment';
      case NotificationType.follow:
        return 'follow';
    }
  }

  static NotificationType fromString(String val) {
    switch (val) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      default:
        return NotificationType.like;
    }
  }
}

class AppNotification {
  final String id;
  final String recipientId;
  final String actorId;
  final String actorName;
  final String actorAvatar;
  final NotificationType type;
  final String? postId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.actorId,
    required this.actorName,
    this.actorAvatar = '',
    required this.type,
    this.postId,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  /// Factory constructor to parse from Firestore snapshot
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppNotification.fromMap(data, id: doc.id);
  }

  /// Factory constructor to parse from Map
  factory AppNotification.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parsedCreatedAt;
    final createdAtRaw = map['createdAt'];
    if (createdAtRaw is Timestamp) {
      parsedCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return AppNotification(
      id: id ?? map['id'] as String? ?? '',
      recipientId: map['recipientId'] as String? ?? '',
      actorId: map['actorId'] as String? ?? '',
      actorName: map['actorName'] as String? ?? 'Someone',
      actorAvatar: map['actorAvatar'] as String? ?? '',
      type: NotificationType.fromString(map['type'] as String? ?? 'like'),
      postId: map['postId'] as String?,
      message: map['message'] as String? ?? '',
      isRead: map['isRead'] as bool? ?? false,
      createdAt: parsedCreatedAt,
    );
  }

  /// Convert model to Firestore document map
  Map<String, dynamic> toMap() {
    return {
      'recipientId': recipientId,
      'actorId': actorId,
      'actorName': actorName,
      'actorAvatar': actorAvatar,
      'type': type.value,
      'postId': postId,
      'message': message,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppNotification copyWith({
    String? id,
    String? recipientId,
    String? actorId,
    String? actorName,
    String? actorAvatar,
    NotificationType? type,
    String? postId,
    String? message,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      actorId: actorId ?? this.actorId,
      actorName: actorName ?? this.actorName,
      actorAvatar: actorAvatar ?? this.actorAvatar,
      type: type ?? this.type,
      postId: postId ?? this.postId,
      message: message ?? this.message,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
