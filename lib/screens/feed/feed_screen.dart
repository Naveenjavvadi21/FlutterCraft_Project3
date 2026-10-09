import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/post_card.dart';
import '../post/comments_sheet.dart';
import '../post/create_post_screen.dart';
import '../post/post_detail_screen.dart';
import '../profile/profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';
      context.read<FeedProvider>().loadInitialFeed(currentUserId: currentUserId);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';
      context.read<FeedProvider>().loadMore(currentUserId: currentUserId);
    }
  }

  void _showReportDialog(Post post) {
    String selectedReason = 'Spam';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report Post'),
          content: RadioGroup<String>(
            groupValue: selectedReason,
            onChanged: (v) => setDialogState(() => selectedReason = v ?? 'Spam'),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  title: Text('Spam or scam'),
                  value: 'Spam',
                ),
                RadioListTile<String>(
                  title: Text('Harassment or hate speech'),
                  value: 'Harassment',
                ),
                RadioListTile<String>(
                  title: Text('Inappropriate content'),
                  value: 'Inappropriate',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  context.read<FeedProvider>().reportPost(
                        postId: post.id,
                        reporterId: user.uid,
                        reason: selectedReason,
                      );
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you!')),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;
    final feedProvider = context.watch<FeedProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                ),
              ),
              child: const Icon(
                Icons.all_inclusive_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'SocialPulse',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Feed',
            onPressed: () {
              if (currentUser != null) {
                feedProvider.loadInitialFeed(currentUserId: currentUser.uid);
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildTabButton(
                  title: 'Following',
                  isSelected: feedProvider.currentTab == FeedTab.following,
                  onTap: () {
                    if (currentUser != null) {
                      feedProvider.switchTab(FeedTab.following, currentUser.uid);
                    }
                  },
                ),
                const SizedBox(width: 10),
                _buildTabButton(
                  title: 'Explore',
                  isSelected: feedProvider.currentTab == FeedTab.explore,
                  onTap: () {
                    if (currentUser != null) {
                      feedProvider.switchTab(FeedTab.explore, currentUser.uid);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        tooltip: 'New Post',
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreatePostScreen()),
          );
        },
      ),
      body: feedProvider.isLoadingInitial
          ? ListView.builder(
              itemCount: 4,
              itemBuilder: (_, _) => const LoadingSkeletonCard(),
            )
          : feedProvider.posts.isEmpty
              ? RefreshIndicator(
                  onRefresh: () async {
                    if (currentUser != null) {
                      await feedProvider.loadInitialFeed(currentUserId: currentUser.uid);
                    }
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 80),
                      if (feedProvider.currentTab == FeedTab.following)
                        EmptyState(
                          icon: Icons.people_outline,
                          title: 'Your feed is quiet',
                          subtitle: 'Follow other creators to see their posts here, or browse Explore.',
                          buttonText: 'Browse Explore',
                          onButtonPressed: () {
                            if (currentUser != null) {
                              feedProvider.switchTab(FeedTab.explore, currentUser.uid);
                            }
                          },
                        )
                      else
                        EmptyState(
                          icon: Icons.post_add_outlined,
                          title: 'No posts yet',
                          subtitle: 'Be the first one to share an update with the community!',
                          buttonText: 'Create Post',
                          onButtonPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                            );
                          },
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    if (currentUser != null) {
                      await feedProvider.loadInitialFeed(currentUserId: currentUser.uid);
                    }
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: feedProvider.posts.length + (feedProvider.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == feedProvider.posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final post = feedProvider.posts[index];

                      return PostCard(
                        post: post,
                        currentUserId: currentUser?.uid ?? '',
                        onLike: () {
                          if (currentUser != null) {
                            feedProvider.toggleLike(
                              post: post,
                              currentUser: currentUser,
                            );
                          }
                        },
                        onComment: () => CommentsSheet.show(context, post),
                        onShare: () {
                          Clipboard.setData(ClipboardData(
                            text: 'SocialPulse post: ${post.text}',
                          ));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Post link copied to clipboard!')),
                          );
                        },
                        onPostTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PostDetailScreen(post: post),
                            ),
                          );
                        },
                        onUserTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(userId: post.authorId),
                            ),
                          );
                        },
                        onDelete: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Post?'),
                              content: const Text('Are you sure you want to delete this post?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.accentColor,
                                  ),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && currentUser != null) {
                            await feedProvider.deletePost(
                              postId: post.id,
                              authorId: post.authorId,
                            );
                          }
                        },
                        onReport: () => _showReportDialog(post),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
