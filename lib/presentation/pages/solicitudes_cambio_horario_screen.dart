import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/solicitud_cambio_horario_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/solicitud_cambio_horario.dart';
import 'package:parte_movil/data/models/barbero.dart';

class SolicitudesCambioHorarioScreen extends StatefulWidget {
  final AppRole role;
  const SolicitudesCambioHorarioScreen({super.key, required this.role});

  @override
  State<SolicitudesCambioHorarioScreen> createState() => _SolicitudesCambioHorarioScreenState();
}

class _SolicitudesCambioHorarioScreenState extends State<SolicitudesCambioHorarioScreen> {
  final _service = SolicitudCambioHorarioService();
  final _searchController = TextEditingController();
  List<SolicitudCambioHorario> _solicitudes = [];
  bool _isLoading = true;
  int? _currentUserId;
  Barbero? _miBarberoPerfil;
  String _searchQuery = '';
  String _filtroEstado = 'Todas';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = await AuthService().getCurrentUser();
    _currentUserId = user?.id;

    if (widget.role == AppRole.barber) {
      _miBarberoPerfil = await UserContextService().obtenerBarberoActual();
    }
    await _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final list = await _service.getSolicitudes(
        barberoId: widget.role == AppRole.barber ? _miBarberoPerfil?.id : null,
        pageSize: 50,
      );
      if (mounted) setState(() { _solicitudes = list; _isLoading = false; });
    } catch (e) {
      if (mounted) { setState(() => _isLoading = false); AppToast.showError(context, limpiarError(e)); }
    }
  }

  List<SolicitudCambioHorario> get _solicitudesFiltradas {
    var resultado = _solicitudes;

    if (_filtroEstado != 'Todas') {
      resultado = resultado.where((s) => s.estado == _filtroEstado).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      resultado = resultado.where((s) {
        final barbero = (s.barberoNombre ?? '').toLowerCase();
        final motivo = s.motivoCategoria.toLowerCase();
        final detalle = (s.motivoDetalle ?? '').toLowerCase();
        return barbero.contains(q) || motivo.contains(q) || detalle.contains(q);
      }).toList();
    }

    return resultado;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _estadoColor(String estado) {
    switch (estado) {
      case 'Aprobada': return Colors.green;
      case 'Rechazada': return Colors.red;
      case 'Sugerida': return Colors.orange;
      default: return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Solicitudes de Cambio de Horario',
            style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.bg,
        iconTheme: const IconThemeData(color: AppColors.gold),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.gold), onPressed: _cargar),
        ],
      ),
      floatingActionButton: widget.role == AppRole.barber
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.bg,
              icon: const Icon(Icons.add),
              label: const Text('Nueva Solicitud'),
              onPressed: _miBarberoPerfil != null ? _mostrarFormNueva : null,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                hintText: 'Buscar solicitud...',
                hintStyle: const TextStyle(color: AppColors.grey),
                prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                filled: true,
                fillColor: AppColors.card,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 20, color: AppColors.grey), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                ...['Todas', 'Pendiente', 'Aprobada', 'Rechazada'].map((e) {
                  final sel = _filtroEstado == e;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(e, style: TextStyle(color: sel ? AppColors.bg : AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600)),
                      selected: sel,
                      onSelected: (_) => setState(() => _filtroEstado = e),
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: sel ? AppColors.gold : AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                : RefreshIndicator(
                    color: AppColors.gold,
                    onRefresh: _cargar,
                    child: _solicitudesFiltradas.isEmpty
                        ? ListView(children: [
                            const SizedBox(height: 80),
                            Center(
                              child: Column(children: [
                                const Icon(Icons.inbox, size: 48, color: AppColors.grey),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isNotEmpty || _filtroEstado != 'Todas'
                                      ? 'No hay solicitudes con estos filtros'
                                      : 'No hay solicitudes',
                                  style: const TextStyle(color: AppColors.grey),
                                ),
                              ]),
                            ),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                            itemCount: _solicitudesFiltradas.length,
                            itemBuilder: (_, i) => _buildCard(_solicitudesFiltradas[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(SolicitudCambioHorario s) {
    final esAdmin = widget.role == AppRole.admin || widget.role == AppRole.manager;
    final esPendiente = s.estado == 'Pendiente';
    final esSugerida = s.estado == 'Sugerida';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: _estadoColor(s.estado).withOpacity(0.3), width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    esAdmin ? (s.barberoNombre ?? 'Barbero #${s.barberoId}') : s.motivoCategoria,
                    style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _estadoColor(s.estado).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _estadoColor(s.estado).withOpacity(0.4)),
                  ),
                  child: Text(s.estado, style: TextStyle(color: _estadoColor(s.estado), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (esAdmin) Text(s.motivoCategoria, style: const TextStyle(color: AppColors.gold, fontSize: 13)),
            if (s.motivoDetalle != null && s.motivoDetalle!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.motivoDetalle!, style: const TextStyle(color: AppColors.greyLight, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.calendar_today, color: AppColors.grey, size: 14),
              const SizedBox(width: 6),
              Text(
                'Ref: ${s.fechaReferencia.day}/${s.fechaReferencia.month}/${s.fechaReferencia.year}',
                style: const TextStyle(color: AppColors.grey, fontSize: 12),
              ),
            ]),
            if (s.sugerencias.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Sugerencias:', style: TextStyle(color: AppColors.greyLight, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...s.sugerencias.map((sg) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Icon(
                    sg.origen == 'Admin' ? Icons.admin_panel_settings : Icons.person,
                    color: sg.origen == 'Admin' ? Colors.orange : AppColors.gold,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${sg.diaSugerido.day}/${sg.diaSugerido.month}/${sg.diaSugerido.year}  ${AppFormat.to12h(sg.horaInicio)}–${AppFormat.to12h(sg.horaFin)}',
                    style: const TextStyle(color: AppColors.greyLight, fontSize: 12),
                  ),
                ]),
              )),
            ],
            if (s.observacionAdmin != null && s.observacionAdmin!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Text(s.observacionAdmin!, style: const TextStyle(color: AppColors.greyLight, fontSize: 12)),
              ),
            ],
            if (esAdmin && esPendiente) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Aprobar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                    onPressed: () => _aprobar(s),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Rechazar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    onPressed: () => _mostrarRechazar(s),
                  ),
                ),
              ]),
            ],
            if (widget.role == AppRole.barber && esSugerida) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () => _responder(s, true),
                    child: const Text('Aceptar propuesta'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                    onPressed: () => _responder(s, false),
                    child: const Text('Rechazar propuesta'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _aprobar(SolicitudCambioHorario s) async {
    if (_currentUserId == null) return;
    try {
      await _service.aprobar(s.id!, _currentUserId!);
      AppToast.showSuccess(context, 'Solicitud aprobada');
      _cargar();
    } catch (e) {
      AppToast.showError(context, limpiarError(e));
    }
  }

  Future<void> _mostrarRechazar(SolicitudCambioHorario s) async {
    final obsCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Rechazar solicitud', style: TextStyle(color: AppColors.white)),
        content: TextField(
          controller: obsCtrl,
          style: const TextStyle(color: AppColors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observación (opcional)',
            labelStyle: TextStyle(color: AppColors.grey),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.rechazar(s.id!, _currentUserId!, observacion: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim());
                AppToast.showSuccess(context, 'Solicitud rechazada');
                _cargar();
              } catch (e) {
                AppToast.showError(context, limpiarError(e));
              }
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
  }

  Future<void> _responder(SolicitudCambioHorario s, bool acepta) async {
    try {
      await _service.responder(s.id!, acepta);
      AppToast.showSuccess(context, acepta ? 'Propuesta aceptada' : 'Propuesta rechazada');
      _cargar();
    } catch (e) {
      AppToast.showError(context, limpiarError(e));
    }
  }

  Future<void> _mostrarFormNueva() async {
    if (_miBarberoPerfil == null) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _NuevaSolicitudForm(
        barberoId: _miBarberoPerfil!.id!,
        onCreated: () { Navigator.pop(ctx); _cargar(); },
      ),
    );
  }
}

// ─── FORMULARIO NUEVA SOLICITUD ────────────────────────────────────────────────
class _NuevaSolicitudForm extends StatefulWidget {
  final int barberoId;
  final VoidCallback onCreated;
  const _NuevaSolicitudForm({required this.barberoId, required this.onCreated});

  @override
  State<_NuevaSolicitudForm> createState() => _NuevaSolicitudFormState();
}

class _NuevaSolicitudFormState extends State<_NuevaSolicitudForm> {
  final _service = SolicitudCambioHorarioService();
  final _detalleCtrl = TextEditingController();
  String _motivoCategoria = 'Enfermedad';
  DateTime _fechaReferencia = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;

  final _motivos = ['Enfermedad', 'VacacionesPersonal', 'Emergencia', 'CambioTurno', 'Otro'];

  Future<void> _pickFecha() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fechaReferencia,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _fechaReferencia = d);
  }

  Future<void> _pickHora(bool esInicio) async {
    final t = await showTimePicker(
      context: context,
      initialTime: esInicio ? _horaInicio : _horaFin,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: Colors.black, surface: AppColors.card, onSurface: AppColors.white),
          ),
          child: child!,
        ),
      ),
    );
    if (t != null) setState(() { if (esInicio) _horaInicio = t; else _horaFin = t; });
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _guardar() async {
    final startMin = _horaInicio.hour * 60 + _horaInicio.minute;
    final endMin = _horaFin.hour * 60 + _horaFin.minute;
    if (startMin >= endMin) {
      AppToast.showError(context, 'Hora inicio debe ser anterior a hora fin');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.crearSolicitud(
        barberoId: widget.barberoId,
        motivoCategoria: _motivoCategoria,
        motivoDetalle: _detalleCtrl.text.trim().isEmpty ? null : _detalleCtrl.text.trim(),
        fechaReferencia: _fechaReferencia,
        sugerencias: [
          SugerenciaHorario(
            diaSugerido: _fechaReferencia,
            horaInicio: _fmt(_horaInicio),
            horaFin: _fmt(_horaFin),
            origen: 'Barbero',
          ),
        ],
      );
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.showError(context, limpiarError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nueva Solicitud de Cambio', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            const Text('Motivo', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _motivoCategoria,
              dropdownColor: AppColors.card,
              style: const TextStyle(color: AppColors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.inputBorder)),
              ),
              items: _motivos.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => setState(() => _motivoCategoria = v!),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _detalleCtrl,
              style: const TextStyle(color: AppColors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Detalle (opcional)',
                labelStyle: const TextStyle(color: AppColors.grey),
                filled: true,
                fillColor: AppColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Fecha Referencia', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickFecha,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.calendar_today, color: AppColors.gold, size: 18),
                  const SizedBox(width: 10),
                  Text('${_fechaReferencia.day}/${_fechaReferencia.month}/${_fechaReferencia.year}',
                      style: const TextStyle(color: AppColors.white)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Horario Sugerido', style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => _pickHora(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.inputBorder)),
                  child: Column(children: [
                    const Icon(Icons.access_time, color: AppColors.gold, size: 22),
                    const SizedBox(height: 4),
                    const Text('Inicio', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                    Text(AppFormat.to12h(_fmt(_horaInicio)), style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => _pickHora(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.inputBorder)),
                  child: Column(children: [
                    const Icon(Icons.access_time_filled, color: Colors.orangeAccent, size: 22),
                    const SizedBox(height: 4),
                    const Text('Fin', style: TextStyle(color: AppColors.grey, fontSize: 11)),
                    Text(AppFormat.to12h(_fmt(_horaFin)), style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ]),
                ),
              )),
            ]),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _guardar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: AppColors.bg, strokeWidth: 2))
                  : const Text('ENVIAR SOLICITUD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }
}
