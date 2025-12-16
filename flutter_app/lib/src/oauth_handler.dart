import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handle OAuth authentication flow.
Future<void> handleOAuthRequired({
  required BuildContext context,
  required String provider,
  required String authUrl,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Authentication Required'),
      content: Text('Sign in with $provider to continue.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sign In'),
        ),
      ],
    ),
  );

  switch (confirmed ?? false) {
    case true:
      await launchUrl(Uri.parse(authUrl));
    case false:
  }
}
