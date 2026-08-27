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
  final _confirmPassCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  final _emailFocusNode = FocusNode();
  final _passFocusNode = FocusNode();
  final _confirmPassFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();

  bool _acceptTerms = false;
  bool _acceptPrivacy = false;
  bool _checkingEmail = false;
  String? _emailValidationError;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  static const _emailTakenMessage = 'Este correo ya está registrado';

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(_onEmailFocusChange);
    // AuthProvider.errorMessage es global y sobrevive a la navegación: si venimos
    // de un login fallido, el mensaje rojo se arrastraría hasta esta pantalla.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<AuthProvider>(context, listen: false).clearError();
    });
  }

  @override
  void dispose() {
    _emailFocusNode.removeListener(_onEmailFocusChange);
    _emailFocusNode.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _passFocusNode.dispose();
    _confirmPassFocusNode.dispose();
    super.dispose();
  }

  void _onEmailFocusChange() {
    if (!_emailFocusNode.hasFocus) {
      _checkEmailAvailability();
    }
  }

  /// Descarta el error global de AuthProvider en cuanto el usuario edita algo.
  void _clearAuthError() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.errorMessage != null) {
      auth.clearError();
    }
  }

  Future<void> _checkEmailAvailability() async {
    final email = Validators.normalizeEmail(_emailCtrl.text);
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

    if (!mounted) return;

    // Si el usuario corrigió el correo mientras la petición estaba en vuelo,
    // la respuesta corresponde a otro correo y no debe pintarse.
    final isStale =
        Validators.normalizeEmail(_emailCtrl.text) != email;

    setState(() {
      _checkingEmail = false;
      if (!isStale) {
        _emailValidationError = exists ? _emailTakenMessage : null;
      }
    });
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
                        onChanged: (_) => _clearAuthError(),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(labelText: 'Apellido', prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                        validator: Validators.validateName,
                        onChanged: (_) => _clearAuthError(),
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
                        onChanged: (_) {
                          _clearAuthError();
                          // El aviso anterior ya no aplica al correo que se está escribiendo.
                          if (_emailValidationError != null) {
                            setState(() => _emailValidationError = null);
                          }
                        },
                      ),

                      // El validator del campo solo se pinta tras validate(), que no
                      // llega a ejecutarse mientras el botón está deshabilitado: sin este
                      // aviso el usuario ve el botón gris y ninguna explicación.
                      if (_emailValidationError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _emailValidationError!,
                                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                                    ),
                                    if (_emailValidationError == _emailTakenMessage)
                                      GestureDetector(
                                        onTap: () => context.go('/login'),
                                        child: const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Inicia sesión con este correo',
                                            style: TextStyle(
                                              color: AppTheme.primaryColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              decoration: TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Teléfono', prefixIcon: Icon(Icons.phone), border: OutlineInputBorder()),
                        validator: Validators.validateBolivianPhone,
                        keyboardType: TextInputType.phone,
                        onChanged: (_) => _clearAuthError(),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _passCtrl,
                        focusNode: _passFocusNode,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_confirmPassFocusNode),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: Validators.validatePassword,
                        onChanged: (_) {
                          _clearAuthError();
                          if (_confirmPassCtrl.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        focusNode: _confirmPassFocusNode,
                        obscureText: _obscureConfirmPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_acceptTerms &&
                              _acceptPrivacy &&
                              !_checkingEmail &&
                              _emailValidationError == null) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirmar contraseña',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) =>
                            Validators.validatePasswordConfirmation(
                          value,
                          _passCtrl.text,
                        ),
                        onChanged: (_) => _clearAuthError(),
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

                                  final email =
                                      Validators.normalizeEmail(_emailCtrl.text);
                                  final success = await auth.register(
                                      _firstNameCtrl.text,
                                      _lastNameCtrl.text,
                                      email,
                                      _passCtrl.text,
                                      phoneToSend,
                                      rolId: 4 // 4 = USUARIO_BASICO
                                  );

                                  if (success && context.mounted) {
                                    // Redirigir a verificación de correo
                                    if (auth.requiresVerification) {
                                      context.go('/verify-email', extra: {
                                        'email': email,
                                      });
                                    } else {
                                      final user = auth.currentUser;
                                      if (user != null) {
                                        Provider.of<UserProvider>(context, listen: false).setUser(user);
                                        context.go('/basic-home');
                                      }
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
