import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flutter_app_saludable/core/constants/counter_sale_payment_types.dart';
import 'package:flutter_app_saludable/core/theme/app_theme.dart';
import 'package:flutter_app_saludable/core/utils/bolivian_price.dart';
import 'package:flutter_app_saludable/core/utils/input_formatters.dart';
import '../../providers/counter_sale_provider.dart';

class HostCounterSaleTicketScreen extends StatefulWidget {
  const HostCounterSaleTicketScreen({super.key});

  @override
  State<HostCounterSaleTicketScreen> createState() =>
      _HostCounterSaleTicketScreenState();
}

class _HostCounterSaleTicketScreenState
    extends State<HostCounterSaleTicketScreen> {
  final TextEditingController _socioCtrl = TextEditingController();
  final TextEditingController _obsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<CounterSaleProvider>();
      _socioCtrl.text = provider.socioCodigo;
      _obsCtrl.text = provider.observaciones;
    });
  }

  @override
  void dispose() {
    _socioCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _finalizarVenta(BuildContext context) async {
    try {
      final provider =
          Provider.of<CounterSaleProvider>(context, listen: false);
      final ok = await provider.submitCounterSale();
      if (!mounted) return;

      if (ok) {
        final action = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Venta registrada'),
            content: const Text('Venta registrada correctamente'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('nueva_venta'),
                child: const Text('Nueva venta'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop('ver_pedidos'),
                child: const Text('Ver pedidos'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (action == 'nueva_venta') {
          provider.resetSale();
          _socioCtrl.clear();
          _obsCtrl.clear();
          Navigator.of(context).pop();
        } else if (action == 'ver_pedidos') {
          provider.resetSale();
          final navigator = Navigator.of(context);
          navigator.pop();
          if (navigator.canPop()) {
            navigator.pop(true);
          }
          if (mounted) {
            context.go('/host-orders');
          }
        }
      } else {
        final message = provider.submitError ?? 'No se pudo registrar la venta';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[COUNTER SALE TICKET] finalizar error: $e');
      debugPrint('[COUNTER SALE TICKET] stack: $st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado al finalizar la venta.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Ticket de venta'),
      ),
      body: Consumer<CounterSaleProvider>(
        builder: (context, provider, _) {
          final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionTitle('Productos'),
                        if (provider.cartLines.isEmpty &&
                            provider.comboCartLines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('Sin productos agregados'),
                            ),
                          )
                        else if (provider.cartLines.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Sin productos sueltos',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          )
                        else
                          ...provider.cartLines.map((line) {
                            final key = line.configKey;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.product.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (line.optionsSummary.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4,
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          line.optionsSummary,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    Row(
                                      children: [
                                        _QtyButton(
                                          icon: Icons.remove,
                                          onTap: () =>
                                              provider.decreaseQty(key),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            '${line.quantity}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        _QtyButton(
                                          icon: Icons.add,
                                          onTap: () =>
                                              provider.increaseQty(key),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${line.quantity} × ${BolivianPrice.formatBs(line.unitPrice)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              BolivianPrice.formatBs(
                                                line.subtotal,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      key: Key('line-note-$key'),
                                      initialValue: line.note,
                                      onChanged: (v) =>
                                          provider.setLineNote(key, v),
                                      maxLength: 500,
                                      inputFormatters:
                                          AppFormatters.largo(500),
                                      decoration: const InputDecoration(
                                        hintText: 'Nota del ítem (opcional)',
                                        isDense: true,
                                        border: OutlineInputBorder(),
                                        counterText: '',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        if (provider.comboCartLines.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const _SectionTitle('Combos'),
                          ...provider.comboCartLines.map((line) {
                            final key = line.configKey;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.comboName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Incluye:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    ...line.ticketComponentLines().map(
                                          (componentLine) => Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8,
                                              top: 2,
                                            ),
                                            child: Text(
                                              '- $componentLine',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ),
                                        ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _QtyButton(
                                          icon: Icons.remove,
                                          onTap: () =>
                                              provider.decreaseComboQty(key),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          child: Text(
                                            '${line.quantity}',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        _QtyButton(
                                          icon: Icons.add,
                                          onTap: () =>
                                              provider.increaseComboQty(key),
                                        ),
                                        const Spacer(),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${line.quantity} × ${BolivianPrice.formatBs(line.price)}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              BolivianPrice.formatBs(
                                                line.lineTotal,
                                              ),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ítems: ${provider.totalCartUnits}'
                              '${provider.totalComboUnits > 0 ? ' (${provider.totalProductUnits} prod. · ${provider.totalComboUnits} combos)' : ''}',
                            ),
                            Text('Puntos: ${provider.totalPuntos}'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              BolivianPrice.formatBs(provider.totalBs),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Cliente'),
                        const SizedBox(height: 8),
                        _SocioBlock(
                          socioCtrl: _socioCtrl,
                          appliedCode: provider.socioCodigo.trim(),
                          onApply: () {
                            provider.setSocioCodigo(_socioCtrl.text.trim());
                          },
                          onCodeChanged: (value) {
                            if (value.trim() !=
                                provider.socioCodigo.trim()) {
                              provider.setSocioCodigo('');
                            }
                          },
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Forma de pago'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              CounterSalePaymentTypes.backendValues.map((value) {
                            final selected = provider.tipoPago == value;
                            return ChoiceChip(
                              key: Key('payment-$value'),
                              label: Text(CounterSalePaymentTypes.label(value)),
                              selected: selected,
                              onSelected: (_) => provider.setTipoPago(value),
                              selectedColor:
                                  AppTheme.primaryColor.withOpacity(0.2),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Observaciones'),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('counter-observations'),
                          controller: _obsCtrl,
                          onChanged: provider.setObservaciones,
                          maxLines: 3,
                          maxLength: 500,
                          inputFormatters: AppFormatters.largo(500),
                          decoration: const InputDecoration(
                            hintText: 'Observaciones de la venta (opcional)',
                            border: OutlineInputBorder(),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            key: const Key('counter-finalize-sale'),
                            onPressed: provider.canSubmit
                                ? () => _finalizarVenta(context)
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(52),
                            ),
                            child: provider.isSubmitting
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Finalizar venta',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.5,
        color: AppTheme.primaryColor,
      ),
    );
  }
}

class _SocioBlock extends StatelessWidget {
  final TextEditingController socioCtrl;
  final String appliedCode;
  final VoidCallback onApply;
  final ValueChanged<String> onCodeChanged;

  const _SocioBlock({
    required this.socioCtrl,
    required this.appliedCode,
    required this.onApply,
    required this.onCodeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPublic = appliedCode.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('counter-socio-code'),
                controller: socioCtrl,
                keyboardType: TextInputType.text,
                maxLength: 30,
                inputFormatters: AppFormatters.largo(30),
                decoration: const InputDecoration(
                  labelText: 'Código de socio (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  counterText: '',
                ),
                onChanged: onCodeChanged,
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const Key('counter-socio-apply'),
              onPressed: onApply,
              child: const Text('Aplicar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Chip(
          label: Text(isPublic ? 'Venta al público' : 'Código aplicado'),
          backgroundColor: isPublic
              ? Colors.grey.shade100
              : AppTheme.primaryColor.withOpacity(0.15),
        ),
        const SizedBox(height: 4),
        Text(
          'Se verificará al finalizar la venta.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
