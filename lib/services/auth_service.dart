import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_options.dart';
import '../models/user_profile.dart';
import 'mock_data_service.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth? _customAuth;
  final UserService _userService;
  final MockDataService _mock = MockDataService();

  AuthService({
    FirebaseAuth? auth,
    UserService? userService,
  })  : _customAuth = auth,
        _userService = userService ?? UserService();

  FirebaseAuth? get _auth {
    if (_customAuth != null) return _customAuth;
    if (!DefaultFirebaseOptions.isConfigured) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// Stream of auth state changes
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();

  /// Get currently signed-in Firebase user
  User? get currentUser => _auth?.currentUser;

  /// Sign up with email, password, username, and display name
  Future<UserProfile> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final cleanUsername = username.trim().toLowerCase().replaceAll('@', '');
    final auth = _auth;

    if (auth == null) {
      final mockId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final newProfile = UserProfile(
        uid: mockId,
        username: cleanUsername,
        displayName: displayName.trim(),
        bio: 'Hello! I just joined SocialPulse.',
        avatarUrl:
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=500&auto=format&fit=crop&q=80',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        createdAt: DateTime.now(),
      );
      _mock.users[mockId] = newProfile;
      _mock.currentMockUser = newProfile;
      return newProfile;
    }

    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user!;
      await user.updateDisplayName(displayName.trim());

      final newProfile = UserProfile(
        uid: user.uid,
        username: cleanUsername,
        displayName: displayName.trim(),
        bio: '',
        avatarUrl: user.photoURL ?? '',
        followersCount: 0,
        followingCount: 0,
        postsCount: 0,
        createdAt: DateTime.now(),
      );

      await _userService.saveUserProfile(newProfile);
      return newProfile;
    } catch (e) {
      debugPrint('Error signing up: $e');
      rethrow;
    }
  }

  /// Sign in with email and password
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _auth;

    if (auth == null) {
      final user = _mock.currentMockUser ?? _mock.users.values.first;
      return user;
    }

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final profile = await _userService.getUserProfile(credential.user!.uid);
      if (profile != null) {
        return profile;
      }

      // Fallback bootstrap if profile doc didn't exist
      final fallbackProfile = UserProfile(
        uid: credential.user!.uid,
        username: (credential.user!.email?.split('@').first ?? 'user').toLowerCase(),
        displayName: credential.user!.displayName ?? 'User',
        avatarUrl: credential.user!.photoURL ?? '',
        createdAt: DateTime.now(),
      );
      await _userService.saveUserProfile(fallbackProfile);
      return fallbackProfile;
    } catch (e) {
      debugPrint('Error signing in: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    final auth = _auth;
    if (auth != null) {
      await auth.signOut();
    }
  }

  /// Get current user's profile
  Future<UserProfile?> getCurrentUserProfile() async {
    final auth = _auth;
    if (auth == null) {
      return _mock.currentMockUser;
    }

    final user = auth.currentUser;
    if (user == null) return null;
    return await _userService.getUserProfile(user.uid);
  }
}
