import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
               // Si vinimos con context.go(), no hay historial para pop. 
               // Volvemos al home de invitado.
              context.go('/guest-home');
            }
          },
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.primaryGradient,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inicia sesión en tu cuenta',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                        onChanged: (value) {
                          // Limpiar error cuando el usuario empiece a escribir
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          if (auth.errorMessage != null) {
                            auth.clearError();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => v!.isEmpty ? 'Campo requerido' : null,
                        onChanged: (value) {
                          // Limpiar error cuando el usuario empiece a escribir
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          if (auth.errorMessage != null) {
                            auth.clearError();
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                            if (auth.errorMessage != null) {
                                return Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      border: Border.all(color: Colors.red.shade300, width: 1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            auth.errorMessage!,
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                );
                            }
                            return const SizedBox.shrink();
                        },
                      ),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : () async {
                                if (_formKey.currentState!.validate()) {
                                  final success = await auth.login(_emailCtrl.text, _passCtrl.text);
                                  if (success && context.mounted) {
                                    // Sync profile to get complete user data (including telefono)
                                    // Login doesn't return telefono, but /auth/me does
                                    await auth.syncProfile();
                                    
                                    final user = auth.currentUser;
                                    if (user != null) {
                                      // Actualizar UserProvider con el usuario logueado
                                      Provider.of<UserProvider>(context, listen: false).setUser(user);
                                      
                                      if (user.role == 'host') {
                                         context.go('/host-dashboard');
                                      } else if (user.role == 'basic_user') {
                                         context.go('/basic-home');
                                      } else {
                                         context.go('/member-home');
                                      }
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: auth.isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('INGRESAR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('O', style: TextStyle(color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: auth.isLoading ? null : () async {
                                final success = await auth.loginWithGoogle();
                                if (success && context.mounted) {
                                  await auth.syncProfile();
                                  final user = auth.currentUser;
                                  if (user != null) {
                                    Provider.of<UserProvider>(context, listen: false).setUser(user);
                                    if (user.role == 'host') {
                                       context.go('/host-dashboard');
                                    } else if (user.role == 'basic_user') {
                                       context.go('/basic-home');
                                    } else {
                                       context.go('/member-home');
                                    }
                                  }
                                }
                              },
                              icon: Image.asset(
                                'assets/images/google_logo.png', // Necesitaremos este asset
                                height: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
                              ),
                              label: const Text('Iniciar con Google', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.grey),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.push('/register'),
                        child: const Text('¿No tienes cuenta? Regístrate aquí', style: TextStyle(color: AppTheme.primaryColor)),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
