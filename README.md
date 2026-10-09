# SocialPulse 📱✨
### The Modern Realtime Social Media Application in Flutter & Firebase
**Capstone Project 3 — Advanced Agentic & Mobile Engineering Sequence**

---

## 🌟 Overview

**SocialPulse** is the third major capstone project in the FlutterCraft portfolio sequence. It builds on the real-time Firebase streams from the **Chat App (Project 1)** and state management architectures from the **E-Commerce App (Project 2)**, advancing into:

- Complex social graphs and relationship modeling
- Cursor-based feed pagination and infinite scrolling
- Atomic counter management and denormalization
- Content interactions (likes, nested comments, reporting, user blocking)
- Actor-driven push notifications

---

## 🏗️ Architecture & Project Structure

The project strictly follows a clean layered separation of concerns:

```
lib/
├── main.dart                      # App entry point, Firebase init, Theme & MultiProvider setup
│
├── models/                        # Domain models with Firestore mapping & copyWith
│   ├── user_profile.dart          # User profile model & counter fields
│   ├── post.dart                  # Post entity with optimistic like flags
│   ├── comment.dart               # Comment model with author details
│   └── notification.dart          # Activity notification model (like, comment, follow)
│
├── services/                      # Backend & data access layer
│   ├── auth_service.dart          # Firebase Auth sign-up, login, session state
│   ├── post_service.dart          # Feed queries, cursor pagination, atomic like/comment
│   ├── user_service.dart          # Social graph, batch follow/unfollow, discovery
│   ├── storage_service.dart       # Firebase Storage uploads & image compression
│   ├── notification_service.dart  # Realtime notification dispatch & mark read
│   └── mock_data_service.dart     # In-memory realistic store for instant testing & offline mode
│
├── providers/                     # State management (Provider pattern)
│   ├── auth_provider.dart         # Active user session, theme toggle, demo switching
│   ├── feed_provider.dart         # Dual feed tabs, cursor pagination, optimistic likes
│   └── profile_provider.dart      # User profiles, posts grid/list, follow toggles
│
├── screens/                       # Presentation layer
│   ├── auth/                      # Login & Signup screens
│   ├── feed/                      # Personalized Following & Explore feeds
│   ├── post/                      # Post creation, details, and bottom sheet comments
│   ├── profile/                   # User profile, edit profile, followers/following lists
│   ├── search/                    # User search & post/hashtag discovery
│   ├── notifications/             # Notification feed with instant navigation
│   └── home/                      # Main bottom navigation container
│
└── widgets/                       # Reusable UI components
    ├── post_card.dart             # Social post card with interactive action row
    ├── comment_tile.dart          # Comment item with relative timestamps
    ├── user_avatar.dart           # Cached avatar with initials fallback
    ├── like_button.dart           # Animated heart button with counter badge
    ├── empty_state.dart           # Adaptive empty states
    └── loading_skeleton.dart      # Shimmer placeholder skeleton cards
```

---

## 🔥 Firebase Data Model & Denormalization

```
users/{uid}
    ├── username: "alex_rivers"
    ├── displayName: "Alex Rivers"
    ├── bio: "Mobile dev & UI enthusiast 🚀"
    ├── avatarUrl: "https://..."
    ├── followersCount: 1420
    ├── followingCount: 380
    ├── postsCount: 14
    └── createdAt: Timestamp

users/{uid}/following/{targetUid}
    └── timestamp: serverTimestamp

users/{uid}/followers/{followerUid}
    └── timestamp: serverTimestamp

posts/{postId}
    ├── authorId: "uid_123"
    ├── authorName: "Sophia Chen"
    ├── authorAvatar: "https://..."
    ├── text: "Just deployed our new cursor-based pagination architecture..."
    ├── imageUrl: "https://..."
    ├── likesCount: 142
    ├── commentsCount: 18
    └── createdAt: Timestamp

posts/{postId}/likes/{uid}
    └── timestamp: serverTimestamp

posts/{postId}/comments/{commentId}
    ├── authorId: "uid_456"
    ├── authorName: "Jordan Craft"
    ├── authorAvatar: "https://..."
    ├── text: "Crucial lesson! Clean architecture."
    └── createdAt: Timestamp

notifications/{notificationId}
    ├── recipientId: "uid_123"
    ├── actorId: "uid_456"
    ├── actorName: "Jordan Craft"
    ├── actorAvatar: "https://..."
    ├── type: "like" | "comment" | "follow"
    ├── postId: "postId_789"
    ├── message: "liked your post."
    ├── isRead: false
    └── createdAt: Timestamp

reports/{reportId}
    ├── postId: "postId_789"
    ├── reporterId: "uid_current"
    ├── reason: "Spam" | "Harassment" | "Inappropriate"
    └── createdAt: serverTimestamp
```

