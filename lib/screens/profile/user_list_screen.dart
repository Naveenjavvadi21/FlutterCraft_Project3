import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/user_avatar.dart';
import 'profile_screen.dart';

enum UserListType { followers, following }

class UserListScreen extends StatefulWidget {
  final String userId;
  final UserListType type;
  final String title;

  const UserListScreen({
    super.key,
    required this.userId,
    required this.type,
    required this.title,
  });

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserService _userService = UserService();
  List<UserProfile> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final list = widget.type == UserListType.followers
        ? await _userService.getFollowersList(widget.userId)
        : await _userService.getFollowingList(widget.userId);

    if (mounted) {
      setState(() {
        _users = list;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _users.isEmpty
              ? EmptyState(
                  icon: Icons.people_outline,
                  title: 'No users found',
                  subtitle: widget.type == UserListType.followers
                      ? 'No one has followed this account yet.'
                      : 'Not following anyone yet.',
                )
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isSelf = user.uid == currentUserId;

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
                      subtitle: Text('@${user.username}'),
                      trailing: isSelf
                          ? null
                          : const Icon(Icons.chevron_right, color: Colors.grey),
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
    );
  }
}
