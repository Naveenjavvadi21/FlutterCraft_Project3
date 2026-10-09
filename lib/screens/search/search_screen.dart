import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/post_card.dart';
import '../../widgets/user_avatar.dart';
import '../post/comments_sheet.dart';
import '../post/post_detail_screen.dart';
import '../profile/profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final UserService _userService = UserService();
  final PostService _postService = PostService();

  late TabController _tabController;
  List<UserProfile> _userResults = [];
  List<Post> _postResults = [];
  bool _isSearching = false;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _activeQuery = '';
        _userResults = [];
        _postResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _activeQuery = clean;
      _isSearching = true;
    });

    final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';

    final usersFuture = _userService.searchUsers(clean);
    final postsFuture = _postService.searchPosts(
      query: clean,
      currentUserId: currentUserId,
    );

    final results = await Future.wait([usersFuture, postsFuture]);

    if (mounted) {
      setState(() {
        _userResults = results[0] as List<UserProfile>;
        _postResults = results[1] as List<Post>;
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: false,
          decoration: InputDecoration(
            hintText: 'Search people, posts, #tags...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onChanged: (val) {
            _performSearch(val);
          },
          onSubmitted: (val) => _performSearch(val),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: theme.textTheme.bodySmall?.color,
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'Posts'),
          ],
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _activeQuery.isEmpty
              ? _buildExploreSuggestions()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Users tab
                    _userResults.isEmpty
                        ? EmptyState(
                            icon: Icons.person_search_outlined,
                            title: 'No users found',
                            subtitle: 'Try searching for another name or handle.',
                          )
                        : ListView.separated(
                            itemCount: _userResults.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = _userResults[index];
                              return ListTile(
                                leading: UserAvatar(
                                  avatarUrl: user.avatarUrl,
                                  name: user.displayName,
                                  radius: 22,
                                ),
                                title: Text(
                                  user.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('@${user.username} • ${user.followersCount} followers'),
                                trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(userId: user.uid),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                    // Posts tab
                    _postResults.isEmpty
                        ? EmptyState(
                            icon: Icons.article_outlined,
                            title: 'No posts found',
                            subtitle: 'Try searching for other keywords or hashtags.',
                          )
                        : ListView.builder(
                            itemCount: _postResults.length,
                            itemBuilder: (context, index) {
                              final post = _postResults[index];
                              return PostCard(
                                post: post,
                                currentUserId: currentUser?.uid ?? '',
                                onLike: () {
                                  if (currentUser != null) {
                                    context.read<FeedProvider>().toggleLike(
                                          post: post,
                                          currentUser: currentUser,
                                        );
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
                                onUserTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(userId: post.authorId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ],
                ),
    );
  }

  Widget _buildExploreSuggestions() {
    final tags = ['#flutter', '#firebase', '#systemdesign', '#pagination', '#batchwrites', '#dart', '#mobiledev'];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popular Topics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return ActionChip(
                label: Text(tag),
                onPressed: () {
                  _searchController.text = tag;
                  _performSearch(tag);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Search for people by @username or browse posts with keywords.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color?.withAlpha(160),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
