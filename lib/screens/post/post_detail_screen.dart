import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/comment.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../services/post_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/comment_tile.dart';
import '../../widgets/post_card.dart';
import '../profile/profile_screen.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _commentController = TextEditingController();
  final PostService _postService = PostService();
  late Post _currentPost;
  List<CommentModel> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();
    _currentPost = widget.post;
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final list = await _postService.getComments(_currentPost.id);
    if (mounted) {
      setState(() {
        _comments = list;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmittingComment) return;

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() => _isSubmittingComment = true);
    _commentController.clear();

    final newComment = await context.read<FeedProvider>().addComment(
          postId: _currentPost.id,
          text: text,
          currentUser: currentUser,
          postAuthorId: _currentPost.authorId,
        );

    if (mounted) {
      setState(() {
        _isSubmittingComment = false;
        if (newComment != null) {
          _comments.add(newComment);
          _currentPost = _currentPost.copyWith(
            commentsCount: _currentPost.commentsCount + 1,
          );
        }
      });
    }
  }

  void _sharePost() {
    Clipboard.setData(ClipboardData(
      text: 'Check out this post on SocialPulse by ${_currentPost.authorName}: "${_currentPost.text}"',
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post link copied to clipboard!')),
    );
  }

  void _showReportDialog() {
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
                        postId: _currentPost.id,
                        reporterId: user.uid,
                        reason: selectedReason,
                      );
                }
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thank you. We have received your report.')),
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
    final currentUser = context.watch<AuthProvider>().currentUser;
    final feedProvider = context.watch<FeedProvider>();

    // Sync latest post status from feedProvider if present
    final postInFeed = feedProvider.posts.firstWhere(
      (p) => p.id == _currentPost.id,
      orElse: () => _currentPost,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PostCard(
                      post: postInFeed,
                      currentUserId: currentUser?.uid ?? '',
                      onLike: () {
                        if (currentUser != null) {
                          feedProvider.toggleLike(
                            post: postInFeed,
                            currentUser: currentUser,
                          );
                        }
                      },
                      onComment: () {},
                      onShare: _sharePost,
                      onUserTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(userId: postInFeed.authorId),
                          ),
                        );
                      },
                      onDelete: () async {
                        final navigator = Navigator.of(context);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Post?'),
                            content: const Text('This action cannot be undone.'),
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

                        if (confirm == true) {
                          await feedProvider.deletePost(
                            postId: postInFeed.id,
                            authorId: postInFeed.authorId,
                          );
                          if (mounted) {
                            navigator.pop();
                          }
                        }
                      },
                      onReport: _showReportDialog,
                    ),

                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        'Comments',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),

                    if (_isLoadingComments)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_comments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No comments yet. Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          return CommentTile(
                            comment: comment,
                            isOwner: comment.authorId == currentUser?.uid,
                            onUserTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(userId: comment.authorId),
                                ),
                              );
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Comment bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Write a comment...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _isSubmittingComment ? null : _submitComment,
                    icon: _isSubmittingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_upward_rounded, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
