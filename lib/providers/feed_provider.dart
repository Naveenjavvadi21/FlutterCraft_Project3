import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';

enum FeedTab { following, explore }

class FeedProvider extends ChangeNotifier {
  final PostService _postService;
  final UserService _userService;

  FeedTab _currentTab = FeedTab.following;
  List<Post> _posts = [];
  bool _isLoadingInitial = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  String? _errorMessage;

  FeedProvider({
    PostService? postService,
    UserService? userService,
  })  : _postService = postService ?? PostService(),
        _userService = userService ?? UserService();

  FeedTab get currentTab => _currentTab;
  List<Post> get posts => _posts;
  bool get isLoadingInitial => _isLoadingInitial;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;

  void switchTab(FeedTab tab, String currentUserId) {
    if (_currentTab != tab) {
      _currentTab = tab;
      loadInitialFeed(currentUserId: currentUserId);
    }
  }

  /// Initial load or pull-to-refresh
  Future<void> loadInitialFeed({required String currentUserId}) async {
    _isLoadingInitial = true;
    _errorMessage = null;
    _lastDocument = null;
    notifyListeners();

    try {
      PaginatedResult<Post> result;

      if (_currentTab == FeedTab.following) {
        final followingIds = await _userService.getFollowingIds(currentUserId);
        result = await _postService.getFollowingFeed(
          followingIds: followingIds,
          currentUserId: currentUserId,
          lastDocument: null,
        );
      } else {
        result = await _postService.getExploreFeed(
          currentUserId: currentUserId,
          lastDocument: null,
        );
      }

      _posts = result.items;
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
    } catch (e) {
      _errorMessage = 'Failed to load feed: $e';
    } finally {
      _isLoadingInitial = false;
      notifyListeners();
    }
  }

  /// Infinite scroll cursor load
  Future<void> loadMore({required String currentUserId}) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      PaginatedResult<Post> result;

      if (_currentTab == FeedTab.following) {
        final followingIds = await _userService.getFollowingIds(currentUserId);
        result = await _postService.getFollowingFeed(
          followingIds: followingIds,
          currentUserId: currentUserId,
          lastDocument: _lastDocument,
        );
      } else {
        result = await _postService.getExploreFeed(
          currentUserId: currentUserId,
          lastDocument: _lastDocument,
        );
      }

      _posts.addAll(result.items);
      _lastDocument = result.lastDocument;
      _hasMore = result.hasMore;
    } catch (e) {
      debugPrint('Error loading more posts: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Create a new post and prepend to the feed
  Future<bool> createPost({
    required String text,
    String? imageUrl,
    required UserProfile currentUser,
  }) async {
    try {
      final post = await _postService.createPost(
        text: text,
        imageUrl: imageUrl,
        author: currentUser,
      );
      _posts.insert(0, post);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error creating post in FeedProvider: $e');
      return false;
    }
  }

  /// Optimistic Like / Unlike Toggle
  Future<void> toggleLike({
    required Post post,
    required UserProfile currentUser,
  }) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final wasLiked = post.isLikedByCurrentUser;
    final updatedLikesCount = wasLiked
        ? (post.likesCount - 1).clamp(0, 999999)
        : post.likesCount + 1;

    // Optimistic UI update
    _posts[index] = post.copyWith(
      isLikedByCurrentUser: !wasLiked,
      likesCount: updatedLikesCount,
    );
    notifyListeners();

    try {
      if (wasLiked) {
        await _postService.unlikePost(
          postId: post.id,
          currentUserId: currentUser.uid,
        );
      } else {
        await _postService.likePost(
          postId: post.id,
          currentUser: currentUser,
          postAuthorId: post.authorId,
        );
      }
    } catch (e) {
      // Revert if error occurs
      _posts[index] = post;
      notifyListeners();
    }
  }

  /// Add comment with optimistic count increment
  Future<CommentModel?> addComment({
    required String postId,
    required String text,
    required UserProfile currentUser,
    String? postAuthorId,
  }) async {
    try {
      final comment = await _postService.addComment(
        postId: postId,
        text: text,
        currentUser: currentUser,
        postAuthorId: postAuthorId,
      );

      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        final p = _posts[index];
        _posts[index] = p.copyWith(commentsCount: p.commentsCount + 1);
        notifyListeners();
      }

      return comment;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return null;
    }
  }

  /// Delete a post
  Future<bool> deletePost({
    required String postId,
    required String authorId,
  }) async {
    try {
      await _postService.deletePost(postId: postId, authorId: authorId);
      _posts.removeWhere((p) => p.id == postId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  /// Report a post
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    await _postService.reportPost(
      postId: postId,
      reporterId: reporterId,
      reason: reason,
      details: details,
    );
  }
}
