import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post.dart';
import '../utils/app_theme.dart';
import 'like_button.dart';
import 'user_avatar.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final String currentUserId;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback? onUserTap;
  final VoidCallback? onPostTap;
  final VoidCallback? onDelete;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUserId,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    this.onUserTap,
    this.onPostTap,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAuthor = post.authorId == currentUserId;

    return Card(
      child: InkWell(
        onTap: onPostTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author Header
              Row(
                children: [
                  UserAvatar(
                    avatarUrl: post.authorAvatar,
                    name: post.authorName,
                    radius: 20,
                    onTap: onUserTap,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: onUserTap,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatTimestamp(post.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: theme.iconTheme.color?.withAlpha(160),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (val) {
                      if (val == 'delete' && onDelete != null) {
                        onDelete!();
                      } else if (val == 'report' && onReport != null) {
                        onReport!();
                      } else if (val == 'block' && onBlock != null) {
                        onBlock!();
                      }
                    },
                    itemBuilder: (context) => [
                      if (isAuthor)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, color: AppTheme.accentColor, size: 20),
                              SizedBox(width: 8),
                              Text('Delete post', style: TextStyle(color: AppTheme.accentColor)),
                            ],
                          ),
                        )
                      else ...[
                        const PopupMenuItem(
                          value: 'report',
                          child: Row(
                            children: [
                              Icon(Icons.flag_outlined, size: 20),
                              SizedBox(width: 8),
                              Text('Report post'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'block',
                          child: Row(
                            children: [
                              Icon(Icons.block, size: 20, color: AppTheme.accentColor),
                              SizedBox(width: 8),
                              Text('Block user', style: TextStyle(color: AppTheme.accentColor)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Post Text Body
              Text(
                post.text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),

              // Post Image (if present)
              if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 340),
                    child: CachedNetworkImage(
                      imageUrl: post.imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    placeholder: (context, url) => Container(
                      height: 220,
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 140,
                      color: Colors.grey.withAlpha(40),
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
              ],

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 6),

              // Action Buttons Row: Likes, Comments, Share
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Like button
                  LikeButton(
                    isLiked: post.isLikedByCurrentUser,
                    count: post.likesCount,
                    onTap: onLike,
                  ),

                  // Comment button
                  InkWell(
                    onTap: onComment,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 20,
                            color: theme.iconTheme.color?.withAlpha(160),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${post.commentsCount}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Share button
                  InkWell(
                    onTap: onShare,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 20,
                            color: theme.iconTheme.color?.withAlpha(160),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color?.withAlpha(180),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
