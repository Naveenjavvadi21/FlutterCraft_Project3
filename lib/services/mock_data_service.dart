import '../models/user_profile.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../models/notification.dart';

/// In-memory mock data store simulating Firestore collections,
/// batch writes, following graph, and atomic counter updates.
class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;

  MockDataService._internal() {
    _initMockData();
  }

  final Map<String, UserProfile> users = {};
  final List<Post> posts = [];
  final Map<String, List<CommentModel>> commentsByPost = {};
  final Map<String, Set<String>> likesByPost = {}; // postId -> set of uids
  final Map<String, Set<String>> followingByUser = {}; // uid -> set of targetUids
  final Map<String, Set<String>> followersByUser = {}; // uid -> set of followerUids
  final List<AppNotification> notifications = [];
  final Set<String> blockedUsers = {};

  UserProfile? currentMockUser;

  void _initMockData() {
    final now = DateTime.now();

    // 1. Mock Users
    final u1 = UserProfile(
      uid: 'user_alex',
      username: 'alex_rivers',
      displayName: 'Alex Rivers',
      bio: 'Mobile dev & UI enthusiast 🚀 Building Flutter apps with style.',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
      followersCount: 1420,
      followingCount: 380,
      postsCount: 14,
      createdAt: now.subtract(const Duration(days: 120)),
    );

    final u2 = UserProfile(
      uid: 'user_sophia',
      username: 'sophia_code',
      displayName: 'Sophia Chen',
      bio: 'Senior Cloud Architect @ TechForge. Coffee lover ☕️ | Firebase & Distributed Systems.',
      avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80',
      followersCount: 3100,
      followingCount: 420,
      postsCount: 28,
      createdAt: now.subtract(const Duration(days: 200)),
    );

    final u3 = UserProfile(
      uid: 'user_marcus',
      username: 'marcus_v',
      displayName: 'Marcus Vance',
      bio: 'Digital artist & photographer 📸 Creating high-res dreamscapes.',
      avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
      followersCount: 5200,
      followingCount: 150,
      postsCount: 45,
      createdAt: now.subtract(const Duration(days: 340)),
    );

    final u4 = UserProfile(
      uid: 'user_elena',
      username: 'elena_dev',
      displayName: 'Elena Rostova',
      bio: 'Fullstack Flutter + Go developer. Open source contributor 💻✨',
      avatarUrl: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=500&auto=format&fit=crop&q=80',
      followersCount: 890,
      followingCount: 210,
      postsCount: 9,
      createdAt: now.subtract(const Duration(days: 60)),
    );

    // Current default test user
    currentMockUser = UserProfile(
      uid: 'demo_user_me',
      username: 'jordan_craft',
      displayName: 'Jordan Craft',
      bio: 'Exploring SocialPulse! Flutter developer working on scalable social graphs.',
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=80',
      followersCount: 128,
      followingCount: 3,
      postsCount: 2,
      createdAt: now.subtract(const Duration(days: 15)),
    );

    users[u1.uid] = u1;
    users[u2.uid] = u2;
    users[u3.uid] = u3;
    users[u4.uid] = u4;
    users[currentMockUser!.uid] = currentMockUser!;

    // Initial Following relationships
    followingByUser[currentMockUser!.uid] = {u1.uid, u2.uid, u3.uid};
    followersByUser[u1.uid] = {currentMockUser!.uid};
    followersByUser[u2.uid] = {currentMockUser!.uid};
    followersByUser[u3.uid] = {currentMockUser!.uid};

    // 2. Mock Posts
    final p1 = Post(
      id: 'post_1',
      authorId: u2.uid,
      authorName: u2.displayName,
      authorAvatar: u2.avatarUrl,
      text: 'Just deployed our new cursor-based pagination architecture on Cloud Firestore! Query times dropped by 65% and costs scaled down drastically. Always leverage document snapshots as query cursors instead of high offsets. 🚀⚡️ #flutter #firebase #systemdesign',
      imageUrl: 'https://images.unsplash.com/photo-1558494949-ef010cbdcc31?w=800&auto=format&fit=crop&q=80',
      likesCount: 142,
      commentsCount: 18,
      createdAt: now.subtract(const Duration(minutes: 35)),
      isLikedByCurrentUser: true,
    );

    final p2 = Post(
      id: 'post_2',
      authorId: u3.uid,
      authorName: u3.displayName,
      authorAvatar: u3.avatarUrl,
      text: 'Golden hour in the mountains yesterday. Captured with a 50mm f/1.4 lens. Swipe to enjoy the natural tones without filter saturation. 🌄✨',
      imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&auto=format&fit=crop&q=80',
      likesCount: 389,
      commentsCount: 24,
      createdAt: now.subtract(const Duration(hours: 3)),
      isLikedByCurrentUser: false,
    );

    final p3 = Post(
      id: 'post_3',
      authorId: u1.uid,
      authorName: u1.displayName,
      authorAvatar: u1.avatarUrl,
      text: 'Why Firestore batch writes matter for social graphs:\n\n1. Atomic guarantee across 4 operations (follower ref, following ref, +2 counters)\n2. No partial updates if network drops midway\n3. Zero data inconsistency between users!\n\nAlways use batch.set() and batch.update(FieldValue.increment(1)) together. 💡',
      likesCount: 95,
      commentsCount: 8,
      createdAt: now.subtract(const Duration(hours: 6)),
      isLikedByCurrentUser: true,
    );

    final p4 = Post(
      id: 'post_4',
      authorId: u4.uid,
      authorName: u4.displayName,
      authorAvatar: u4.avatarUrl,
      text: 'Weekend hackathon project: an offline-first caching layer built on top of Flutter Provider and SQLite. Super smooth 120 FPS animations on all platforms! 💻📱',
      imageUrl: 'https://images.unsplash.com/photo-1526374965328-7f61d4dc18c5?w=800&auto=format&fit=crop&q=80',
      likesCount: 64,
      commentsCount: 5,
      createdAt: now.subtract(const Duration(hours: 14)),
      isLikedByCurrentUser: false,
    );

    final p5 = Post(
      id: 'post_5',
      authorId: currentMockUser!.uid,
      authorName: currentMockUser!.displayName,
      authorAvatar: currentMockUser!.avatarUrl,
      text: 'Excited to be on SocialPulse! Testing out the new dynamic feed and real-time interaction flows. Drop a comment below if you are building in Flutter too! 💙',
      likesCount: 32,
      commentsCount: 4,
      createdAt: now.subtract(const Duration(days: 1)),
      isLikedByCurrentUser: false,
    );

    final p6 = Post(
      id: 'post_6',
      authorId: u2.uid,
      authorName: u2.displayName,
      authorAvatar: u2.avatarUrl,
      text: 'Deep dive into Firestore Security Rules: Never trust client-sent timestamps or counter increments. Validate using request.time and request.resource.data! 🛡️',
      imageUrl: 'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?w=800&auto=format&fit=crop&q=80',
      likesCount: 215,
      commentsCount: 16,
      createdAt: now.subtract(const Duration(days: 2)),
      isLikedByCurrentUser: false,
    );

    final p7 = Post(
      id: 'post_7',
      authorId: u3.uid,
      authorName: u3.displayName,
      authorAvatar: u3.avatarUrl,
      text: 'Tokyo night cityscapes under the rain. The neon reflections are mesmerizing. 🌃🌧️',
      imageUrl: 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?w=800&auto=format&fit=crop&q=80',
      likesCount: 512,
      commentsCount: 37,
      createdAt: now.subtract(const Duration(days: 3)),
      isLikedByCurrentUser: true,
    );

    posts.addAll([p1, p2, p3, p4, p5, p6, p7]);

    // Likes tracking
    likesByPost[p1.id] = {currentMockUser!.uid, u1.uid, u3.uid};
    likesByPost[p2.id] = {u1.uid, u4.uid};
    likesByPost[p3.id] = {currentMockUser!.uid, u2.uid};
    likesByPost[p7.id] = {currentMockUser!.uid, u2.uid, u4.uid};

    // 3. Comments
    commentsByPost[p1.id] = [
      CommentModel(
        id: 'c1',
        authorId: u1.uid,
        authorName: u1.displayName,
        authorAvatar: u1.avatarUrl,
        text: 'Crucial lesson! Many people forget that offset-based queries still scan all preceding docs in Firestore.',
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
      CommentModel(
        id: 'c2',
        authorId: currentMockUser!.uid,
        authorName: currentMockUser!.displayName,
        authorAvatar: currentMockUser!.avatarUrl,
        text: 'Loved the explanation Sophia! Clean and practical architecture.',
        createdAt: now.subtract(const Duration(minutes: 10)),
      ),
    ];

    commentsByPost[p3.id] = [
      CommentModel(
        id: 'c3',
        authorId: u4.uid,
        authorName: u4.displayName,
        authorAvatar: u4.avatarUrl,
        text: 'Atomic increments are game changers for concurrent likes as well.',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    ];

    // 4. Notifications
    notifications.addAll([
      AppNotification(
        id: 'notif_1',
        recipientId: currentMockUser!.uid,
        actorId: u2.uid,
        actorName: u2.displayName,
        actorAvatar: u2.avatarUrl,
        type: NotificationType.like,
        postId: p5.id,
        message: 'liked your post: "Excited to be on SocialPulse!..."',
        isRead: false,
        createdAt: now.subtract(const Duration(minutes: 45)),
      ),
      AppNotification(
        id: 'notif_2',
        recipientId: currentMockUser!.uid,
        actorId: u1.uid,
        actorName: u1.displayName,
        actorAvatar: u1.avatarUrl,
        type: NotificationType.comment,
        postId: p5.id,
        message: 'commented: "Welcome aboard! Great to have you here."',
        isRead: false,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      AppNotification(
        id: 'notif_3',
        recipientId: currentMockUser!.uid,
        actorId: u3.uid,
        actorName: u3.displayName,
        actorAvatar: u3.avatarUrl,
        type: NotificationType.follow,
        message: 'started following you.',
        isRead: true,
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
    ]);
  }
}
