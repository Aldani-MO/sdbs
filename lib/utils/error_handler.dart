import 'package:flutter/material.dart';

/// Centralized error handling utility for the SDBS application.
/// Replaces per-widget try/catch patterns with a single, consistent
/// error display and logging mechanism.
class ErrorHandler {
  ErrorHandler._(); // prevent instantiation

  /// Show a red error SnackBar. Safe to call even if the widget is
  /// no longer mounted (checks [context.mounted] internally).
  static void showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a green success SnackBar.
  static void showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a red error SnackBar using a pre-captured [ScaffoldMessengerState].
  /// Use this when you need to show an error after an async gap to avoid
  /// using a BuildContext across an await.
  static void showErrorOnMessenger(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show a green success SnackBar using a pre-captured [ScaffoldMessengerState].
  static void showSuccessOnMessenger(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<bool> run(
    BuildContext context,
    Future<void> Function() operation, {
    String? successMessage,
  }) async {
    try {
      await operation();
      if (successMessage != null && context.mounted) {
        showSuccess(context, successMessage);
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        showError(context, _friendlyMessage(e));
      }
      return false;
    }
  }

  /// Convert common Firebase exceptions into user-friendly messages.
  static String _friendlyMessage(Object error) {
    final msg = error.toString();
    if (msg.contains('email-already-in-use')) {
      return 'This email is already registered.';
    }
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('user-not-found')) {
      return 'No account found with this email.';
    }
    if (msg.contains('too-many-requests')) {
      return 'Too many attempts. Please try again later.';
    }
    if (msg.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    if (msg.contains('permission-denied')) {
      return 'You do not have permission for this action.';
    }
    // Fallback: strip the exception prefix for cleaner output
    return msg.replaceFirst(RegExp(r'^\[.*?\]\s*'), '');
  }
}
