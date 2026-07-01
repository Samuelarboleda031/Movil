import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_confirm_dialog.dart';
import 'package:parte_movil/data/datasources/gasto_externo_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/gasto_externo.dart';

String _todayColombia() {
  final now = DateTime.now().toUtc().subtract(const Duration(hours: 5));
  return DateFormat('yyyy-MM-dd').format(now);
}

final _moneyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

const _categoriaColors = {
  'Servicios': Color(0xFF6EA8FE),
  'Suministros': Color(0xFFA78BFA),
  'Mantenimiento': Color(0xFFFB923C),
  'Utilities': Color(0xFF34D399),
  'Alquiler': Color(0xFFF472B6),
  'Personal': Color(0xFFFBBF24),
  'Otros': Color(0xFF94A3B8),
};

class GastosExternosScreen extends StatefulWidget {
  const GastosExternosScreen({super.key});

  @override
  State<GastosExternosScreen> createState() => GastosExternosScreenState();
}

class GastosExternosScreenState extends State<GastosExternosScreen> {
  void openNewGastoForm() => _openForm();
  final _service = GastoExternoService();
  ResumenDia? _resumen;
  bool _loading = true;
  String? _error;
  late String _fecha;

  @override
  void initState() {
    super.initState();
    _fecha = _todayColombia();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.obtenerResumenDia(_fecha);
      if (mounted) setState(() { _resumen = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_fecha),
      firstDate: DateTime(2024),
      lastDate: DateTime.parse(_todayColombia()),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.gold,
              onPrimary: AppColors.bg,
              surface: AppColors.card,
              onSurface: AppColors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _fecha = DateFormat('yyyy-MM-dd').format(picked);
      _loadData();
    }
  }

  Future<void> _openForm({GastoExterno? gasto}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GastoFormSheet(gasto: gasto, fecha: _fecha),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Gastos Externos'),
        backgroundColor: AppColors.card,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            onPressed: _pickDate,
            tooltip: 'Cambiar fecha',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: _loadData,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: AppColors.greyLight), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _loadData, child: const Text('Reintentar')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppColors.gold,
                  backgroundColor: AppColors.card,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDateHeader(),
                      const SizedBox(height: 16),
                      _buildKPICards(),
                      const SizedBox(height: 20),
                      _buildGastosHeader(),
                      const SizedBox(height: 12),
                      if (_resumen!.gastos.isEmpty)
                        _buildEmptyState()
                      else
                        ..._resumen!.gastos.map(_buildGastoCard),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDateHeader() {
    final date = DateTime.parse(_fecha);
    final formatted = DateFormat("EEEE, d 'de' MMMM yyyy", 'es').format(date);
    final capitalized = formatted[0].toUpperCase() + formatted.substring(1);
    return Text(
      capitalized,
      style: const TextStyle(color: AppColors.greyLight, fontSize: 14),
    );
  }

  Widget _buildKPICards() {
    final r = _resumen!;
    final isProfit = r.gananciaNeta >= 0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _kpiCard(
              'Ingresos del dia',
              _moneyFormat.format(r.ingresosTotal),
              const Color(0xFF34D399),
              Icons.trending_up,
              subtitle: 'Servicios: ${_moneyFormat.format(r.ingresosAgendamientos)}',
            )),
            const SizedBox(width: 12),
            Expanded(child: _kpiCard(
              'Gastos externos',
              _moneyFormat.format(r.gastosExternos),
              const Color(0xFFFB923C),
              Icons.trending_down,
              subtitle: '${r.cantidadGastos} registro${r.cantidadGastos != 1 ? 's' : ''}',
            )),
          ],
        ),
        const SizedBox(height: 12),
        _kpiCard(
          'Ganancia neta',
          _moneyFormat.format(r.gananciaNeta),
          isProfit ? const Color(0xFF60A5FA) : Colors.redAccent,
          Icons.attach_money,
          subtitle: isProfit ? 'Resultado positivo' : 'Gastos superan ingresos',
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _kpiCard(String title, String value, Color color, IconData icon,
      {String? subtitle, bool fullWidth = false}) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(color: AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildGastosHeader() {
    return Row(
      children: [
        const Icon(Icons.receipt_long, color: AppColors.gold, size: 18),
        const SizedBox(width: 8),
        Text(
          'Gastos del dia (${_resumen!.gastos.length})',
          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.receipt_long, color: AppColors.grey, size: 24),
          ),
          const SizedBox(height: 16),
          const Text('Sin gastos registrados', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('No hay gastos externos para este dia.', style: TextStyle(color: AppColors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGastoCard(GastoExterno gasto) {
    final catColor = _categoriaColors[gasto.categoria] ?? const Color(0xFF94A3B8);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(gasto.descripcion, style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: catColor.withOpacity(0.3)),
                      ),
                      child: Text(gasto.categoria, style: TextStyle(color: catColor, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    if (gasto.usuarioNombre.isNotEmpty)
                      Expanded(
                        child: Text(gasto.usuarioNombre, style: const TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
                if (gasto.notas != null && gasto.notas!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(gasto.notas!, style: const TextStyle(color: AppColors.grey, fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_moneyFormat.format(gasto.monto), style: const TextStyle(color: Color(0xFFFB923C), fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _iconBtn(Icons.edit_outlined, AppColors.greyLight, () => _openForm(gasto: gasto)),
                  const SizedBox(width: 4),
                  _iconBtn(Icons.delete_outline, Colors.redAccent, () => _deleteGasto(gasto)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color.withOpacity(0.08),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
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
    _montoCtrl = TextEditingController(text: widget.gasto != null ? widget.gasto!.monto.toStringAsFixed(0) : '');
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

  Future<int> _resolveUsuarioId() async {
    final user = _authService.currentUser;
    if (user == null) return 0;
    final numericId = int.tryParse(user.uid) ?? 0;
    if (numericId > 0) return numericId;
    return 0;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() { _saving = true; _error = null; });

    try {
      final usuarioId = widget.gasto?.usuarioId ?? await _resolveUsuarioId();
      final data = {
        'descripcion': _descCtrl.text.trim(),
        'monto': double.tryParse(_montoCtrl.text) ?? 0,
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
                        color: AppColors.gold.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold.withOpacity(0.3)),
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
                          _textField(_montoCtrl, '0',
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final n = double.tryParse(v ?? '');
                                if (n == null || n <= 0) return 'Debe ser > 0';
                                return null;
                              }),
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
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
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
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.gold.withOpacity(0.6))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
