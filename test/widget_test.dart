import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialpulse/main.dart';
import 'package:socialpulse/models/post.dart';
import 'package:socialpulse/models/user_profile.dart';
import 'package:socialpulse/models/comment.dart';
import 'package:socialpulse/models/notification.dart';
import 'package:socialpulse/widgets/like_button.dart';
import 'package:socialpulse/widgets/user_avatar.dart';

void main() {
  group('SocialPulse Model Tests', () {
    test('UserProfile serialization and copyWith', () {
      final now = DateTime.now();
      final user = UserProfile(
        uid: 'user_test_123',
        username: 'testuser',
        displayName: 'Test User',
        bio: 'Hello world',
        avatarUrl: 'https://example.com/avatar.jpg',
        followersCount: 10,
        followingCount: 5,
        postsCount: 2,
        createdAt: now,
      );

      final map = user.toMap();
      expect(map['uid'], 'user_test_123');
      expect(map['username'], 'testuser');
      expect(map['followersCount'], 10);

      final fromMap = UserProfile.fromMap(map, uid: user.uid);
      expect(fromMap.uid, user.uid);
      expect(fromMap.username, user.username);
      expect(fromMap.followersCount, 10);

      final updated = user.copyWith(followersCount: 11);
      expect(updated.followersCount, 11);
      expect(updated.followingCount, 5);
    });

    test('Post serialization and copyWith', () {
      final now = DateTime.now();
      final post = Post(
        id: 'post_123',
        authorId: 'author_1',
        authorName: 'Alex Rivers',
        text: 'Exploring cursor-based pagination!',
        likesCount: 15,
        commentsCount: 3,
        createdAt: now,
      );

      final map = post.toMap();
      expect(map['authorId'], 'author_1');
      expect(map['likesCount'], 15);

      final fromMap = Post.fromMap(map, id: post.id, isLiked: true);
      expect(fromMap.id, post.id);
      expect(fromMap.isLikedByCurrentUser, true);

      final liked = post.copyWith(likesCount: 16, isLikedByCurrentUser: true);
      expect(liked.likesCount, 16);
      expect(liked.isLikedByCurrentUser, true);
    });

    test('CommentModel serialization', () {
      final now = DateTime.now();
      final comment = CommentModel(
        id: 'comment_1',
        authorId: 'user_1',
        authorName: 'Sophia',
        text: 'Great architecture design!',
        createdAt: now,
      );

      final map = comment.toMap();
      expect(map['text'], 'Great architecture design!');

      final fromMap = CommentModel.fromMap(map, id: comment.id);
      expect(fromMap.id, comment.id);
      expect(fromMap.authorName, 'Sophia');
    });

    test('AppNotification model serialization and types', () {
      final now = DateTime.now();
      final notif = AppNotification(
        id: 'notif_1',
        recipientId: 'user_1',
        actorId: 'user_2',
        actorName: 'Marcus',
        type: NotificationType.like,
        postId: 'post_99',
        message: 'liked your post.',
        isRead: false,
        createdAt: now,
      );

      final map = notif.toMap();
      expect(map['type'], 'like');
      expect(map['postId'], 'post_99');

      final fromMap = AppNotification.fromMap(map, id: notif.id);
      expect(fromMap.type, NotificationType.like);
      expect(fromMap.isRead, false);
    });
  });

  group('SocialPulse Widget Tests', () {
    testWidgets('UserAvatar renders initials when no image provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(name: 'Alex Rivers', radius: 24),
          ),
        ),
      );

      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('LikeButton renders initial count and responds to tap',
        (WidgetTester tester) async {
      int count = 42;
      bool isLiked = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: LikeButton(
                  isLiked: isLiked,
                  count: count,
                  onTap: () {
                    setState(() {
                      isLiked = !isLiked;
                      count += isLiked ? 1 : -1;
                    });
                  },
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('42'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      await tester.tap(find.byType(LikeButton));
      await tester.pumpAndSettle();

      expect(find.text('43'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('SocialPulseApp boots to login or feed screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const SocialPulseApp(isFirebaseReady: true),
      );

      await tester.pump();
      // App loads cleanly
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
