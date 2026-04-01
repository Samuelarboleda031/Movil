import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/estado_cita.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
// import 'barber_agendamiento_form_screen.dart'; // No longer needed


class BarberAgendamientosScreen extends StatefulWidget {
  const BarberAgendamientosScreen({super.key});

  @override
  State<BarberAgendamientosScreen> createState() => _BarberAgendamientosScreenState();
}

class _BarberAgendamientosScreenState extends State<BarberAgendamientosScreen> {
  final AgendamientoService _agendamientoService = AgendamientoService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();

  List<Agendamiento> _agendamientos = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filtroEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    _cargarAgendamientosBarbero();
  }

  Future<void> _cargarAgendamientosBarbero() async {
    setState(() => _isLoading = true);
    try {
      final user = _authService.currentUser;
      if (user == null || user.email == null) throw Exception('No identificado');

      final barberos = await _auxiliarService.obtenerBarberos();
      final barbero = barberos.firstWhere(
        (b) => (b.email ?? '').toLowerCase() == user.email!.toLowerCase(),
        orElse: () => Barbero(id: 0, documento: '', nombre: 'Barbero', apellido: '', telefono: '', email: user.email, direccion: '', estado: true),
      );

      final paginacion = await _agendamientoService.obtenerAgendamientos(page: 1, pageSize: 2000);
      final todos = paginacion.items;
      final propios = todos.where((a) => a.barberoId == barbero.id || (a.barbero?.email?.toLowerCase() == barbero.email?.toLowerCase())).toList();

      setState(() {
        _agendamientos = propios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Agendamiento> get _agendamientosFiltrados {
    var filtrados = _agendamientos;
    if (_filtroEstado != 'Todos') filtrados = filtrados.where((a) => a.estadoCita == _filtroEstado).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtrados = filtrados.where((a) => (a.cliente?.nombreCompleto.toLowerCase().contains(q) ?? false) || (a.servicio?.nombre.toLowerCase().contains(q) ?? false)).toList();
    }
    return filtrados;
  }

  Future<void> _cancelarMiDiaCompleto() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return _BarberDaySelectorDialog();
      },
    );

    if (result == null || result['fechas'] == null || (result['fechas'] as List).isEmpty) return;
    final List<String> fechasStr = (result['fechas'] as List).map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final String motivoStr = result['motivo']?.trim() ?? '';
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('CANCELAR DÍAS', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas cancelar todas tus citas de los ${fechasStr.length} días seleccionados?\n\nEsta acción no se puede deshacer.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.orange), 
            child: const Text('SÍ, CANCELAR'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final user = await _authService.getCurrentUser();
    final barberos = await _auxiliarService.obtenerBarberos();
    final barbero = barberos.firstWhere(
      (b) => (b.email ?? '').toLowerCase() == (user?.correo ?? '').toLowerCase(),
      orElse: () => Barbero(id: 0, documento: '', nombre: '', apellido: ''),
    );

    if (barbero.id == 0 || user?.id == null) {
      if (mounted) AppToast.showError(context, 'No se pudo identificar tu perfil de barbero.');
      return;
    }

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      int diasCanceladosCount = 0;
      for (var fecha in fechasStr) {
        await _agendamientoService.cancelarDiaBarbero(
          barberoId: barbero.id!,
          fecha: fecha,
          usuarioSolicitanteId: user!.id!,
          motivo: motivoStr.isNotEmpty ? motivoStr : 'Día libre del barbero (Cancelado desde App Móvil)',
        );
        diasCanceladosCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        AppToast.showSuccess(context, '$diasCanceladosCount día(s) cancelado(s) exitosamente.');
        _cargarAgendamientosBarbero();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        AppToast.showError(context, 'Error al cancelar día: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.barber,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mis Citas'),
          actions: [
            IconButton(icon: const Icon(Icons.event_busy, color: Colors.orange), tooltip: 'Cancelar días', onPressed: _cancelarMiDiaCompleto),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar citas...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _agendamientosFiltrados.isEmpty
                      ? const Center(child: Text('No hay citas'))
                      : RefreshIndicator(
                          onRefresh: _cargarAgendamientosBarbero,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _agendamientosFiltrados.length,
                            itemBuilder: (context, index) {
                              final ag = _agendamientosFiltrados[index];
                              return _buildAgendamientoCard(ag);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendamientoCard(Agendamiento ag) {
    final estado = ag.estadoCita ?? 'Pendiente';
    final isCancelada = estado.toLowerCase() == 'cancelada';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isCancelada ? Colors.red.withOpacity(0.1) : const Color(0xFFD8B081).withOpacity(0.1),
          child: Icon(
            isCancelada ? Icons.close : Icons.calendar_today,
            color: isCancelada ? Colors.red : const Color(0xFFD8B081),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                ag.cliente?.nombreCompleto ?? 'Cita #${ag.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _buildBadge(estado),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.content_cut, size: 14, color: Color(0xFFD8B081)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    ag.servicio?.nombre ?? (ag.paquete?.nombre ?? 'Servicio múltiple'),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  '${ag.fechaCita} | ${ag.horaInicio}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _verDetallesCita(ag),
        trailing: PopupMenuButton(
          onSelected: (val) {
            if (val == 'details') _verDetallesCita(ag);
            if (val == 'status') _cambiarEstado(ag);
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'details', child: Text('Detalles')),
            const PopupMenuItem(value: 'status', child: Text('Cambiar Estado')),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Agendamiento ag) async {
    final estados = ['Pendiente', 'Confirmado', 'En Proceso', 'Finalizado', 'No Asistio', 'Cancelado'];
    
    final nuevoEstado = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cambiar Estado'),
        children: estados.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, e),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(e, style: TextStyle(
              color: ag.estadoCita == e ? const Color(0xFFD8B081) : Colors.white,
            )),
          ),
        )).toList(),
      ),
    );

    if (nuevoEstado != null && nuevoEstado != ag.estadoCita && mounted) {
      try {
        final updated = ag.copyWith(estadoCita: nuevoEstado);
        await _agendamientoService.actualizarAgendamiento(updated);
        AppToast.showSuccess(context, 'Estado actualizado');
        _cargarAgendamientosBarbero();
      } catch (e) {
        AppToast.showError(context, 'Error: $e');
      }
    }
  }


  Widget _buildBadge(String texto) {
    final color = EstadoCita.getColor(texto);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _verDetallesCita(Agendamiento ag) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Detalles de la Cita'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('Cliente:', ag.cliente?.nombreCompleto ?? 'N/A'),
            _detailRow('Servicio/Paquete:', ag.servicio?.nombre ?? ag.paquete?.nombre ?? 'N/A'),
            _detailRow('Fecha:', ag.fechaCita ?? 'N/A'),
            _detailRow('Hora:', '${ag.horaInicio} - ${ag.horaFin}'),
            _detailRow('Monto:', '\$${(ag.monto ?? 0).toStringAsFixed(2)}'),
            _detailRow('Estado:', ag.estadoCita ?? 'Pendiente'),
            const Divider(),
            const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(ag.observaciones ?? 'Sin observaciones'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        ],

      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _BarberDaySelectorDialog extends StatefulWidget {
  @override
  State<_BarberDaySelectorDialog> createState() => __BarberDaySelectorDialogState();
}

class __BarberDaySelectorDialogState extends State<_BarberDaySelectorDialog> {
  String _selectedWeek = 'Semana actual';
  final List<DateTime> _selectedDates = [];
  final TextEditingController _motivoController = TextEditingController();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }
  
  List<DateTime> _getWeekDays(String weekType) {
    DateTime now = DateTime.now();
    // Monday of current week
    DateTime monday = now.subtract(Duration(days: now.weekday - 1));
    if (weekType == 'Siguiente semana') {
      monday = monday.add(const Duration(days: 7));
    }
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final weekDays = _getWeekDays(_selectedWeek);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return AlertDialog(
      backgroundColor: const Color(0xFF161616),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD8B081), width: 0.5)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selecciona los días:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD8B081), width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedWeek,
                dropdownColor: const Color(0xFF1E1E1E),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD8B081)),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: ['Semana actual', 'Siguiente semana'].map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedWeek = val);
                },
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weekDays.map((date) {
                final isPast = date.isBefore(today);
                final isSelected = _selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
                final name = DateFormat('EEEE', 'es_ES').format(date);
                final capitalized = name[0].toUpperCase() + name.substring(1);

                return FilterChip(
                  label: Text(capitalized),
                  selected: isSelected,
                  onSelected: isPast ? null : (val) {
                    setState(() {
                      if (val) {
                        _selectedDates.add(date);
                      } else {
                        _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
                      }
                    });
                  },
                  backgroundColor: const Color(0xFF2A2A2A),
                  selectedColor: const Color(0xFFD8B081),
                  labelStyle: TextStyle(
                    color: isPast ? Colors.white24 : (isSelected ? Colors.black : Colors.white70),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  checkmarkColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Text(
              '* Semana: ${_selectedWeek.split(' ')[1]}. Solo se pueden seleccionar el día de hoy y días futuros.',
              style: const TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _motivoController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Motivo (opcional)...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD8B081), width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _selectedDates.isEmpty 
              ? null 
              : () => Navigator.pop(context, {'fechas': _selectedDates, 'motivo': _motivoController.text}),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD8B081),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('CONFIRMAR'),
        ),
      ],
    );
  }
}
