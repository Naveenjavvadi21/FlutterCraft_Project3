class AppConstants {
  static const String appName = 'SocialPulse';
  static const String appTagline = 'Connect, share, and inspire in real time';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String postsCollection = 'posts';
  static const String notificationsCollection = 'notifications';
  static const String reportsCollection = 'reports';
  static const String blocksCollection = 'blocks';

  // Subcollections
  static const String followingSubcollection = 'following';
  static const String followersSubcollection = 'followers';
  static const String likesSubcollection = 'likes';
  static const String commentsSubcollection = 'comments';

  // Pagination limit
  static const int feedPageSize = 10;
  static const int commentsPageSize = 20;

  // Max Firestore whereIn items (Firestore hard limit is 30)
  static const int firestoreWhereInLimit = 30;

  // Storage paths
  static const String avatarStoragePath = 'avatars';
  static const String postImagesStoragePath = 'post_images';
}
