import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/mock_data_service.dart';
import '../services/user_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final UserService _userService;

  UserProfile? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  ThemeMode _themeMode = ThemeMode.system;

  AuthProvider({
    AuthService? authService,
    UserService? userService,
  })  : _authService = authService ?? AuthService(),
        _userService = userService ?? UserService() {
    _initialize();
  }

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
    } else {
      _themeMode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> _initialize() async {
    _setLoading(true);
    try {
      _currentUser = await _authService.getCurrentUserProfile();
    } catch (e) {
      debugPrint('Error initializing auth provider: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _authService.signUp(
        email: email,
        password: password,
        username: username,
        displayName: displayName,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      _currentUser = await _authService.signIn(
        email: email,
        password: password,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanErrorMessage(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Switch active demo user (handy for testing follow/like between accounts)
  void switchDemoAccount(String userId) {
    final mock = MockDataService();
    final target = mock.users[userId];
    if (target != null) {
      mock.currentMockUser = target;
      _currentUser = target;
      notifyListeners();
    }
  }

  /// Update current profile details
  Future<void> updateCurrentProfile({
    String? displayName,
    String? bio,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return;

    final updated = _currentUser!.copyWith(
      displayName: displayName ?? _currentUser!.displayName,
      bio: bio ?? _currentUser!.bio,
      avatarUrl: avatarUrl ?? _currentUser!.avatarUrl,
    );

    await _userService.saveUserProfile(updated);
    _currentUser = updated;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  String _cleanErrorMessage(String raw) {
    if (raw.contains(']')) {
      return raw.split(']').last.trim();
    }
    return raw.replaceAll('Exception:', '').trim();
  }
}
