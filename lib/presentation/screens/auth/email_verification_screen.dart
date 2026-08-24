import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/user_provider.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

class EmailVerificationScreen extends StatefulWidget {
  /// Email desde GoRouter extra; si falta (cold start), se lee del store local.
  final String? email;

  const EmailVerificationScreen({super.key, this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  // El KeyboardListener necesita su propio FocusNode. Antes se construía uno
  // nuevo en cada build (`FocusNode()` inline) y nunca se liberaba.
  final List<FocusNode> _keyboardFocusNodes =
      List.generate(6, (_) => FocusNode());

  Timer? _resendTimer;
  int _resendCooldown = 0;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _codeComplete = false;
  String? _resolvedEmail;
  bool _loadingEmail = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _resolveEmail();
    // Focus the first field after email is known
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resolvedEmail != null && _resolvedEmail!.isNotEmpty) {
        _focusNodes[0].requestFocus();
      }
    });

    // Shake animation for error feedback
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  Future<void> _resolveEmail() async {
    final fromExtra = widget.email?.trim();
    if (fromExtra != null && fromExtra.isNotEmpty) {
      setState(() {
        _resolvedEmail = fromExtra;
        _loadingEmail = false;
      });
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final stored = await auth.getPendingVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resolvedEmail = stored ?? '';
      _loadingEmail = false;
    });
  }

  String get _email => _resolvedEmail ?? '';

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    for (final f in _keyboardFocusNodes) {
      f.dispose();
    }
    _resendTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  String get _fullCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      // Move to next field
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {
      _codeComplete = _fullCode.length == 6;
      _errorMessage = null;
    });

    // Auto-submit when all 6 digits are entered
    if (_fullCode.length == 6) {
      _verifyCode();
    }
  }

  void _onKeyPressed(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _verifyCode() async {
    if (_isVerifying || _email.isEmpty) return;

    final code = _fullCode;
    if (code.length != 6) {
      setState(() => _errorMessage = 'Ingresa los 6 dígitos del código');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final verified = await auth.verifyEmail(_email, code);

    if (!mounted) return;

    setState(() => _isVerifying = false);

    if (verified) {
      // Success! Navigate to home
      _showSuccessAndNavigate();
    } else {
      // Error — shake the inputs and show error
      _shakeController.forward(from: 0);
      setState(() {
        _errorMessage = auth.errorMessage ?? 'Código inválido o expirado';
      });
      // Clear inputs
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      setState(() => _codeComplete = false);
    }
  }

  void _showSuccessAndNavigate() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user != null && mounted) {
      Provider.of<UserProvider>(context, listen: false).setUser(user);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('¡Correo verificado exitosamente!'),
          ],
        ),
        backgroundColor: AppTheme.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate to basic-home after a brief delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        context.go('/basic-home');
      }
    });
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _email.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.resendCode(_email);

    if (!mounted) return;

    if (success) {
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.email_outlined, color: Colors.white),
              SizedBox(width: 12),
              Text('Código reenviado. Revisa tu correo.'),
            ],
          ),
          backgroundColor: AppTheme.info,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Error al reenviar código'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEmail) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_email.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Verificar correo')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No encontramos un correo pendiente de verificación.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Ir a iniciar sesión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (context.canPop()) {
              context.pop();
              return;
            }
            final auth = Provider.of<AuthProvider>(context, listen: false);
            await auth.clearPendingVerificationEmail();
            auth.clearVerificationFlag();
            if (context.mounted) {
              context.go('/login');
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
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 400 ? 16 : 24,
              vertical: 24,
            ),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 400 ? 20 : 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email icon with circular background
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLighter,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Verificar Correo',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      'Enviamos un código de 6 dígitos a',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 32),

                    // OTP input fields with shake animation
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        final shakeOffset = _shakeAnimation.value *
                            10 *
                            ((_shakeController.value * 6).toInt().isOdd
                                ? 1
                                : -1);
                        return Transform.translate(
                          offset: Offset(shakeOffset, 0),
                          child: child,
                        );
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Antes las casillas eran fijas (46px + 12 de margen
                          // cada una = 336px) y desbordaban en cualquier pantalla
                          // estrecha. Ahora se reparte el ancho disponible: se
                          // limita el máximo para que no se deformen en tablets,
                          // pero nunca se fuerza un mínimo, así jamás desborda.
                          const gap = 8.0;
                          final boxWidth =
                              ((constraints.maxWidth - gap * 5) / 6)
                                  .clamp(0.0, 52.0);
                          final boxHeight = boxWidth * 1.22;
                          final fontSize = (boxWidth * 0.52).clamp(14.0, 24.0);

                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Container(
                                width: boxWidth,
                                height: boxHeight,
                                margin: EdgeInsets.only(
                                  left: index == 0 ? 0 : gap,
                                ),
                                child: KeyboardListener(
                                  focusNode: _keyboardFocusNodes[index],
                                  onKeyEvent: (event) =>
                                      _onKeyPressed(index, event),
                                  child: TextField(
                                    controller: _controllers[index],
                                    focusNode: _focusNodes[index],
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor:
                                          _controllers[index].text.isNotEmpty
                                              ? AppTheme.primaryLighter
                                                  .withValues(alpha: 0.5)
                                              : Colors.grey.shade50,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppTheme.primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: _controllers[index]
                                                  .text
                                                  .isNotEmpty
                                              ? AppTheme.primaryLight
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onChanged: (value) =>
                                        _onDigitChanged(index, value),
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Error message
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline,
                                  color: AppTheme.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Verify button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_isVerifying || !_codeComplete)
                            ? null
                            : _verifyCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          disabledBackgroundColor: Colors.grey.shade300,
                        ),
                        child: _isVerifying
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'VERIFICAR',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Divider
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        // Flexible para que el texto se ajuste en vez de
                        // desbordar cuando el usuario tiene el tamaño de letra
                        // del sistema ampliado por accesibilidad.
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '¿No recibiste el código?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Resend button
                    TextButton.icon(
                      onPressed: _resendCooldown > 0 ? null : _resendCode,
                      icon: Icon(
                        Icons.refresh,
                        size: 18,
                        color: _resendCooldown > 0
                            ? Colors.grey
                            : AppTheme.primaryColor,
                      ),
                      label: Text(
                        _resendCooldown > 0
                            ? 'Reenviar en ${_resendCooldown}s'
                            : 'Reenviar Código',
                        style: TextStyle(
                          color: _resendCooldown > 0
                              ? Colors.grey
                              : AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Expiration notice
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined,
                              color: AppTheme.warning, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'El código expira en 15 minutos',
                              style: TextStyle(
                                color: Colors.orange.shade800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
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
