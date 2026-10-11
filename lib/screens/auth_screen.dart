import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../utils/errors.dart';
import '../widgets/animations.dart';

/// Login + Sign up in one screen (toggle at the bottom).
class AuthScreen extends StatefulWidget {
  final bool initialSignUp;
  const AuthScreen({super.key, this.initialSignUp = false});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();

  late bool _isSignUp = widget.initialSignUp;
  bool _loading = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      if (_email.text.trim().isEmpty || _password.text.isEmpty) {
        throw AppException('Please enter your email and password.');
      }
      final emailOk = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
          .hasMatch(_email.text.trim());
      if (!emailOk) {
        throw AppException('Enter a valid email like name@example.com.');
      }
      if (_isSignUp) {
        if (_username.text.trim().isEmpty || _name.text.trim().isEmpty) {
          throw AppException('Please fill in your name and username.');
        }
        final needsConfirm = await _auth.signUp(
          email: _email.text,
          password: _password.text,
          username: _username.text,
          displayName: _name.text,
        );
        if (needsConfirm && mounted) {
          setState(() {
            _isSignUp = false;
            _info = 'Account created! Check your email to confirm, then log in.';
          });
        }
      } else {
        await _auth.signIn(email: _email.text, password: _password.text);
      }
      // On success the root gate switches screens automatically.
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeSlideIn(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: AppLogo(size: 88)),
                  const SizedBox(height: 18),
                  const Text('Memories',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1)),
                  const SizedBox(height: 8),
                  const Text('Your life, mapped.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 17, color: AppColors.accentLight)),
                  const SizedBox(height: 40),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    child: _isSignUp
                        ? Column(
                            children: [
                              TextField(
                                controller: _name,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                    hintText: 'Display name'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _username,
                                autocorrect: false,
                                decoration: const InputDecoration(
                                    hintText: 'Username'),
                              ),
                              const SizedBox(height: 12),
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(hintText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                            _showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppColors.textSecondary),
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                    onSubmitted: (_) => _loading ? null : _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error)),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 14),
                    Text(_info!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.location)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentLight,
                        foregroundColor: AppColors.onAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: AppColors.onAccent))
                          : Text(_isSignUp ? 'Create account' : 'Log in',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                              _info = null;
                            }),
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Log in'
                          : 'New here? Create an account',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
