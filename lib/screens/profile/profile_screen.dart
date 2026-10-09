import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar.dart';
import '../post/comments_sheet.dart';
import '../post/post_detail_screen.dart';
import 'edit_profile_screen.dart';
import 'user_list_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileProvider _profileProvider;
  bool _isGridView = false;

  @override
  void initState() {
    super.initState();
    _profileProvider = ProfileProvider();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';
      _profileProvider.loadProfile(
        targetUserId: widget.userId,
        currentUserId: currentUserId,
      );
    });
  }

  @override
  void dispose() {
    _profileProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUser = auth.currentUser;
    final isOwnProfile = currentUser?.uid == widget.userId;

    return ChangeNotifierProvider<ProfileProvider>.value(
      value: _profileProvider,
      child: Consumer<ProfileProvider>(
        builder: (context, profileProv, _) {
          final profile = profileProv.profile;
          final theme = Theme.of(context);

          return Scaffold(
            appBar: AppBar(
              title: Text(profile?.username != null ? '@${profile!.username}' : 'Profile'),
              actions: [
                if (isOwnProfile) ...[
                  IconButton(
                    icon: Icon(
                      auth.themeMode == ThemeMode.dark
                          ? Icons.light_mode_outlined
                          : Icons.dark_mode_outlined,
                    ),
                    tooltip: 'Toggle Theme',
                    onPressed: () => auth.toggleTheme(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Sign Out'),
                          content: const Text('Are you sure you want to sign out?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Sign Out'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await auth.signOut();
                      }
                    },
                  ),
                ],
              ],
            ),
            body: profileProv.isLoading && profile == null
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : profile == null
                    ? const EmptyState(
                        icon: Icons.person_off_outlined,
                        title: 'User not found',
                        subtitle: 'This user may have been deleted or does not exist.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (currentUser != null) {
                            await profileProv.loadProfile(
                              targetUserId: widget.userId,
                              currentUserId: currentUser.uid,
                            );
                          }
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Header
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        UserAvatar(
                                          avatarUrl: profile.avatarUrl,
                                          name: profile.displayName,
                                          radius: 40,
                                          showBorder: true,
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                                            children: [
                                              _buildStat(
                                                'Posts',
                                                '${profile.postsCount}',
                                                null,
                                              ),
                                              _buildStat(
                                                'Followers',
                                                '${profile.followersCount}',
                                                () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => UserListScreen(
                                                      userId: profile.uid,
                                                      type: UserListType.followers,
                                                      title: 'Followers',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              _buildStat(
                                                'Following',
                                                '${profile.followingCount}',
                                                () => Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => UserListScreen(
                                                      userId: profile.uid,
                                                      type: UserListType.following,
                                                      title: 'Following',
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),

                                    // Name and Username
                                    Text(
                                      profile.displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '@${profile.username}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                                      ),
                                    ),

                                    // Bio
                                    if (profile.bio.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        profile.bio,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          height: 1.35,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 20),

                                    // Action Button (Edit Profile or Follow / Unfollow)
                                    if (isOwnProfile)
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          icon: const Icon(Icons.edit_outlined, size: 18),
                                          label: const Text('Edit Profile'),
                                          onPressed: () async {
                                            await Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => EditProfileScreen(
                                                  profile: profile,
                                                ),
                                              ),
                                            );
                                            if (currentUser != null) {
                                              profileProv.loadProfile(
                                                targetUserId: widget.userId,
                                                currentUserId: currentUser.uid,
                                              );
                                            }
                                          },
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: profileProv.isFollowing
                                                ? theme.colorScheme.surfaceContainerHighest
                                                : AppTheme.primaryColor,
                                            foregroundColor: profileProv.isFollowing
                                                ? theme.colorScheme.onSurface
                                                : Colors.white,
                                          ),
                                          onPressed: currentUser == null
                                              ? null
                                              : () => profileProv.toggleFollow(
                                                    currentUser: currentUser,
                                                  ),
                                          child: Text(
                                            profileProv.isFollowing ? 'Following' : 'Follow',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              const Divider(height: 1),

                              // Posts Header with view toggle
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  children: [
                                    const Text(
                                      'Posts',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: Icon(
                                        _isGridView ? Icons.view_agenda_outlined : Icons.grid_view,
                                        size: 20,
                                      ),
                                      tooltip: _isGridView ? 'List view' : 'Grid view',
                                      onPressed: () {
                                        setState(() {
                                          _isGridView = !_isGridView;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              // User Posts List or Grid
                              if (profileProv.userPosts.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: EmptyState(
                                    icon: Icons.post_add_rounded,
                                    title: 'No posts yet',
                                    subtitle: 'Share your first story or photo with followers.',
                                  ),
                                )
                              else if (_isGridView)
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: profileProv.userPosts.length,
                                  itemBuilder: (context, index) {
                                    final p = profileProv.userPosts[index];
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PostDetailScreen(post: p),
                                          ),
                                        );
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                                            ? Image.network(
                                                p.imageUrl!,
                                                fit: BoxFit.cover,
                                              )
                                            : Container(
                                                color: AppTheme.primaryColor.withAlpha(30),
                                                padding: const EdgeInsets.all(8),
                                                child: Center(
                                                  child: Text(
                                                    p.text,
                                                    maxLines: 4,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    );
                                  },
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: profileProv.userPosts.length,
                                  itemBuilder: (context, index) {
                                    final post = profileProv.userPosts[index];
                                    return PostCard(
                                      post: post,
                                      currentUserId: currentUser?.uid ?? '',
                                      onLike: () {
                                        if (currentUser != null) {
                                          context.read<FeedProvider>().toggleLike(
                                                post: post,
                                                currentUser: currentUser,
                                              );
                                          profileProv.refreshPosts(currentUser.uid);
                                        }
                                      },
                                      onComment: () => CommentsSheet.show(context, post),
                                      onShare: () {},
                                      onPostTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => PostDetailScreen(post: post),
                                          ),
                                        );
                                      },
                                      onDelete: () async {
                                        if (currentUser != null) {
                                          await context.read<FeedProvider>().deletePost(
                                                postId: post.id,
                                                authorId: post.authorId,
                                              );
                                          profileProv.refreshPosts(currentUser.uid);
                                        }
                                      },
                                    );
                                  },
                                ),

                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
          );
        },
      ),
    );
  }

  Widget _buildStat(String label, String count, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Text(
              count,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
