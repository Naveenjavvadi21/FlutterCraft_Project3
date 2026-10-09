import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';
import '../models/comment.dart';
import '../models/post.dart';
import '../models/user_profile.dart';
import '../models/notification.dart';
import '../utils/constants.dart';
import 'mock_data_service.dart';
import 'notification_service.dart';

/// Container for cursor-paginated result sets
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });
}

class PostService {
  final FirebaseFirestore? _customFirestore;
  final NotificationService _notificationService;
  final MockDataService _mock = MockDataService();

  PostService({
    FirebaseFirestore? firestore,
    NotificationService? notificationService,
  })  : _customFirestore = firestore,
        _notificationService = notificationService ?? NotificationService();

  FirebaseFirestore? get _firestore {
    if (_customFirestore != null) return _customFirestore;
    if (!DefaultFirebaseOptions.isConfigured) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  /// Create a new post (text or image) and atomically increment user's postsCount
  Future<Post> createPost({
    required String text,
    String? imageUrl,
    required UserProfile author,
  }) async {
    final postId = const Uuid().v4();
    final now = DateTime.now();

    final newPost = Post(
      id: postId,
      authorId: author.uid,
      authorName: author.displayName,
      authorAvatar: author.avatarUrl,
      text: text,
      imageUrl: imageUrl,
      likesCount: 0,
      commentsCount: 0,
      createdAt: now,
      isLikedByCurrentUser: false,
    );

    final firestore = _firestore;
    if (firestore == null) {
      _mock.posts.insert(0, newPost);
      // Update mock user post count
      final user = _mock.users[author.uid];
      if (user != null) {
        _mock.users[author.uid] = user.copyWith(postsCount: user.postsCount + 1);
        if (_mock.currentMockUser?.uid == author.uid) {
          _mock.currentMockUser = _mock.users[author.uid];
        }
      }
      return newPost;
    }

    try {
      final batch = firestore.batch();
      final postRef = firestore.collection(AppConstants.postsCollection).doc(postId);
      final userRef = firestore.collection(AppConstants.usersCollection).doc(author.uid);

      batch.set(postRef, newPost.toMap());
      batch.update(userRef, {
        'postsCount': FieldValue.increment(1),
      });

      await batch.commit();
      return newPost;
    } catch (e) {
      debugPrint('Error creating post in Firestore: $e');
      _mock.posts.insert(0, newPost);
      return newPost;
    }
  }

  /// Delete a post and decrement user's postsCount
  Future<void> deletePost({
    required String postId,
    required String authorId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      _mock.posts.removeWhere((p) => p.id == postId);
      final user = _mock.users[authorId];
      if (user != null) {
        final newCount = (user.postsCount - 1).clamp(0, 999999);
        _mock.users[authorId] = user.copyWith(postsCount: newCount);
      }
      return;
    }

    try {
      final batch = firestore.batch();
      final postRef = firestore.collection(AppConstants.postsCollection).doc(postId);
      final userRef = firestore.collection(AppConstants.usersCollection).doc(authorId);

      batch.delete(postRef);
      batch.update(userRef, {
        'postsCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting post in Firestore: $e');
      _mock.posts.removeWhere((p) => p.id == postId);
    }
  }

  /// ⭐ Cursor-Based Paginated Feed (Personalized for Followed Users + Self)
  ///
  /// Uses startAfterDocument(lastDoc) for infinite scrolling.
  /// Firestore whereIn allows up to 30 elements.
  Future<PaginatedResult<Post>> getFollowingFeed({
    required List<String> followingIds,
    required String currentUserId,
    DocumentSnapshot? lastDocument,
    int limit = AppConstants.feedPageSize,
  }) async {
    // Author set includes following list + current user
    final feedAuthorIds = {...followingIds, currentUserId}.toList();

    final firestore = _firestore;
    if (firestore == null) {
      // In-memory cursor pagination simulation
      final filtered = _mock.posts.where((p) {
        if (_mock.blockedUsers.contains(p.authorId)) return false;
        return feedAuthorIds.contains(p.authorId);
      }).toList();

      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      int startIndex = 0;
      if (lastDocument != null) {
        final idx = filtered.indexWhere((p) => p.id == lastDocument.id);
        if (idx != -1) startIndex = idx + 1;
      }

      final page = filtered.skip(startIndex).take(limit).toList();
      final hasMore = (startIndex + page.length) < filtered.length;

      // Populate like status
      final enriched = page.map((p) {
        final isLiked = _mock.likesByPost[p.id]?.contains(currentUserId) ?? false;
        return p.copyWith(isLikedByCurrentUser: isLiked);
      }).toList();

      return PaginatedResult(
        items: enriched,
        lastDocument: null,
        hasMore: hasMore,
      );
    }

    try {
      // Cap at 30 authors for Firestore `whereIn` limit
      final queriedAuthors = feedAuthorIds.take(AppConstants.firestoreWhereInLimit).toList();

      Query query = firestore
          .collection(AppConstants.postsCollection)
          .where('authorId', whereIn: queriedAuthors)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final hasMore = docs.length == limit;
      final lastDoc = docs.isNotEmpty ? docs.last : null;

      final posts = <Post>[];
      for (final doc in docs) {
        final isLiked = await isPostLiked(
          postId: doc.id,
          currentUserId: currentUserId,
        );
        posts.add(Post.fromFirestore(doc, isLiked: isLiked));
      }

      return PaginatedResult(
        items: posts,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('Error getting following feed: $e');
      return getExploreFeed(
        currentUserId: currentUserId,
        lastDocument: lastDocument,
        limit: limit,
      );
    }
  }

  /// ⭐ Cursor-Based Paginated Feed (Explore / All Posts)
  ///
  /// Demonstrates infinite scrolling on the global timeline.
  Future<PaginatedResult<Post>> getExploreFeed({
    required String currentUserId,
    DocumentSnapshot? lastDocument,
    int limit = AppConstants.feedPageSize,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      final unblocked = _mock.posts
          .where((p) => !_mock.blockedUsers.contains(p.authorId))
          .toList();
      unblocked.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      int startIndex = 0;
      if (lastDocument != null) {
        final idx = unblocked.indexWhere((p) => p.id == lastDocument.id);
        if (idx != -1) startIndex = idx + 1;
      }

      final page = unblocked.skip(startIndex).take(limit).toList();
      final hasMore = (startIndex + page.length) < unblocked.length;

      final enriched = page.map((p) {
        final isLiked = _mock.likesByPost[p.id]?.contains(currentUserId) ?? false;
        return p.copyWith(isLikedByCurrentUser: isLiked);
      }).toList();

      return PaginatedResult(
        items: enriched,
        lastDocument: null,
        hasMore: hasMore,
      );
    }

    try {
      Query query = firestore
          .collection(AppConstants.postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      final docs = snapshot.docs;
      final hasMore = docs.length == limit;
      final lastDoc = docs.isNotEmpty ? docs.last : null;

      final posts = <Post>[];
      for (final doc in docs) {
        final isLiked = await isPostLiked(
          postId: doc.id,
          currentUserId: currentUserId,
        );
        posts.add(Post.fromFirestore(doc, isLiked: isLiked));
      }

      return PaginatedResult(
        items: posts,
        lastDocument: lastDoc,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('Error getting explore feed: $e');
      return PaginatedResult(items: [], hasMore: false);
    }
  }

  /// Fetch posts written by a specific user (profile grid/list)
  Future<List<Post>> getUserPosts({
    required String userId,
    required String currentUserId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      final list = _mock.posts.where((p) => p.authorId == userId).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list.map((p) {
        final isLiked = _mock.likesByPost[p.id]?.contains(currentUserId) ?? false;
        return p.copyWith(isLikedByCurrentUser: isLiked);
      }).toList();
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.postsCollection)
          .where('authorId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      final posts = <Post>[];
      for (final doc in snapshot.docs) {
        final isLiked = await isPostLiked(
          postId: doc.id,
          currentUserId: currentUserId,
        );
        posts.add(Post.fromFirestore(doc, isLiked: isLiked));
      }
      return posts;
    } catch (e) {
      debugPrint('Error fetching user posts: $e');
      return [];
    }
  }

  /// Check whether the current user liked a specific post
  Future<bool> isPostLiked({
    required String postId,
    required String currentUserId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      return _mock.likesByPost[postId]?.contains(currentUserId) ?? false;
    }

    try {
      final doc = await firestore
          .collection(AppConstants.postsCollection)
          .doc(postId)
          .collection(AppConstants.likesSubcollection)
          .doc(currentUserId)
          .get();
      return doc.exists;
    } catch (e) {
      debugPrint('Error checking like status: $e');
      return false;
    }
  }

  /// ⭐ Like a post using Atomic Counter + Subcollection
  Future<void> likePost({
    required String postId,
    required UserProfile currentUser,
    String? postAuthorId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      _mock.likesByPost.putIfAbsent(postId, () => {}).add(currentUser.uid);
      final idx = _mock.posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _mock.posts[idx];
        _mock.posts[idx] = p.copyWith(
          likesCount: p.likesCount + 1,
          isLikedByCurrentUser: true,
        );

        if (p.authorId != currentUser.uid) {
          await _notificationService.sendNotification(
            recipientId: p.authorId,
            actor: currentUser,
            type: NotificationType.like,
            postId: postId,
            message: 'liked your post.',
          );
        }
      }
      return;
    }

    try {
      final batch = firestore.batch();
      final postRef = firestore.collection(AppConstants.postsCollection).doc(postId);
      final likeRef = postRef.collection(AppConstants.likesSubcollection).doc(currentUser.uid);

      batch.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
      batch.update(postRef, {'likesCount': FieldValue.increment(1)});

      await batch.commit();

      if (postAuthorId != null && postAuthorId != currentUser.uid) {
        await _notificationService.sendNotification(
          recipientId: postAuthorId,
          actor: currentUser,
          type: NotificationType.like,
          postId: postId,
          message: 'liked your post.',
        );
      }
    } catch (e) {
      debugPrint('Error liking post in Firestore: $e');
      rethrow;
    }
  }

  /// ⭐ Unlike a post using Atomic Counter + Subcollection
  Future<void> unlikePost({
    required String postId,
    required String currentUserId,
  }) async {
    final firestore = _firestore;
    if (firestore == null) {
      _mock.likesByPost[postId]?.remove(currentUserId);
      final idx = _mock.posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _mock.posts[idx];
        final newCount = (p.likesCount - 1).clamp(0, 999999);
        _mock.posts[idx] = p.copyWith(
          likesCount: newCount,
          isLikedByCurrentUser: false,
        );
      }
      return;
    }

    try {
      final batch = firestore.batch();
      final postRef = firestore.collection(AppConstants.postsCollection).doc(postId);
      final likeRef = postRef.collection(AppConstants.likesSubcollection).doc(currentUserId);

      batch.delete(likeRef);
      batch.update(postRef, {'likesCount': FieldValue.increment(-1)});

      await batch.commit();
    } catch (e) {
      debugPrint('Error unliking post in Firestore: $e');
      rethrow;
    }
  }

  /// Add a comment to a post with atomic commentsCount increment
  Future<CommentModel> addComment({
    required String postId,
    required String text,
    required UserProfile currentUser,
    String? postAuthorId,
  }) async {
    final commentId = const Uuid().v4();
    final now = DateTime.now();

    final comment = CommentModel(
      id: commentId,
      authorId: currentUser.uid,
      authorName: currentUser.displayName,
      authorAvatar: currentUser.avatarUrl,
      text: text,
      createdAt: now,
    );

    final firestore = _firestore;
    if (firestore == null) {
      _mock.commentsByPost.putIfAbsent(postId, () => []).add(comment);
      final idx = _mock.posts.indexWhere((p) => p.id == postId);
      if (idx != -1) {
        final p = _mock.posts[idx];
        _mock.posts[idx] = p.copyWith(commentsCount: p.commentsCount + 1);

        if (p.authorId != currentUser.uid) {
          await _notificationService.sendNotification(
            recipientId: p.authorId,
            actor: currentUser,
            type: NotificationType.comment,
            postId: postId,
            message: 'commented: "$text"',
          );
        }
      }
      return comment;
    }

    try {
      final batch = firestore.batch();
      final postRef = firestore.collection(AppConstants.postsCollection).doc(postId);
      final commentRef = postRef.collection(AppConstants.commentsSubcollection).doc(commentId);

      batch.set(commentRef, comment.toMap());
      batch.update(postRef, {'commentsCount': FieldValue.increment(1)});

      await batch.commit();

      if (postAuthorId != null && postAuthorId != currentUser.uid) {
        await _notificationService.sendNotification(
          recipientId: postAuthorId,
          actor: currentUser,
          type: NotificationType.comment,
          postId: postId,
          message: 'commented: "$text"',
        );
      }
      return comment;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      _mock.commentsByPost.putIfAbsent(postId, () => []).add(comment);
      return comment;
    }
  }

  /// Get comments for a post
  Future<List<CommentModel>> getComments(String postId) async {
    final firestore = _firestore;
    if (firestore == null) {
      final list = _mock.commentsByPost[postId] ?? [];
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.postsCollection)
          .doc(postId)
          .collection(AppConstants.commentsSubcollection)
          .orderBy('createdAt', descending: false)
          .limit(AppConstants.commentsPageSize)
          .get();

      return snapshot.docs.map((d) => CommentModel.fromFirestore(d)).toList();
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      return _mock.commentsByPost[postId] ?? [];
    }
  }

  /// Report a post
  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
    String? details,
  }) async {
    final reportId = const Uuid().v4();
    final data = {
      'reportId': reportId,
      'postId': postId,
      'reporterId': reporterId,
      'reason': reason,
      'details': details ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    };

    final firestore = _firestore;
    if (firestore != null) {
      try {
        await firestore
            .collection(AppConstants.reportsCollection)
            .doc(reportId)
            .set(data);
      } catch (e) {
        debugPrint('Error reporting post: $e');
      }
    }
  }

  /// Search posts by keyword or hashtag
  Future<List<Post>> searchPosts({
    required String query,
    required String currentUserId,
  }) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final firestore = _firestore;
    if (firestore == null) {
      return _mock.posts.where((p) {
        return p.text.toLowerCase().contains(clean) ||
            p.authorName.toLowerCase().contains(clean);
      }).map((p) {
        final isLiked = _mock.likesByPost[p.id]?.contains(currentUserId) ?? false;
        return p.copyWith(isLikedByCurrentUser: isLiked);
      }).toList();
    }

    try {
      final snapshot = await firestore
          .collection(AppConstants.postsCollection)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      final matching = <Post>[];
      for (final doc in snapshot.docs) {
        final text = (doc.data()['text'] as String? ?? '').toLowerCase();
        if (text.contains(clean)) {
          final isLiked = await isPostLiked(
            postId: doc.id,
            currentUserId: currentUserId,
          );
          matching.add(Post.fromFirestore(doc, isLiked: isLiked));
        }
      }
      return matching;
    } catch (e) {
      debugPrint('Error searching posts: $e');
      return [];
    }
  }
}
