import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Sign in with Apple solo aplica en iOS nativo.
bool isAppleAccountLinkAvailable() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Abre el sheet de Apple y llama `POST /auth/apple/link` con el JWT actual.
Future<void> linkAppleAccountFromProfile(BuildContext context) async {
  final auth = Provider.of<AuthProvider>(context, listen: false);
  final ok = await auth.linkAppleAccount();
  if (!context.mounted) return;

  if (ok) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cuenta de Apple vinculada correctamente')),
    );
    return;
  }

  final message = auth.errorMessage;
  if (message != null && message.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
