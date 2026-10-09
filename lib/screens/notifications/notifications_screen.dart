import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_avatar.dart';
import '../post/post_detail_screen.dart';
import '../profile/profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final PostService _postService = PostService();

  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    final list = await _notificationService.getNotifications(currentUser.uid);

    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    await _notificationService.markAllAsRead(currentUser.uid);
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      });
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  Widget _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.like:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppTheme.likeRed,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.favorite, size: 12, color: Colors.white),
        );
      case NotificationType.comment:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_bubble, size: 12, color: Colors.white),
        );
      case NotificationType.follow:
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: AppTheme.secondaryColor,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_add, size: 12, color: Colors.white),
        );
    }
  }

  Future<void> _onNotificationTap(AppNotification notif) async {
    await _notificationService.markAsRead(notif.id);
    if (mounted) {
      setState(() {
        final idx = _notifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _notifications[idx] = _notifications[idx].copyWith(isRead: true);
        }
      });
    }

    if (!mounted) return;

    if (notif.postId != null) {
      // Find post or load post
      final currentUserId = context.read<AuthProvider>().currentUser?.uid ?? '';
      final explore = await _postService.getExploreFeed(
        currentUserId: currentUserId,
        limit: 50,
      );
      final targetPost = explore.items.where((p) => p.id == notif.postId).firstOrNull;

      if (targetPost != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: targetPost),
          ),
        );
      }
    } else {
      // Follow notification -> open user profile
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: notif.actorId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications yet',
                  subtitle: 'When people like, comment, or follow you, you will see it here.',
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];

                      return InkWell(
                        onTap: () => _onNotificationTap(notif),
                        child: Container(
                          color: notif.isRead
                              ? null
                              : AppTheme.primaryColor.withAlpha(15),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    avatarUrl: notif.actorAvatar,
                                    name: notif.actorName,
                                    radius: 22,
                                  ),
                                  Positioned(
                                    bottom: -2,
                                    right: -2,
                                    child: _getIconForType(notif.type),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontSize: 14,
                                          height: 1.35,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: '${notif.actorName} ',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          TextSpan(text: notif.message),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(notif.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.textTheme.bodySmall?.color?.withAlpha(160),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!notif.isRead) ...[
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
