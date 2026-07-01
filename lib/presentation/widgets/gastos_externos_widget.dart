import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_confirm_dialog.dart';
import 'package:parte_movil/data/datasources/gasto_externo_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/gasto_externo.dart';

DateTime _nowColombia() => DateTime.now().toUtc().subtract(const Duration(hours: 5));
String _fmtDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

final _moneyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _dayFmt = DateFormat('d MMM', 'es');

enum _FilterMode { dia, semana, mes, personalizado }

const _categoriaColors = {
  'Servicios': Color(0xFF6EA8FE),
  'Suministros': Color(0xFFA78BFA),
  'Mantenimiento': Color(0xFFFB923C),
  'Utilities': Color(0xFF34D399),
  'Alquiler': Color(0xFFF472B6),
  'Personal': Color(0xFFFBBF24),
  'Otros': Color(0xFF94A3B8),
};

class GastosExternosWidget extends StatefulWidget {
  const GastosExternosWidget({super.key});

  @override
  State<GastosExternosWidget> createState() => _GastosExternosWidgetState();
}

class _GastosExternosWidgetState extends State<GastosExternosWidget> {
  final _service = GastoExternoService();
  bool _loading = true;
  String? _error;
  bool _expanded = true;

  _FilterMode _filter = _FilterMode.dia;

  // Data for day mode (full resumen with KPIs)
  ResumenDia? _resumen;

  // Data for range modes (just gastos list)
  List<GastoExterno> _rangeGastos = [];