---

## ⭐ The Three Core Concepts Under the Hood

### 1. Firestore Batch Writes
When User A follows User B, **four distinct mutations** must occur atomically:
1. Create `users/{UserA}/following/{UserB}`
2. Create `users/{UserB}/followers/{UserA}`
3. Increment `UserA.followingCount` by `+1`
4. Increment `UserB.followersCount` by `+1`

```dart
final batch = FirebaseFirestore.instance.batch();

batch.set(followingRef, {'timestamp': FieldValue.serverTimestamp()});
batch.set(followerRef, {'timestamp': FieldValue.serverTimestamp()});

batch.update(currentUserRef, {
  'followingCount': FieldValue.increment(1),
});

batch.update(targetUserRef, {
  'followersCount': FieldValue.increment(1),
});

await batch.commit();
```

**Why it matters:** If any single write fails (e.g. connectivity drop midway), the entire batch rolls back. This prevents orphaned relationship records and corrupted follower tallies.

---

### 2. Cursor-Based Pagination vs Offset Pagination
Naive database pagination uses `offset(20).limit(10)`. In NoSQL systems like Firestore, offset-based queries still charge you for scanning and skipping the first 20 documents, and new posts inserted at the top cause posts to be duplicated or skipped between pages.

**Cursor pagination** uses the last document snapshot as an anchor:
```
Request 1: 10 posts -> Anchor = lastDoc1
Request 2: query.startAfterDocument(lastDoc1).limit(10) -> Anchor = lastDoc2
Request 3: query.startAfterDocument(lastDoc2).limit(10) -> Anchor = lastDoc3
```

```dart
Query query = firestore
    .collection('posts')
    .orderBy('createdAt', descending: true)
    .limit(10);

if (lastDocument != null) {
  query = query.startAfterDocument(lastDocument);
}

final snapshot = await query.get();
```

---

### 3. Atomic Counters & Denormalization
A common anti-pattern in social apps:
```
❌ BAD:
final snapshot = await postRef.get();
final currentLikes = snapshot['likesCount'];
await postRef.update({'likesCount': currentLikes + 1});
```
When 50 users like the same viral post simultaneously, race conditions result in 49 lost increments.

**Solution:** Server-side atomic increments with `FieldValue.increment()`:
```dart
✅ GOOD:
postRef.update({'likesCount': FieldValue.increment(1)});
```

**Denormalization rationale:**
- Querying `likesCount` directly on `posts/{postId}` costs **1 read operation** instead of scanning thousands of documents in the `likes` subcollection.
- Querying `posts/{postId}/likes/{currentUserUid}` takes **1 document lookup** to answer *"Has current user liked this post?"*.

---

## ⚠️ Feed Architecture & The 30 `whereIn` Limit

In Firestore, the `whereIn` filter supports a maximum of **30 items**:
```dart
// Works for small graphs (<= 30 followed users):
final queriedAuthors = followingIds.take(30).toList();
query.where('authorId', whereIn: queriedAuthors);
```

### How to Scale Beyond 30 Following Accounts in Production

