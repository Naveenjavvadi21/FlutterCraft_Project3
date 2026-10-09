import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import 'mock_data_service.dart';

class UserService {
  final FirebaseFirestore? _customFirestore;
  final MockDataService _mock = MockDataService();

  UserService({FirebaseFirestore? firestore}) : _customFirestore = firestore;

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    if (!DefaultFirebaseOptions.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Fetch a user profile by ID
  Future<UserProfile?> getUserProfile(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      return _mock.users[uid];
    }

    try {
      final doc = await firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .get();
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return _mock.users[uid];
    }
  }

  /// Create or update user profile document
  Future<void> saveUserProfile(UserProfile profile) async {
    final firestore = _firestore;
    if (firestore == null) {
      _mock.users[profile.uid] = profile;
      if (_mock.currentMockUser?.uid == profile.uid) {
        _mock.currentMockUser = profile;
      }
      return;
    }

    try {
      await firestore
          .collection(AppConstants.usersCollection)
          .doc(profile.uid)
          .set(profile.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      _mock.users[profile.uid] = profile;
    }
  }

  /// Check if current user is following target user
  Future<bool> isFollowing({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return false;

    final firestore = _firestore;
    if (firestore == null) {
      return _mock.followingByUser[currentUserId]?.contains(targetUserId) ??
          false;
    }

    try {
      final doc = await firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.followingSubcollection)
          .doc(targetUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking follow status: $e');
      return _mock.followingByUser[currentUserId]?.contains(targetUserId) ??
          false;
    }
  }

  /// Follow a user using atomic Firestore batch write
  /// Updates:
  /// 1. users/{currentUserId}/following/{targetUserId}
  /// 2. users/{targetUserId}/followers/{currentUserId}
  /// 3. users/{currentUserId} followingCount + 1
  /// 4. users/{targetUserId} followersCount + 1
  Future<void> followUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;

    final firestore = _firestore;
    if (firestore == null) {
      // In-memory atomic update
      _mock.followingByUser.putIfAbsent(currentUserId, () => {}).add(targetUserId);
      _mock.followersByUser.putIfAbsent(targetUserId, () => {}).add(currentUserId);

      final current = _mock.users[currentUserId];
      if (current != null) {
        _mock.users[currentUserId] = current.copyWith(
          followingCount: current.followingCount + 1,
        );
        if (_mock.currentMockUser?.uid == currentUserId) {
          _mock.currentMockUser = _mock.users[currentUserId];
        }
      }

      final target = _mock.users[targetUserId];
      if (target != null) {
        _mock.users[targetUserId] = target.copyWith(
          followersCount: target.followersCount + 1,
        );
      }
      return;
    }

    try {
      final batch = firestore.batch();

      final followingRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.followingSubcollection)
          .doc(targetUserId);

      final followerRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(targetUserId)
          .collection(AppConstants.followersSubcollection)
          .doc(currentUserId);

      final currentUserRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId);

      final targetUserRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(targetUserId);

      final followData = {'timestamp': FieldValue.serverTimestamp()};

      batch.set(followingRef, followData);
      batch.set(followerRef, followData);

      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error following user: $e');
      rethrow;
    }
  }

  /// Unfollow a user using atomic Firestore batch write
  /// Updates:
  /// 1. Delete users/{currentUserId}/following/{targetUserId}
  /// 2. Delete users/{targetUserId}/followers/{currentUserId}
  /// 3. users/{currentUserId} followingCount - 1
  /// 4. users/{targetUserId} followersCount - 1
  Future<void> unfollowUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    if (currentUserId == targetUserId) return;

    final firestore = _firestore;
    if (firestore == null) {
      _mock.followingByUser[currentUserId]?.remove(targetUserId);
      _mock.followersByUser[targetUserId]?.remove(currentUserId);

      final current = _mock.users[currentUserId];
      if (current != null) {
        final newCount = (current.followingCount - 1).clamp(0, 9999999);
        _mock.users[currentUserId] = current.copyWith(followingCount: newCount);
        if (_mock.currentMockUser?.uid == currentUserId) {
          _mock.currentMockUser = _mock.users[currentUserId];
        }
      }

      final target = _mock.users[targetUserId];
      if (target != null) {
        final newCount = (target.followersCount - 1).clamp(0, 9999999);
        _mock.users[targetUserId] = target.copyWith(followersCount: newCount);
      }
      return;
    }

    try {
      final batch = firestore.batch();

      final followingRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId)
          .collection(AppConstants.followingSubcollection)
          .doc(targetUserId);

      final followerRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(targetUserId)
          .collection(AppConstants.followersSubcollection)
          .doc(currentUserId);

      final currentUserRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(currentUserId);

      final targetUserRef = firestore
          .collection(AppConstants.usersCollection)
          .doc(targetUserId);

      batch.delete(followingRef);
      batch.delete(followerRef);

      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error unfollowing user: $e');
      rethrow;
    }
  }

  /// Get list of IDs followed by a user
  Future<List<String>> getFollowingIds(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      return _mock.followingByUser[uid]?.toList() ?? [];
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.followingSubcollection)
          .get();
      return snapshot.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('Error fetching following IDs: $e');
      return _mock.followingByUser[uid]?.toList() ?? [];
    }
  }

  /// Get list of UserProfiles that this user is following
  Future<List<UserProfile>> getFollowingList(String uid) async {
    final ids = await getFollowingIds(uid);
    if (ids.isEmpty) return [];

    final List<UserProfile> result = [];
    for (final id in ids) {
      final profile = await getUserProfile(id);
      if (profile != null) {
        result.add(profile);
      }
    }
    return result;
  }

  /// Get list of UserProfiles following this user
  Future<List<UserProfile>> getFollowersList(String uid) async {
    final firestore = _firestore;
    if (firestore == null) {
      final followerIds = _mock.followersByUser[uid]?.toList() ?? [];
      final list = <UserProfile>[];
      for (final id in followerIds) {
        final u = _mock.users[id];
        if (u != null) list.add(u);
      }
      return list;
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.followersSubcollection)
          .get();

      final List<UserProfile> result = [];
      for (final doc in snapshot.docs) {
        final profile = await getUserProfile(doc.id);
        if (profile != null) {
          result.add(profile);
        }
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching followers list: $e');
      return [];
    }
  }

  /// Search users by username or displayName
  Future<List<UserProfile>> searchUsers(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final firestore = _firestore;
    if (firestore == null) {
      return _mock.users.values.where((u) {
        return u.username.toLowerCase().contains(cleanQuery) ||
            u.displayName.toLowerCase().contains(cleanQuery);
      }).toList();
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.usersCollection)
          .where('username', isGreaterThanOrEqualTo: cleanQuery)
          .where('username', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(20)
          .get();

      return snapshot.docs.map((d) => UserProfile.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('Error searching users in Firestore: $e');
      return _mock.users.values.where((u) {
        return u.username.toLowerCase().contains(cleanQuery) ||
            u.displayName.toLowerCase().contains(cleanQuery);
      }).toList();
    }
  }

  /// Block a user
  Future<void> blockUser(String currentUserId, String targetUserId) async {
    _mock.blockedUsers.add(targetUserId);

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection(AppConstants.usersCollection)
            .doc(currentUserId)
            .collection(AppConstants.blocksCollection)
            .doc(targetUserId)
            .set({'timestamp': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('Error blocking user in Firestore: $e');
      }
    }
  }

  /// Check if target user is blocked
  bool isBlocked(String targetUserId) {
    return _mock.blockedUsers.contains(targetUserId);
  }
}
