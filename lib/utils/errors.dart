import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// An error whose message is already safe to show to the user.
class AppException implements Exception {
  final String message;
  AppException(this.message);
  @override
  String toString() => message;
}

/// Converts ANY error into a friendly message. Raw database/storage
/// errors are never shown to the user.
String friendlyError(Object e) {
  if (e is AppException) return e.message;
  final s = e.toString();
  if (e is SocketException ||
      s.contains('SocketException') ||
      s.contains('Failed host lookup') ||
      s.contains('ClientException') ||
      s.contains('Connection closed') ||
      s.contains('Connection refused')) {
    return 'No internet connection. Check your network and try again.';
  }
  if (e is TimeoutException) {
    return 'That took too long. Please try again.';
  }
  if (e is AuthException) {
    final m = e.message.toLowerCase();
    final code = (e.code ?? '').toLowerCase();
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        code == 'over_sms_send_rate_limit') {
      return 'Too many sign-up emails were sent recently. Wait a while and try again.';
    }
    if (code == 'email_address_not_authorized') {
      return 'This email cannot be used yet because the app is in test mode. Ask the app owner to turn off email confirmation.';
    }
    if (code == 'email_address_invalid') {
      return 'That email address looks invalid. Check it and try again.';
    }
    if (code == 'user_already_exists' || code == 'email_exists') {
      return 'An account with this email already exists. Try logging in.';
    }
    if (code == 'weak_password') {
      return 'Choose a stronger password (at least 6 characters).';
    }
    if (code == 'email_not_confirmed') {
      return 'Please confirm your email first, then log in.';
    }
    if (code == 'signup_disabled') {
      return 'New sign-ups are turned off right now.';
    }
    if (code == 'invalid_credentials') return 'Wrong email or password.';
    if (m.contains('invalid login')) return 'Wrong email or password.';
    // ORDER MATTERS: these all contain the word "email", so they must be
    // checked BEFORE the generic "invalid email" message.
    if (m.contains('rate limit')) {
      return 'Too many sign-up emails were sent recently. Wait a while and try again.';
    }
    if (m.contains('not authorized') || m.contains('not allowed')) {
      return 'This email cannot be used yet because the app is in test mode. Ask the app owner to turn off email confirmation.';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'An account with this email already exists. Try logging in.';
    }
    if (m.contains('email not confirmed')) {
      return 'Please confirm your email first, then log in.';
    }
    if (m.contains('signups not allowed') || m.contains('signup is disabled')) {
      return 'New sign-ups are turned off right now.';
    }
    if (m.contains('database error')) {
      return 'That username may already be taken. Try another.';
    }
    if (m.contains('password')) {
      return 'Password must be at least 6 characters.';
    }
    if (m.contains('invalid') && m.contains('email')) {
      return 'That email address looks invalid. Check it and try again.';
    }
    return 'Something went wrong signing you in. Please try again.';
  }
  if (e is StorageException) {
    final m = e.message.toLowerCase();
    if (m.contains('maximum allowed size') || m.contains('too large')) {
      return 'That file is larger than the 50 MB upload limit.';
    }
    if (m.contains('mime') || m.contains('not supported')) {
      return 'That file type is not supported.';
    }
    return 'Could not upload or load media. Please try again.';
  }
  if (e is PostgrestException) {
    return 'Could not reach your memories right now. Please try again.';
  }
  return 'Something went wrong. Please try again.';
}
