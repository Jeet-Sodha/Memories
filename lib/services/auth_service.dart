import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  GoTrueClient get _auth => Supabase.instance.client.auth;

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(
        email: email.trim().toLowerCase(), password: password);
  }

  /// Returns true if the user must confirm their email before logging in.
  /// username + display_name go into metadata; your DB trigger copies them
  /// into public.profiles automatically.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    final res = await _auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'username': username.trim().toLowerCase(),
        'display_name': displayName.trim(),
      },
    );
    return res.session == null;
  }

  Future<void> signOut() => _auth.signOut();
}
