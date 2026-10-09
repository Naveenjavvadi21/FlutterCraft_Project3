import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';
import '../models/notification.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import 'mock_data_service.dart';

class NotificationService {
  final FirebaseFirestore? _customFirestore;
  final MockDataService _mock = MockDataService();

  NotificationService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    if (!DefaultFirebaseOptions.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Send an in-app social notification
  Future<void> sendNotification({
    required String recipientId,
    required UserProfile actor,
    required NotificationType type,
    String? postId,
    required String message,
  }) async {
    // Avoid notifying yourself
    if (recipientId == actor.uid) return;

    final notifId = const Uuid().v4();
    final notif = AppNotification(
      id: notifId,
      recipientId: recipientId,
      actorId: actor.uid,
      actorName: actor.displayName,
      actorAvatar: actor.avatarUrl,
      type: type,
      postId: postId,
      message: message,
      isRead: false,
      createdAt: DateTime.now(),
    );

    final firestore = _firestore;
    if (firestore == null) {
      _mock.notifications.insert(0, notif);
      return;
    }

    try {
      await firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notifId)
          .set(notif.toMap());
    } catch (e) {
      debugPrint('Error sending notification: $e');
      _mock.notifications.insert(0, notif);
    }
  }

  /// Get notifications list for recipient
  Future<List<AppNotification>> getNotifications(String recipientId) async {
    final firestore = _firestore;
    if (firestore == null) {
      final list = _mock.notifications
          .where((n) => n.recipientId == recipientId)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.notificationsCollection)
          .where('recipientId', isEqualTo: recipientId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((d) => AppNotification.fromFirestore(d))
          .toList();
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      return _mock.notifications
          .where((n) => n.recipientId == recipientId)
          .toList();
    }
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId) async {
    final firestore = _firestore;
    if (firestore == null) {
      final idx = _mock.notifications.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        _mock.notifications[idx] = _mock.notifications[idx].copyWith(isRead: true);
      }
      return;
    }

    try {
      await firestore
          .collection(AppConstants.notificationsCollection)
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read for recipient
  Future<void> markAllAsRead(String recipientId) async {
    final firestore = _firestore;
    if (firestore == null) {
      for (int i = 0; i < _mock.notifications.length; i++) {
        if (_mock.notifications[i].recipientId == recipientId) {
          _mock.notifications[i] = _mock.notifications[i].copyWith(isRead: true);
        }
      }
      return;
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.notificationsCollection)
          .where('recipientId', isEqualTo: recipientId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }
}