| Architecture | Strategy | Pros | Cons |
|---|---|---|---|
| **Fan-out on Read (Pull)** | Client or backend queries top followings or batches multiple queries and merges chronologically | Low write load when posting | Slower feed loads for users following hundreds of accounts |
| **Fan-out on Write (Push / Denormalized Timeline)** | When an author posts, a Cloud Function pushes a lightweight post stub into each follower's private `users/{uid}/timeline` collection | Feed queries are a single, instant `$O(1)$` index lookup | Higher write cost for celebrity accounts (millions of followers) |
| **Hybrid Model (Instagram/Twitter approach)** | Fan-out on write for regular users; Fan-out on read for accounts with >25k followers | Best balance of read and write efficiency | Requires custom backend orchestration |

---

## 🎯 Interview Questions & Answers

### Q1: Why use `FieldValue.increment()` instead of reading, adding 1, and writing?
> **Answer:** `FieldValue.increment()` executes atomically on Google's backend servers. In high-concurrency environments (like trending posts receiving concurrent likes), client-side read-modify-write causes race conditions where concurrent updates overwrite each other. Atomic increments prevent lost updates without requiring costly distributed locks or retries.

### Q2: Why use batch writes for follow/unfollow?
> **Answer:** Following someone involves four coordinated state changes across two different user entities (creating relationship records in both subcollections and incrementing both counters). Using `batch.commit()` ensures ACID atomicity: either all four changes succeed or none do, guaranteeing data consistency.

### Q3: Why use cursor-based pagination instead of offset pagination?
> **Answer:** Offset pagination requires Firestore to read and discard all prior documents up to the offset, increasing latency and read billing costs. Additionally, as new posts are published, offsets shift dynamically, causing items to appear twice or disappear. Cursor pagination (`startAfterDocument`) starts directly after the anchor point in $O(1)$ query complexity.

### Q4: Why denormalize `likesCount` onto the post document?
> **Answer:** If we counted documents in `posts/{id}/likes` each time a feed was loaded, loading 10 posts with 500 likes each would require 5,000 document reads. By storing `likesCount` as an integer on the post document, displaying the feed costs only 10 document reads while still allowing instant $O(1)$ lookup for the like button state.

---

## 🛠️ Verification & Test Suite

The project includes unit and widget tests covering domain models, UI components, and authentication states:

```bash
# Run static analysis
flutter analyze

# Run unit and widget test suite
flutter test
```

### Test Suite Output:
```
00:00 +0: SocialPulse Model Tests UserProfile serialization and copyWith
00:00 +1: SocialPulse Model Tests Post serialization and copyWith
00:00 +2: SocialPulse Model Tests CommentModel serialization
00:00 +3: SocialPulse Model Tests AppNotification model serialization and types
00:00 +4: SocialPulse Widget Tests UserAvatar renders initials when no image provided
00:01 +5: SocialPulse Widget Tests LikeButton renders initial count and responds to tap
00:02 +6: SocialPulse Widget Tests SocialPulseApp boots to login or feed screen
00:03 +7: All tests passed!
```

---

## 🚀 Running the App

### 1. Instant Interactive Preview (Demo Mode)
SocialPulse includes an intelligent, zero-setup in-memory database (`MockDataService`) that replicates all Firestore features (batch writes, atomic counters, cursor feeds, likes, comments, notifications). You can run and interact with the application immediately without providing Firebase API keys:

```bash
flutter run
```

### 2. Connecting to Production Firebase
To link your own live Firebase project:
1. Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
2. Run `flutterfire configure` in the project root
3. Deploy Firestore and Storage security rules:
```bash
firebase deploy --only firestore:rules,storage,firestore:indexes
```

---

## 📋 Capstone Sequence Portfolio Progression

1. **Project 1: ChatFlow (Chat App)**
   - Real-time Firestore streams
   - Presence detection
   - 1-on-1 and group messaging

2. **Project 2: CraftShop (E-Commerce App)**
   - Complex state management
   - Cart persistence & checkout flows
   - Business rule enforcement

3. **Project 3: SocialPulse (Social Media App)**
   - Social graph relationship management
   - Cursor-based feed pagination & infinite scroll
   - Atomic server counters & denormalization
   - Moderation, reporting, and activity notifications
