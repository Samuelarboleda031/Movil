import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/data/datasources/day_discount_service.dart';

class ModalDescuentoDia extends StatefulWidget {
  final DateTime fecha;
  final double descuentoActual;
  final VoidCallback onSaved;

  const ModalDescuentoDia({
    super.key,
    required this.fecha,
    required this.descuentoActual,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context,
    DateTime fecha,
    double descuentoActual,
    VoidCallback onSaved,
  ) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ModalDescuentoDia(
        fecha: fecha,
        descuentoActual: descuentoActual,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ModalDescuentoDia> createState() => _ModalDescuentoDiaState();
}

class _ModalDescuentoDiaState extends State<ModalDescuentoDia> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  static const _meses = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.descuentoActual > 0 ? widget.descuentoActual.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _fechaLabel {
    final d = widget.fecha;
    return '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';
  }

  Future<void> _guardar() async {
    final texto = _ctrl.text.trim();
    final valor = texto.isEmpty ? 0.0 : (double.tryParse(texto) ?? 0.0);
    if (valor < 0 || valor > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El descuento debe estar entre 0 y 100.')),
      );
      return;
    }
    setState(() => _saving = true);
    await DayDiscountService.setDiscount(DayDiscountService.fechaKey(widget.fecha), valor);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
  }

  Future<void> _quitar() async {
    setState(() => _saving = true);
    await DayDiscountService.setDiscount(DayDiscountService.fechaKey(widget.fecha), 0);
    if (!mounted) return;
    widget.onSaved();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descuento del día',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _fechaLabel,
                      style: const TextStyle(color: AppColors.grey, fontSize: 13),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Aplica un porcentaje de descuento a todos los servicios y paquetes agendados para este día.',
              style: TextStyle(color: AppColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.percent, color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                        child: TextField(
                          controller: _ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,3}(\.\d{0,2})?')),
                          ],
                          style: const TextStyle(color: AppColors.white, fontSize: 16),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(color: AppColors.grey),
                            suffixText: '%',
                            suffixStyle: TextStyle(color: AppColors.grey, fontSize: 16),
                          ),
                          onChanged: (val) {
                            final d = double.tryParse(val) ?? 0;
                            if (d > 100) {
                              _ctrl.text = '100';
                            }
                          },
                          autofocus: true,
                        ),
                      ),
                ],
              ),
            ),
            if (widget.descuentoActual > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.grey, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Descuento actual: ${widget.descuentoActual.toStringAsFixed(0)}%',
                    style: const TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.descuentoActual > 0)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _quitar,
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Quitar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.red,
                        side: const BorderSide(color: AppColors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                if (widget.descuentoActual > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _guardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                          )
                        : const Text(
                            'Guardar',
                            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