  // Date range
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = _nowColombia();
    _from = now;
    _to = now;
    _loadData();
  }

  void _applyFilter(_FilterMode mode) {
    final now = _nowColombia();
    setState(() => _filter = mode);
    switch (mode) {
      case _FilterMode.dia:
        _from = now;
        _to = now;
        break;
      case _FilterMode.semana:
        _from = now.subtract(Duration(days: now.weekday - 1)); // Monday
        _to = now;
        break;
      case _FilterMode.mes:
        _from = DateTime(now.year, now.month, 1);
        _to = now;
        break;
      case _FilterMode.personalizado:
        return; // don't reload, user picks dates
    }
    _loadData();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _nowColombia(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: Color(0xFF111111),
            surface: AppColors.card,
            onSurface: AppColors.white,
          ),
          dialogTheme: const DialogThemeData(backgroundColor: AppColors.bg),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _from = picked.start;
      _to = picked.end;
      setState(() => _filter = _FilterMode.personalizado);
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_filter == _FilterMode.dia) {
        final data = await _service.obtenerResumenDia(_fmtDate(_from));
        if (mounted) setState(() { _resumen = data; _rangeGastos = []; _loading = false; });
      } else {
        final data = await _service.obtenerPorRango(_fmtDate(_from), _fmtDate(_to));
        if (mounted) setState(() { _rangeGastos = data; _resumen = null; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<GastoExterno> get _gastos => _resumen?.gastos ?? _rangeGastos;
  double get _totalGastos => _resumen?.gastosExternos ?? _rangeGastos.fold(0.0, (s, g) => s + g.monto);

  Future<void> _openForm({GastoExterno? gasto}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GastoFormSheet(gasto: gasto, fecha: _fmtDate(_nowColombia())),
    );
    if (result == true) _loadData();
  }

  Future<void> _deleteGasto(GastoExterno gasto) async {
    final ok = await AppConfirmDialog.showWarning(
      context,
      title: 'Eliminar Gasto',
      message: 'Se eliminara "${gasto.descripcion}". Esta accion no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (ok == true) {
      try {
        await _service.eliminar(gasto.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String get _dateLabel {
    if (_filter == _FilterMode.dia) return 'Hoy';
    final f = _dayFmt.format(_from);
    final t = _dayFmt.format(_to);
    return '$f - $t';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFB923C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long, color: Color(0xFFFB923C), size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Gastos Externos', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                  if (!_loading)
                    InkWell(
                      onTap: _loadData,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: const Icon(Icons.refresh, color: AppColors.greyLight, size: 14),
                      ),
                    ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _openForm(),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppColors.goldGradient,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, color: Color(0xFF111111), size: 14),
                          SizedBox(width: 4),
                          Text('Nuevo', style: TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.greyLight, size: 20),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Container(height: 1, color: AppColors.divider),

            // ── Filter chips ──
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  _filterChip('Dia', _FilterMode.dia),
                  const SizedBox(width: 6),
                  _filterChip('Semana', _FilterMode.semana),
                  const SizedBox(width: 6),
                  _filterChip('Mes', _FilterMode.mes),
                  const Spacer(),
                  InkWell(
                    onTap: _pickDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: _filter == _FilterMode.personalizado
                            ? AppColors.gold.withValues(alpha: 0.15)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _filter == _FilterMode.personalizado
                              ? AppColors.gold.withValues(alpha: 0.5)
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 12,
                              color: _filter == _FilterMode.personalizado ? AppColors.gold : AppColors.greyLight),
                          const SizedBox(width: 4),
                          Text(
                            _filter == _FilterMode.personalizado ? _dateLabel : 'Fechas',
                            style: TextStyle(
                              fontSize: 11,
                              color: _filter == _FilterMode.personalizado ? AppColors.gold : AppColors.greyLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Date label
            if (_filter != _FilterMode.dia)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Text(_dateLabel, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
              ),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2)),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                    TextButton(onPressed: _loadData, child: const Text('Reintentar', style: TextStyle(color: AppColors.gold, fontSize: 12))),
                  ],
                ),
              )
            else ...[
              // KPI Row
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _filter == _FilterMode.dia && _resumen != null
                    ? Row(
                        children: [
                          Expanded(child: _miniKpi('Ingresos', _moneyFmt.format(_resumen!.ingresosTotal), const Color(0xFF34D399))),
                          const SizedBox(width: 8),
                          Expanded(child: _miniKpi('Gastos', _moneyFmt.format(_resumen!.gastosExternos), const Color(0xFFFB923C))),
                          const SizedBox(width: 8),
                          Expanded(child: _miniKpi(
                            'Neta',
                            _moneyFmt.format(_resumen!.gananciaNeta),
                            _resumen!.gananciaNeta >= 0 ? const Color(0xFF60A5FA) : Colors.redAccent,
                          )),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _miniKpi('Total Gastos', _moneyFmt.format(_totalGastos), const Color(0xFFFB923C))),
                          const SizedBox(width: 8),
                          Expanded(child: _miniKpi('Cantidad', '${_gastos.length}', const Color(0xFF6EA8FE))),
                        ],
                      ),
              ),
              const SizedBox(height: 12),

              // Gastos list
              if (_gastos.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Center(
                      child: Text(
                        _filter == _FilterMode.dia ? 'Sin gastos registrados hoy' : 'Sin gastos en este periodo',
                        style: const TextStyle(color: AppColors.grey, fontSize: 12),
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    children: _gastos.map((g) => _gastoTile(g)).toList(),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, _FilterMode mode) {
    final selected = _filter == mode;
    return InkWell(
      onTap: () => _applyFilter(mode),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.gold.withValues(alpha: 0.5) : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.gold : AppColors.greyLight,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _miniKpi(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: AppColors.greyLight, fontSize: 10, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _gastoTile(GastoExterno gasto) {
    final catColor = _categoriaColors[gasto.categoria] ?? const Color(0xFF94A3B8);
    final showDate = _filter != _FilterMode.dia;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gasto.descripcion, style: const TextStyle(color: AppColors.white, fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(gasto.categoria, style: TextStyle(color: catColor, fontSize: 9, fontWeight: FontWeight.w600)),
                    ),
                    if (showDate) ...[
                      const SizedBox(width: 6),
                      Text(
                        _dayFmt.format(DateTime.tryParse(gasto.fecha) ?? DateTime.now()),
                        style: const TextStyle(color: AppColors.grey, fontSize: 9),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(_moneyFmt.format(gasto.monto), style: const TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _openForm(gasto: gasto),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.edit_outlined, color: AppColors.greyLight, size: 14),
            ),
          ),
          InkWell(
            onTap: () => _deleteGasto(gasto),
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.delete_outline, color: Colors.redAccent, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── MONEY INPUT FORMATTER ────────────────────────────────────────────────────

class _MoneyInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,###', 'es_CO');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    final number = int.parse(digits);
    final formatted = _fmt.format(number);
    return TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
  }
}

// ── FORMULARIO (Bottom Sheet) ────────────────────────────────────────────────

class _GastoFormSheet extends StatefulWidget {
  final GastoExterno? gasto;
  final String fecha;
  const _GastoFormSheet({this.gasto, required this.fecha});

  @override
  State<_GastoFormSheet> createState() => _GastoFormSheetState();
}

class _GastoFormSheetState extends State<_GastoFormSheet> {
  final _service = GastoExternoService();
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _descCtrl;
  late final TextEditingController _montoCtrl;
  late final TextEditingController _notasCtrl;
  String _categoria = 'Servicios';
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.gasto != null;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.gasto?.descripcion ?? '');
    final montoFmt = NumberFormat('#,###', 'es_CO');
    _montoCtrl = TextEditingController(
      text: widget.gasto != null ? montoFmt.format(widget.gasto!.monto.toInt()) : '',
    );
    _notasCtrl = TextEditingController(text: widget.gasto?.notas ?? '');
    _categoria = widget.gasto?.categoria ?? 'Servicios';
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _montoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _saving = true; _error = null; });

    try {
      final user = _authService.currentUser;
      final usuarioId = widget.gasto?.usuarioId ?? (int.tryParse(user?.uid ?? '') ?? 0);
      final rawMonto = _montoCtrl.text.replaceAll(RegExp(r'[^\d]'), '');

      final data = {
        'descripcion': _descCtrl.text.trim(),
        'monto': double.tryParse(rawMonto) ?? 0,
        'categoria': _categoria,
        'fecha': widget.fecha,
        'notas': _notasCtrl.text.trim(),
        'usuarioId': usuarioId,
      };

      if (_isEdit) {
        await _service.actualizar(widget.gasto!.id, data);
      } else {
        await _service.crear(data);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.receipt_long, color: AppColors.gold, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isEdit ? 'Editar Gasto' : 'Nuevo Gasto Externo',
                      style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.greyLight, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                _label('Descripcion'),
                _textField(_descCtrl, 'Ej: Pago de servicios de agua',
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Monto (\$)'),
                          TextFormField(
                            controller: _montoCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _MoneyInputFormatter(),
                            ],
                            validator: (v) {
                              final raw = (v ?? '').replaceAll(RegExp(r'[^\d]'), '');
                              final n = int.tryParse(raw);
                              if (n == null || n <= 0) return 'Debe ser > 0';
                              return null;
                            },
                            style: const TextStyle(color: AppColors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: '0',
                              prefixText: '\$ ',
                              prefixStyle: const TextStyle(color: AppColors.gold, fontSize: 14, fontWeight: FontWeight.bold),
                              hintStyle: const TextStyle(color: AppColors.grey, fontSize: 13),
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Categoria'),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _categoria,
                                isExpanded: true,
                                dropdownColor: AppColors.card,
                                style: const TextStyle(color: AppColors.white, fontSize: 14),
                                items: categoriasGasto.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                onChanged: (v) { if (v != null) setState(() => _categoria = v); },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _label('Notas (opcional)'),
                _textField(_notasCtrl, 'Informacion adicional...', maxLines: 2),
                const SizedBox(height: 8),

                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.divider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.greyLight)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                            : Text(_isEdit ? 'Guardar cambios' : 'Registrar Gasto', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(color: AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint,
      {String? Function(String?)? validator, TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.grey, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold.withValues(alpha: 0.6))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
