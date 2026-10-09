import 'package:flutter/material.dart';
import '../models/notification.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';

class ProfileProvider extends ChangeNotifier {
  final UserService _userService;
  final PostService _postService;
  final NotificationService _notificationService;

  UserProfile? _profile;
  List<Post> _userPosts = [];
  bool _isFollowing = false;
  bool _isLoading = false;
  String? _errorMessage;

  ProfileProvider({
    UserService? userService,
    PostService? postService,
    NotificationService? notificationService,
  })  : _userService = userService ?? UserService(),
        _postService = postService ?? PostService(),
        _notificationService = notificationService ?? NotificationService();

  UserProfile? get profile => _profile;
  List<Post> get userPosts => _userPosts;
  bool get isFollowing => _isFollowing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Load a user's profile and their posts
  Future<void> loadProfile({
    required String targetUserId,
    required String currentUserId,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _userService.getUserProfile(targetUserId);
      _profile = user;

      if (currentUserId != targetUserId) {
        _isFollowing = await _userService.isFollowing(
          currentUserId: currentUserId,
          targetUserId: targetUserId,
        );
      } else {
        _isFollowing = false;
      }

      _userPosts = await _postService.getUserPosts(
        userId: targetUserId,
        currentUserId: currentUserId,
      );
    } catch (e) {
      _errorMessage = 'Failed to load profile: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// ⭐ Toggle Follow / Unfollow using Firestore Batch Writes
  Future<void> toggleFollow({
    required UserProfile currentUser,
  }) async {
    if (_profile == null || currentUser.uid == _profile!.uid) return;

    final wasFollowing = _isFollowing;
    final currentProfile = _profile!;
    final newFollowersCount = wasFollowing
        ? (currentProfile.followersCount - 1).clamp(0, 9999999)
        : currentProfile.followersCount + 1;

    // Optimistic UI update
    _isFollowing = !wasFollowing;
    _profile = currentProfile.copyWith(followersCount: newFollowersCount);
    notifyListeners();

    try {
      if (wasFollowing) {
        await _userService.unfollowUser(
          currentUserId: currentUser.uid,
          targetUserId: currentProfile.uid,
        );
      } else {
        await _userService.followUser(
          currentUserId: currentUser.uid,
          targetUserId: currentProfile.uid,
        );

        // Send follow notification
        await _notificationService.sendNotification(
          recipientId: currentProfile.uid,
          actor: currentUser,
          type: NotificationType.follow,
          message: 'started following you.',
        );
      }
    } catch (e) {
      // Revert if write fails
      _isFollowing = wasFollowing;
      _profile = currentProfile;
      notifyListeners();
    }
  }

  /// Update bio and display name
  Future<void> updateBio({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    if (_profile == null) return;

    final updated = _profile!.copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl ?? _profile!.avatarUrl,
    );

    await _userService.saveUserProfile(updated);
    _profile = updated;
    notifyListeners();
  }

  /// Refresh posts
  Future<void> refreshPosts(String currentUserId) async {
    if (_profile == null) return;
    _userPosts = await _postService.getUserPosts(
      userId: _profile!.uid,
      currentUserId: currentUserId,
    );
    notifyListeners();
  }
}
