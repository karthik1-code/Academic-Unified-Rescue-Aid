import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:aura_frontend/services/api_service.dart';
import 'package:aura_frontend/services/local_storage.dart';

class User {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  User({required this.uid, this.email, this.displayName, this.photoURL});
}

class UserCredential {
  final User? user;
  UserCredential({this.user});
}

class AuthService {
  static const String _webClientId =
      '528620809743-6lgoof9f354uiasj6o36uv0e7v5j3kr3.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
    serverClientId: _webClientId,
    scopes: ['email', 'profile', 'openid'],
  );

  static final String _baseUrl = ApiService.baseUrl;

  // Stream of auth state changes (compatibility stream)
  Stream<User?> get authStateChanges => Stream.value(currentUser);

  // Get current user from local storage
  User? get currentUser {
    final cached = LocalStorageService.getAuthUser();
    if (cached != null) {
      return User(uid: cached['uid']!, email: cached['email']);
    }
    return null;
  }

  // Sign in with Email & Password
  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final uid = data['uid'] as String;
        final resEmail = data['email'] as String?;
        LocalStorageService.saveAuthUser(uid, resEmail);
        return UserCredential(user: User(uid: uid, email: resEmail));
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Invalid email or password';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint("signInWithEmail failed: $e");
      rethrow;
    }
  }

  // Register with Email & Password
  Future<UserCredential?> registerWithEmail(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final uid = data['uid'] as String;
        final resEmail = data['email'] as String?;
        LocalStorageService.saveAuthUser(uid, resEmail);
        return UserCredential(user: User(uid: uid, email: resEmail));
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Registration failed';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint("registerWithEmail failed: $e");
      rethrow;
    }
  }

  // Password Reset (dummy endpoint / email service)
  Future<void> sendPasswordReset(String email) async {
    // Password reset is handled locally/mock for custom backend
    await Future.delayed(const Duration(milliseconds: 500));
  }

  // Sign in with Google (OAuth ID Token verification against backend)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled flow

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Failed to retrieve Google OAuth token.");
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id_token': idToken}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final uid = data['uid'] as String;
        final resEmail = data['email'] as String?;
        LocalStorageService.saveAuthUser(uid, resEmail);
        return UserCredential(user: User(uid: uid, email: resEmail));
      } else {
        final error = jsonDecode(response.body)['detail'] ?? 'Google sign-in failed';
        throw Exception(error);
      }
    } catch (e) {
      debugPrint("signInWithGoogle failed: $e");
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    LocalStorageService.clearProfile();
  }
}
