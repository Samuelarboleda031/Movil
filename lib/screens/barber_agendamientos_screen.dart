import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/agendamiento.dart';
import '../models/barbero.dart';
import '../services/agendamiento_service.dart';
import '../services/auxiliar_service.dart';
import '../services/emailjs_service.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../utils/estado_cita.dart';
import '../widgets/session_guard.dart';
import 'barber_agendamiento_form_screen.dart';

class BarberAgendamientosScreen extends StatefulWidget {
  const BarberAgendamientosScreen({super.key});

  @override
  State<BarberAgendamientosScreen> createState() => _BarberAgendamientosScreenState();
}

class _BarberAgendamientosScreenState extends State<BarberAgendamientosScreen> {
  final AgendamientoService _agendamientoService = AgendamientoService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();
  final EmailJsService _emailJsService = EmailJsService();

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

      final todos = await _agendamientoService.obtenerAgendamientos();
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
    final DateTime hoy = DateTime.now();
    final List<DateTime> proximosDias = List.generate(14, (i) => hoy.add(Duration(days: i)));
    final List<DateTime> seleccionados = [];

    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('MIS DÍAS LIBRES'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: proximosDias.length,
                  itemBuilder: (context, index) {
                    final dia = proximosDias[index];
                    final dateStr = DateFormat('EEEE, d MMMM', 'es_ES').format(dia);
                    final isSelected = seleccionados.contains(dia);

                    return CheckboxListTile(
                      title: Text(dateStr),
                      value: isSelected,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) seleccionados.add(dia);
                          else seleccionados.remove(dia);
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
                ElevatedButton(
                  onPressed: seleccionados.isEmpty ? null : () => Navigator.pop(context, seleccionados),
                  child: const Text('CONFIRMAR'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null || result.isEmpty) return;
    final List<String> fechasStr = result.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
    final citasACancelar = _agendamientos.where((a) => fechasStr.any((f) => a.fechaCita?.contains(f) ?? false) && a.estadoCita != EstadoCita.cancelada).toList();

    if (citasACancelar.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin citas esos días.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CANCELAR MIS DÍAS'),
        content: Text('¿Deseas cancelar tus ${citasACancelar.length} citas de estos días?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('NO')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.orange), child: const Text('SÍ')),
        ],
      ),
    );

    if (confirm != true) return;
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      for (var ag in citasACancelar) {
        await _agendamientoService.actualizarAgendamiento(ag.copyWith(estadoCita: EstadoCita.cancelada));
        if (ag.cliente?.email != null) {
          await _emailJsService.notificarCancelacion(
              clienteNombre: ag.cliente!.nombreCompleto,
              clienteEmail: ag.cliente!.email!,
              barberoNombre: ag.barbero?.nombreCompleto ?? 'Tu barbero',
              fechaOriginal: '${ag.fechaCita}T${ag.horaInicio}',
              motivo: 'Compromiso imprevisto del barbero.');
        }
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Días cancelados y correos enviados.')));
        _cargarAgendamientosBarbero();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                decoration: InputDecoration(hintText: 'Buscar...', prefixIcon: const Icon(Icons.search)),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _agendamientosFiltrados.isEmpty
                      ? Center(child: Text('No hay citas'))
                      : ListView.builder(
                          itemCount: _agendamientosFiltrados.length,
                          itemBuilder: (context, index) {
                            final ag = _agendamientosFiltrados[index];
                            return ListTile(
                              title: Text(ag.servicio?.nombre ?? 'Cita'),
                              subtitle: Text('Cliente: ${ag.cliente?.nombreCompleto}\nFecha: ${ag.fechaCita}'),
                              trailing: IconButton(
                                icon: Icon(Icons.cancel, color: Colors.orange),
                                onPressed: () {
                                  // Reutilizar lógica individual si se desea
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const BarberAgendamientoFormScreen())).then((_) => _cargarAgendamientosBarbero()),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
