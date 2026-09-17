import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

/// Diálogo de confirmación fuerte + `DELETE /usuarios/me`.
///
/// Cancelar no llama a la API. Éxito / 401 navegan a `/login`.
Future<void> deleteAccountFromProfile(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: const Text(
        'Esta acción eliminará tu cuenta y cerrará tu sesión. Algunos datos '
        'operativos pueden conservarse anonimizados cuando sea necesario.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Eliminar cuenta'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final auth = Provider.of<AuthProvider>(context, listen: false);
  final userProv = Provider.of<UserProvider>(context, listen: false);
  final result = await auth.deleteAccount();
  if (!context.mounted) return;

  switch (result) {
    case DeleteAccountResult.success:
      userProv.logout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tu cuenta ha sido eliminada.')),
      );
      context.go('/login');
      return;
    case DeleteAccountResult.sessionExpired:
      userProv.logout();
      context.go('/login');
      return;
    case DeleteAccountResult.blocked:
    case DeleteAccountResult.failed:
      final message = auth.errorMessage ??
          'No se pudo eliminar la cuenta. Intenta de nuevo.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
  }
}
