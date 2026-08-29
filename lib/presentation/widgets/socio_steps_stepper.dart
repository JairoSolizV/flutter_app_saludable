import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';

/// Guía informativa navegable con los pasos para que un usuario básico
/// se convierta en socio de un club.
///
/// Es puramente explicativa: no consulta el backend ni refleja progreso real.
/// Son solo 3 pasos, a propósito: lo único que el usuario necesita entender es
/// que su QR lo activa un anfitrión.
///
/// El widget fija su propia altura: [Stepper] con [StepperType.horizontal]
/// usa un `Expanded` internamente y reventaría con constraints de alto
/// infinitas (p. ej. dentro de un `SingleChildScrollView`).
class SocioStepsStepper extends StatefulWidget {
  const SocioStepsStepper({super.key});

  /// Alto reservado para el stepper (cabecera + contenido + controles).
  static const double height = 320;

  @override
  State<SocioStepsStepper> createState() => _SocioStepsStepperState();
}

class _SocioStepsStepperState extends State<SocioStepsStepper> {
  static const int _stepCount = 3;

  int _currentStep = 0;

  bool get _isFirstStep => _currentStep == 0;
  bool get _isLastStep => _currentStep == _stepCount - 1;

  void _onStepContinue() {
    if (!_isLastStep) setState(() => _currentStep += 1);
  }

  void _onStepCancel() {
    if (!_isFirstStep) setState(() => _currentStep -= 1);
  }

  StepState _stateFor(int index) {
    if (_currentStep > index) return StepState.complete;
    if (_currentStep == index) return StepState.editing;
    return StepState.indexed;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: SocioStepsStepper.height,
      child: Stepper(
        type: StepperType.horizontal,
        elevation: 0,
        currentStep: _currentStep,
        onStepContinue: _onStepContinue,
        onStepCancel: _onStepCancel,
        onStepTapped: (index) => setState(() => _currentStep = index),
        controlsBuilder: _buildControls,
        steps: _stepList(),
      ),
    );
  }

  Widget _buildControls(BuildContext context, ControlsDetails details) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          if (!_isFirstStep) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: details.onStepCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size.fromHeight(45),
                ),
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (!_isLastStep)
            Expanded(
              child: ElevatedButton(
                onPressed: details.onStepContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  minimumSize: const Size.fromHeight(45),
                ),
                child: const Text('Siguiente'),
              ),
            ),
        ],
      ),
    );
  }

  List<Step> _stepList() => [
        Step(
          title: const Text('Tu QR'),
          isActive: _currentStep >= 0,
          state: _stateFor(0),
          content: const _StepBody(
            icon: LucideIcons.qrCode,
            title: 'Mostrá tu QR en un club',
            description:
                'Acercate a un Club de Nutrición y mostrale al anfitrión el '
                'código QR que aparece arriba.',
          ),
        ),
        Step(
          title: const Text('Registro'),
          isActive: _currentStep >= 1,
          state: _stateFor(1),
          content: const _StepBody(
            icon: LucideIcons.userCheck,
            title: 'El anfitrión te registra',
            description:
                'Escanea tu código y completa tu alta como socio del club.',
          ),
        ),
        Step(
          title: const Text('¡Listo!'),
          isActive: _currentStep >= 2,
          state: _stateFor(2),
          content: const _StepBody(
            icon: LucideIcons.partyPopper,
            title: 'Ya sos socio',
            description:
                'Desbloqueás pedidos, asistencias y los beneficios del club.',
          ),
        ),
      ];
}

class _StepBody extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _StepBody({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: AppTheme.primaryLighter,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
