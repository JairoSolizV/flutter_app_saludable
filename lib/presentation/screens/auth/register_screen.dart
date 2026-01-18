import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
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
            colors: [Color(0xFF7AC142), Color(0xFF5A9E27)],
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
                        'Crear Cuenta',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Regístrate para comenzar',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 32),
                      
                      TextFormField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person), border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Correo Electrónico', prefixIcon: Icon(Icons.email), border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        validator: (v) => v!.isEmpty ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                        validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
                      ),
                      
                      const SizedBox(height: 24),

                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                            if (auth.errorMessage != null) {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(auth.errorMessage!, style: const TextStyle(color: Colors.red)),
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
                                  final success = await auth.register(
                                      _firstNameCtrl.text,
                                      _lastNameCtrl.text,
                                      _emailCtrl.text,
                                      _passCtrl.text,
                                      _phoneCtrl.text,
                                      rolId: 4 // 4 = USUARIO_BASICO
                                  );

                                  if (success && context.mounted) {
                                    final user = auth.currentUser;
                                    if (user != null) {
                                      Provider.of<UserProvider>(context, listen: false).setUser(user);
                                      // Navegar a basic home (pues rol es 4 por defecto ahora)
                                      context.go('/basic-home');
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7AC142),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: auth.isLoading 
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('REGISTRARSE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          );
                        }
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('¿Ya tienes cuenta? Inicia Sesión', style: TextStyle(color: Color(0xFF7AC142))),
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
