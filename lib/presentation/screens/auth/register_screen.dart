import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_app_saludable/core/utils/validators.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

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
  
  final _emailFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _checkingEmail = false;
  String? _emailValidationError;

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocusChange);
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      _checkEmailAvailability();
    }
  }

  Future<void> _checkEmailAvailability() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    
    final formatError = Validators.validateEmail(email);
    if (formatError != null) {
      setState(() {
        _emailValidationError = formatError;
      });
      return;
    }

    setState(() {
      _checkingEmail = true;
      _emailValidationError = null;
    });

    final exists = await Provider.of<AuthProvider>(context, listen: false).checkEmailExists(email);

    if (mounted) {
      setState(() {
        _checkingEmail = false;
        if (exists) {
          _emailValidationError = 'Este correo ya está registrado';
        } else {
          _emailValidationError = null;
        }
      });
    }
  }

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
                        validator: Validators.validateName,
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: Validators.validateName,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocusNode,
                        decoration: InputDecoration(
                          labelText: 'Correo Electrónico',
                          prefixIcon: const Icon(Icons.email),
                          border: const OutlineInputBorder(),
                          suffixIcon: _checkingEmail
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Padding(
                                    padding: EdgeInsets.all(12.0),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : null,
                        ),
                        validator: (value) {
                          final formatError = Validators.validateEmail(value);
                          if (formatError != null) return formatError;
                          return _emailValidationError;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        validator: Validators.validateBolivianPhone,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder()),
                        validator: Validators.validatePassword,
                      ),
                      
                      const SizedBox(height: 16),

                      CheckboxListTile(
                        value: _acceptTerms,
                        onChanged: (val) {
                          setState(() {
                            _acceptTerms = val ?? false;
                          });
                        },
                        title: const Text(
                          'Acepto los Términos y Condiciones',
                          style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                      ),

                      CheckboxListTile(
                        value: _acceptPrivacy,
                        onChanged: (val) {
                          setState(() {
                            _acceptPrivacy = val ?? false;
                          });
                        },
                        title: const Text(
                          'Consiento el tratamiento de mis datos personales de salud',
                          style: TextStyle(fontSize: 13, color: Color(0xFF333333)),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        activeColor: AppTheme.primaryColor,
                      ),

                      const SizedBox(height: 16),

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
                          final canRegister = _acceptTerms && _acceptPrivacy && !_checkingEmail && _emailValidationError == null;

                          return SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (auth.isLoading || !canRegister) ? null : () async {
                                if (_formKey.currentState!.validate()) {
                                  // Preprocesar el teléfono al formato E.164 requerido por el backend (+591...)
                                  String phoneToSend = _phoneCtrl.text.trim();
                                  if (!phoneToSend.startsWith('+')) {
                                    if (phoneToSend.length == 8) {
                                      phoneToSend = '+591$phoneToSend';
                                    }
                                  }

                                  final success = await auth.register(
                                      _firstNameCtrl.text,
                                      _lastNameCtrl.text,
                                      _emailCtrl.text.trim(),
                                      _passCtrl.text,
                                      phoneToSend,
                                      rolId: 4 // 4 = USUARIO_BASICO
                                  );

                                  if (success && context.mounted) {
                                    final user = auth.currentUser;
                                    if (user != null) {
                                      Provider.of<UserProvider>(context, listen: false).setUser(user);
                                      context.go('/basic-home');
                                    }
                                  }
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                disabledBackgroundColor: Colors.grey.shade300,
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
                        child: const Text('¿Ya tienes cuenta? Inicia Sesión', style: TextStyle(color: AppTheme.primaryColor)),
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
