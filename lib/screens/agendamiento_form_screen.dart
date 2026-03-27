import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/agendamiento.dart';
import '../models/cliente.dart';
import '../models/barbero.dart';
import '../models/servicio.dart';
import '../models/paquete.dart';
import '../services/agendamiento_service.dart';
import '../services/auxiliar_service.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../config/api_config.dart';
import '../widgets/session_guard.dart';
import '../widgets/searchable_selector.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Convierte "HH:mm" a minutos totales desde medianoche
int _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// Convierte minutos totales a "HH:mm"
String _fromMinutes(int totalMin) {
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// Formatea "HH:mm" a "h:mm AM/PM"
String _toAmPm(String hhmm) {
  final parts = hhmm.split(':');
  int h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final period = h >= 12 ? 'PM' : 'AM';
  if (h == 0) h = 12;
  if (h > 12) h -= 12;
  return '${h}:${m.toString().padLeft(2, '0')} $period';
}

// ─── Modelo mínimo de horario ─────────────────────────────────────────────────
class _HorarioBarbero {
  final int barberoId;
  final int diaSemana; // 0=Lunes … 6=Domingo (o 1=Lunes según API)
  final String horaInicio; // HH:mm
  final String horaFin;    // HH:mm
  final bool estado;

  _HorarioBarbero({
    required this.barberoId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
  });

  factory _HorarioBarbero.fromJson(Map<String, dynamic> j) {
    // Day of week puede venir como int (0-6) o como nombre de día en español
    int dia = 0;
    final rawDia = j['diaSemana'] ?? j['DiaSemana'] ?? j['dia'] ?? j['Dia'];
    if (rawDia is int) {
      dia = rawDia;
    } else if (rawDia is String) {
      const nombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      dia = nombres.indexOf(rawDia);
      if (dia < 0) dia = 0;
    }

    String parseHora(dynamic val) {
      if (val == null) return '09:00';
      final s = val.toString();
      // formato "HH:mm:ss" → tomar solo primeros 5 chars
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return _HorarioBarbero(
      barberoId: j['barberoId'] ?? j['BarberoId'] ?? 0,
      diaSemana: dia,
      horaInicio: parseHora(j['horaInicio'] ?? j['HoraInicio']),
      horaFin: parseHora(j['horaFin'] ?? j['HoraFin']),
      estado: j['estado'] ?? j['Estado'] ?? true,
    );
  }
}

// ─── Widget Principal ─────────────────────────────────────────────────────────
class AgendamientoFormScreen extends StatefulWidget {
  final Agendamiento? agendamiento;
  const AgendamientoFormScreen({super.key, this.agendamiento});

  @override
  State<AgendamientoFormScreen> createState() => _AgendamientoFormScreenState();
}

class _AgendamientoFormScreenState extends State<AgendamientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AgendamientoService _agendamientoService = AgendamientoService();
  final AuxiliarService _auxiliarService = AuxiliarService();
  final AuthService _authService = AuthService();

  // Datos base
  List<Cliente> _clientes = [];
  List<Barbero> _barberos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];
  List<_HorarioBarbero> _todosLosHorarios = [];

  // Selecciones
  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  Servicio? _servicioSeleccionado;
  Paquete? _paqueteSeleccionado;
  bool _esServicio = true;

  // Fecha y hora
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  String? _horaInicioSeleccionada; // "HH:mm"
  String? _horaFinSeleccionada;    // "HH:mm"

  // Slots disponibles calculados según horario del barbero
  List<String> _slotsDisponibles = [];

  // Otros campos
  String _estadoCita = 'Pendiente';
  double? _monto;
  String? _observaciones;

  bool _isLoading = false;
  bool _isLoadingData = true;

  // ── Cycle AM/PM ──────────────────────────────────────────────────────────────
  final List<String> _estadosCita = ['Pendiente', 'Confirmada', 'En Proceso', 'Completada', 'Cancelada'];

  @override
  void initState() {
    super.initState();
    _cargarDatos().then((_) {
      if (widget.agendamiento != null && mounted) {
        _rellenarFormulario(widget.agendamiento!);
      }
    });
  }

  // ─── Carga de datos ───────────────────────────────────────────────────────
  Future<void> _cargarDatos() async {
    try {
      final token = await _authService.getToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final results = await Future.wait([
        _auxiliarService.obtenerClientes(),
        _auxiliarService.obtenerBarberos(),
        _auxiliarService.obtenerServicios(),
        _auxiliarService.obtenerPaquetes(),
        _fetchHorarios(headers),
      ]);

      if (!mounted) return;
      setState(() {
        _clientes = results[0] as List<Cliente>;
        _barberos = results[1] as List<Barbero>;
        _servicios = results[2] as List<Servicio>;
        _paquetes = results[3] as List<Paquete>;
        _todosLosHorarios = results[4] as List<_HorarioBarbero>;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _mostrarError('Error al cargar datos: $e');
    }
  }

  Future<List<_HorarioBarbero>> _fetchHorarios(Map<String, String> headers) async {
    try {
      final resp = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/HorariosBarberos?pageSize=1000'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) {
        final raw = jsonDecode(resp.body);
        List<dynamic> lista;
        if (raw is List) {
          lista = raw;
        } else if (raw is Map && raw.containsKey('items')) {
          lista = raw['items'];
        } else if (raw is Map && raw.containsKey('data')) {
          lista = raw['data'];
        } else {
          lista = [];
        }
        return lista
            .map((j) => _HorarioBarbero.fromJson(j as Map<String, dynamic>))
            .where((h) => h.estado)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ─── Rellenar si edit ─────────────────────────────────────────────────────
  void _rellenarFormulario(Agendamiento a) {
    setState(() {
      _clienteSeleccionado = _clientes.firstWhere(
        (c) => c.id == a.clienteId,
        orElse: () => a.cliente!,
      );
      _barberoSeleccionado = _barberos.firstWhere(
        (b) => b.id == a.barberoId,
        orElse: () => a.barbero!,
      );
      if (a.servicioId != null) {
        _servicioSeleccionado = _servicios.firstWhere(
          (s) => s.id == a.servicioId,
          orElse: () => a.servicio!,
        );
        _esServicio = true;
      }
      if (a.paqueteId != null) {
        _paqueteSeleccionado = _paquetes.firstWhere(
          (p) => p.id == a.paqueteId,
          orElse: () => a.paquete!,
        );
        _esServicio = false;
      }
      if (a.fechaCita != null && a.fechaCita!.isNotEmpty) {
        _fechaSeleccionada = DateTime.tryParse(a.fechaCita!) ?? _fechaSeleccionada;
      }
      _horaInicioSeleccionada = a.horaInicio?.isNotEmpty == true ? a.horaInicio : null;
      _horaFinSeleccionada = a.horaFin?.isNotEmpty == true ? a.horaFin : null;
      _estadoCita = a.estadoCita ?? 'Pendiente';
      _monto = a.monto ?? a.precio;
    });
    _recalcularSlots();
  }

  // ─── Cálculo de slots disponibles ─────────────────────────────────────────
  void _recalcularSlots() {
    if (_barberoSeleccionado == null) {
      setState(() => _slotsDisponibles = []);
      return;
    }

    // día de semana: Dart usa 1=Lunes…7=Domingo, API puede usar 0=Lunes…6=Domingo
    // probamos ambas convenciones
    final dartDow = _fechaSeleccionada.weekday; // 1–7
    final apiDow = dartDow - 1; // 0–6 (0=Lunes)

    final horariosBarbero = _todosLosHorarios.where((h) {
      if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
      // aceptar tanto 0-indexed como 1-indexed
      return h.diaSemana == apiDow || h.diaSemana == dartDow;
    }).toList();

    if (horariosBarbero.isEmpty) {
      setState(() {
        _slotsDisponibles = [];
        _horaInicioSeleccionada = null;
        _horaFinSeleccionada = null;
      });
      return;
    }

    // Duración estimada del servicio/paquete seleccionado (en minutos)
    int durMin = 30;
    if (_esServicio && _servicioSeleccionado != null) {
      durMin = _servicioSeleccionado!.duracionMinutos > 0
          ? _servicioSeleccionado!.duracionMinutos
          : 30;
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }

    final slots = <String>[];
    for (final h in horariosBarbero) {
      int cursor = _toMinutes(h.horaInicio);
      final end = _toMinutes(h.horaFin);
      while (cursor + durMin <= end) {
        slots.add(_fromMinutes(cursor));
        cursor += 30; // intervalos de 30 min
      }
    }

    // Ordenar y deduplicar
    final unique = slots.toSet().toList()..sort();

    setState(() {
      _slotsDisponibles = unique;
      // Si la hora seleccionada ya no está en los nuevos slots, limpiar
      if (_horaInicioSeleccionada != null && !unique.contains(_horaInicioSeleccionada)) {
        _horaInicioSeleccionada = null;
        _horaFinSeleccionada = null;
      }
    });
  }

  /// Al seleccionar un slot de inicio, calcular fin automáticamente
  void _seleccionarSlot(String slot) {
    int durMin = 30;
    if (_esServicio && _servicioSeleccionado != null) {
      durMin = _servicioSeleccionado!.duracionMinutos > 0
          ? _servicioSeleccionado!.duracionMinutos
          : 30;
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    final finMin = _toMinutes(slot) + durMin;
    setState(() {
      _horaInicioSeleccionada = slot;
      _horaFinSeleccionada = _fromMinutes(finMin);
    });
  }

  // ─── Selector de fecha ────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFD8B081),
            onPrimary: Colors.black,
            surface: const Color(0xFF1E1E1E),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fechaSeleccionada = picked;
        _horaInicioSeleccionada = null;
        _horaFinSeleccionada = null;
      });
      _recalcularSlots();
    }
  }

  // ─── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardarAgendamiento() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clienteSeleccionado == null) {
      _mostrarError('Por favor seleccione un cliente');
      return;
    }
    if (_barberoSeleccionado == null) {
      _mostrarError('Por favor seleccione un barbero');
      return;
    }
    if (_esServicio && _servicioSeleccionado == null) {
      _mostrarError('Por favor seleccione un servicio');
      return;
    }
    if (!_esServicio && _paqueteSeleccionado == null) {
      _mostrarError('Por favor seleccione un paquete');
      return;
    }
    if (_horaInicioSeleccionada == null) {
      _mostrarError('Por favor seleccione una hora disponible');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final agendamiento = Agendamiento(
        id: widget.agendamiento?.id,
        clienteId: _clienteSeleccionado!.id!,
        barberoId: _barberoSeleccionado!.id!,
        servicioId: _esServicio ? _servicioSeleccionado!.id : null,
        paqueteId: !_esServicio ? _paqueteSeleccionado!.id : null,
        fechaCita: DateFormat('yyyy-MM-dd').format(_fechaSeleccionada),
        horaInicio: _horaInicioSeleccionada,
        horaFin: _horaFinSeleccionada,
        estadoCita: _estadoCita,
        monto: _monto,
        observaciones: _observaciones,
      );

      if (widget.agendamiento == null) {
        await _agendamientoService.crearAgendamiento(agendamiento);
      } else {
        await _agendamientoService.actualizarAgendamiento(agendamiento);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.agendamiento == null
              ? '✅ Agendamiento creado exitosamente'
              : '✅ Agendamiento actualizado exitosamente'),
          backgroundColor: Colors.green.shade700,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  // ─── Nombre día en español ─────────────────────────────────────────────────
  String _nombreDia(DateTime d) {
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return dias[d.weekday - 1];
  }

  // ─── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        appBar: AppBar(
          title: Text(
            widget.agendamiento == null ? 'Nuevo Agendamiento' : 'Editar Agendamiento',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF3E1F00),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8B081)))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Tipo ───────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.cut,
                        title: 'Tipo de Cita',
                        child: SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(
                              value: true,
                              label: Text('Servicio'),
                              icon: Icon(Icons.cut),
                            ),
                            ButtonSegment(
                              value: false,
                              label: Text('Paquete'),
                              icon: Icon(Icons.inventory_2),
                            ),
                          ],
                          selected: {_esServicio},
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(0xFFD8B081);
                              }
                              return const Color(0xFF2A2A2A);
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) return Colors.black;
                              return Colors.white70;
                            }),
                          ),
                          onSelectionChanged: (s) {
                            setState(() {
                              _esServicio = s.first;
                              _servicioSeleccionado = null;
                              _paqueteSeleccionado = null;
                              _monto = null;
                            });
                            _recalcularSlots();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Cliente ────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.person,
                        title: 'Cliente *',
                        child: SearchableSelector<Cliente>(
                          label: 'Cliente *',
                          hint: 'Escribe nombre o documento...',
                          items: _clientes,
                          selectedItem: _clienteSeleccionado,
                          displayText: (c) => c.nombreCompleto,
                          searchText: (c) => '${c.nombreCompleto} ${c.documento}',
                          prefixIcon: Icons.person_search,
                          required: true,
                          renderItem: (c) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.nombreCompleto,
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                              Text(c.documento,
                                  style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                          onSelected: (c) => setState(() => _clienteSeleccionado = c),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Barbero ────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.badge,
                        title: 'Barbero *',
                        child: SearchableSelector<Barbero>(
                          label: 'Barbero *',
                          hint: 'Escribe el nombre del barbero...',
                          items: _barberos,
                          selectedItem: _barberoSeleccionado,
                          displayText: (b) => b.nombreCompleto,
                          searchText: (b) => '${b.nombreCompleto} ${b.documento}',
                          prefixIcon: Icons.badge,
                          required: true,
                          onSelected: (b) {
                            setState(() {
                              _barberoSeleccionado = b;
                              _horaInicioSeleccionada = null;
                              _horaFinSeleccionada = null;
                            });
                            _recalcularSlots();
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Servicio / Paquete ────────────────────────────────
                      _sectionCard(
                        icon: _esServicio ? Icons.cut : Icons.inventory_2,
                        title: _esServicio ? 'Servicio *' : 'Paquete *',
                        child: _esServicio
                            ? SearchableSelector<Servicio>(
                                label: 'Servicio *',
                                hint: 'Escribe el nombre del servicio...',
                                items: _servicios,
                                selectedItem: _servicioSeleccionado,
                                displayText: (s) => s.nombre,
                                searchText: (s) => s.nombre,
                                prefixIcon: Icons.cut,
                                required: true,
                                renderItem: (s) => Row(
                                  children: [
                                    Expanded(
                                      child: Text(s.nombre,
                                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    ),
                                    Text(
                                      '\$${s.precio.toStringAsFixed(0)} · ${s.duracionMinutos}min',
                                      style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12),
                                    ),
                                  ],
                                ),
                                onSelected: (s) {
                                  setState(() {
                                    _servicioSeleccionado = s;
                                    _monto = s?.precio;
                                    _paqueteSeleccionado = null;
                                    _horaInicioSeleccionada = null;
                                    _horaFinSeleccionada = null;
                                  });
                                  _recalcularSlots();
                                },
                              )
                            : SearchableSelector<Paquete>(
                                label: 'Paquete *',
                                hint: 'Escribe el nombre del paquete...',
                                items: _paquetes,
                                selectedItem: _paqueteSeleccionado,
                                displayText: (p) => p.nombre,
                                searchText: (p) => p.nombre,
                                prefixIcon: Icons.inventory_2,
                                required: true,
                                renderItem: (p) => Row(
                                  children: [
                                    Expanded(
                                      child: Text(p.nombre,
                                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                                    ),
                                    Text(
                                      '\$${p.precio.toStringAsFixed(0)} · ${p.duracionMinutos}min',
                                      style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12),
                                    ),
                                  ],
                                ),
                                onSelected: (p) {
                                  setState(() {
                                    _paqueteSeleccionado = p;
                                    _monto = p?.precio;
                                    _servicioSeleccionado = null;
                                    _horaInicioSeleccionada = null;
                                    _horaFinSeleccionada = null;
                                  });
                                  _recalcularSlots();
                                },
                              ),
                      ),
                      const SizedBox(height: 12),

                      // ── Fecha ──────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.calendar_today,
                        title: 'Fecha de Cita *',
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF3A3A3A)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month,
                                    color: Color(0xFFD8B081), size: 20),
                                const SizedBox(width: 10),
                                Text(
                                  '${_nombreDia(_fechaSeleccionada)}, ${DateFormat('dd/MM/yyyy').format(_fechaSeleccionada)}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 15),
                                ),
                                const Spacer(),
                                const Icon(Icons.edit_calendar,
                                    color: Colors.white38, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Slots de Hora ─────────────────────────────────────
                      _sectionCard(
                        icon: Icons.schedule,
                        title: 'Hora Disponible *',
                        child: _buildSlotsHora(),
                      ),
                      const SizedBox(height: 12),

                      // ── Hora fin (informativa) ────────────────────────────
                      if (_horaInicioSeleccionada != null)
                        _sectionCard(
                          icon: Icons.timelapse,
                          title: 'Resumen de la cita',
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A2A1A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.green.shade800),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceAround,
                              children: [
                                _timeChip(
                                    'INICIO',
                                    _toAmPm(_horaInicioSeleccionada!),
                                    Colors.green),
                                const Icon(Icons.arrow_forward,
                                    color: Colors.white38),
                                _timeChip(
                                    'FIN',
                                    _horaFinSeleccionada != null
                                        ? _toAmPm(_horaFinSeleccionada!)
                                        : '—',
                                    Colors.orange),
                              ],
                            ),
                          ),
                        ),
                      if (_horaInicioSeleccionada != null)
                        const SizedBox(height: 12),

                      // ── Estado ─────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.flag,
                        title: 'Estado de Cita',
                        child: DropdownButtonFormField<String>(
                          value: _estadoCita,
                          dropdownColor: const Color(0xFF1E1E1E),
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Estado'),
                          items: _estadosCita
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e,
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (e) =>
                              setState(() => _estadoCita = e!),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Monto ─────────────────────────────────────────────
                      _sectionCard(
                        icon: Icons.attach_money,
                        title: 'Monto',
                        child: TextFormField(
                          initialValue: _monto?.toStringAsFixed(0) ?? '',
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Precio de la cita'),
                          onChanged: (v) => _monto = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── Observaciones ────────────────────────────────────
                      _sectionCard(
                        icon: Icons.notes,
                        title: 'Observaciones',
                        child: TextFormField(
                          initialValue: _observaciones,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecor('Notas adicionales (opcional)'),
                          onChanged: (v) => _observaciones = v,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Botón guardar ─────────────────────────────────────
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _guardarAgendamiento,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD8B081),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Text(
                                  widget.agendamiento == null
                                      ? 'Crear Agendamiento'
                                      : 'Actualizar Agendamiento',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Selector de slots de hora ─────────────────────────────────────────────
  Widget _buildSlotsHora() {
    if (_barberoSeleccionado == null) {
      return _infoBox(
        Icons.info_outline,
        'Selecciona un barbero primero para ver los horarios disponibles.',
        Colors.blue,
      );
    }

    if (_slotsDisponibles.isEmpty) {
      final dia = _nombreDia(_fechaSeleccionada);
      return _infoBox(
        Icons.event_busy,
        'El barbero no tiene horario disponible el $dia. Prueba con otra fecha.',
        Colors.orange,
      );
    }

    // Dividir slots en AM y PM
    final slotsAm =
        _slotsDisponibles.where((s) => _toMinutes(s) < 720).toList();
    final slotsPm =
        _slotsDisponibles.where((s) => _toMinutes(s) >= 720).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (slotsAm.isNotEmpty) ...[
          _slotGroupLabel('AM — Mañana'),
          const SizedBox(height: 6),
          _slotGrid(slotsAm),
          const SizedBox(height: 12),
        ],
        if (slotsPm.isNotEmpty) ...[
          _slotGroupLabel('PM — Tarde/Noche'),
          const SizedBox(height: 6),
          _slotGrid(slotsPm),
        ],
      ],
    );
  }

  Widget _slotGroupLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFFD8B081),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _slotGrid(List<String> slots) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSelected = slot == _horaInicioSeleccionada;
        return GestureDetector(
          onTap: () => _seleccionarSlot(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD8B081)
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD8B081)
                    : const Color(0xFF3A3A3A),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD8B081).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
            child: Text(
              _toAmPm(slot),
              style: TextStyle(
                color: isSelected ? Colors.black : Colors.white,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Helpers de UI ─────────────────────────────────────────────────────────
  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E2E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 15, color: const Color(0xFFD8B081)),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFFD8B081),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ]),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF2A2A2A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: Color(0xFFD8B081), width: 1.5),
        ),
      );

  Widget _infoBox(IconData icon, String msg, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
