import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/agendamiento.dart';
import '../models/cliente.dart';
import '../models/barbero.dart';
import '../models/servicio.dart';
import '../models/paquete.dart';
import '../models/producto.dart';
import '../services/agendamiento_service.dart';
import '../services/auxiliar_service.dart';
import '../services/auth_service.dart';
import '../models/app_role.dart';
import '../config/api_config.dart';
import '../widgets/session_guard.dart';
import '../widgets/searchable_selector.dart';
import '../models/paginacion.dart';
import '../utils/app_snackbar.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

int _toMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

String _fromMinutes(int totalMin) {
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

String _toAmPm(String hhmm) {
  final parts = hhmm.split(':');
  int h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final period = h >= 12 ? 'PM' : 'AM';
  if (h == 0) h = 12;
  if (h > 12) h -= 12;
  return '${h}:${m.toString().padLeft(2, '0')} $period';
}

String _nombreDia(DateTime d) {
  const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  return dias[d.weekday - 1];
}

// ─── Modelo mínimo de horario ─────────────────────────────────────────────────
class _HorarioBarbero {
  final int barberoId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;
  final bool estado;

  _HorarioBarbero({
    required this.barberoId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
  });

  factory _HorarioBarbero.fromJson(Map<String, dynamic> j) {
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
  List<Producto> _productos = [];
  List<Agendamiento> _todasLasCitas = [];
  List<_HorarioBarbero> _todosLosHorarios = [];

  // Selecciones
  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  List<Servicio> _serviciosSeleccionados = [];
  Paquete? _paqueteSeleccionado;
  Map<int, int> _productoCantidades = {};
  bool _esServicio = true;

  // Fecha y hora
  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  String? _horaInicioSeleccionada;
  String? _horaFinSeleccionada;

  // Slots disponibles calculados
  List<String> _slotsDisponibles = [];

  // Otros campos
  String _estadoCita = 'Pendiente';
  double? _monto;
  String? _observaciones;

  bool _isLoading = false;
  bool _isLoadingData = true;
  
  final TextEditingController _montoController = TextEditingController();

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
        _auxiliarService.obtenerProductos(),
        _agendamientoService.obtenerAgendamientos(),
        _fetchHorarios(headers),
      ]);

      if (!mounted) return;
      setState(() {
        _clientes = (results[0] as List<Cliente>).where((c) => c.estado ?? true).toList();
        _barberos = (results[1] as List<Barbero>).where((b) => b.estado ?? true).toList();
        _servicios = results[2] as List<Servicio>;
        _paquetes = results[3] as List<Paquete>;
        _productos = results[4] as List<Producto>;
        _todasLasCitas = (results[5] as Paginacion<Agendamiento>).items;
        _todosLosHorarios = results[6] as List<_HorarioBarbero>;
        
        _isLoadingData = false;
      });
      _recalcularSlots();
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
  void _calcularTotal() {
    double total = 0;
    if (_esServicio) {
      for (var s in _serviciosSeleccionados) {
        total += s.precio;
      }
    } else if (_paqueteSeleccionado != null) {
      total += _paqueteSeleccionado!.precio;
    }

    _productoCantidades.forEach((pid, qty) {
      try {
        final p = _productos.firstWhere((prod) => prod.id == pid);
        total += p.precioVenta * qty;
      } catch (_) {}
    });

    setState(() {
       _monto = total;
       _montoController.text = total > 0 ? total.toStringAsFixed(0) : '';
    });
  }

  void _rellenarFormulario(Agendamiento a) {
    setState(() {
      try {
        _clienteSeleccionado = _clientes.firstWhere((c) => c.id == a.clienteId);
      } catch (_) {
        _clienteSeleccionado = a.cliente;
      }
      
      try {
        _barberoSeleccionado = _barberos.firstWhere((b) => b.id == a.barberoId);
      } catch (_) {
        _barberoSeleccionado = a.barbero;
      }

      if (a.servicioIds.isNotEmpty) {
        _serviciosSeleccionados = _servicios.where((s) => a.servicioIds.contains(s.id)).toList();
        _esServicio = true;
      } else if (a.servicioId != null) {
        try {
          final serv = _servicios.firstWhere((s) => s.id == a.servicioId);
          _serviciosSeleccionados = [serv];
          _esServicio = true;
        } catch(_) {
           if (a.servicio != null) _serviciosSeleccionados = [a.servicio!];
        }
      }
      
      if (a.productoIds.isNotEmpty) {
        _productoCantidades.clear();
        for (var pid in a.productoIds) {
           _productoCantidades[pid] = (_productoCantidades[pid] ?? 0) + 1;
        }
      }
      if (a.paqueteId != null) {
        try {
           _paqueteSeleccionado = _paquetes.firstWhere((p) => p.id == a.paqueteId);
        } catch (_) {
           _paqueteSeleccionado = a.paquete;
        }
        _esServicio = false;
      }
      if (a.fechaCita != null && a.fechaCita!.isNotEmpty) {
        _fechaSeleccionada = DateTime.tryParse(a.fechaCita!) ?? _fechaSeleccionada;
      }
      _horaInicioSeleccionada = a.horaInicio?.isNotEmpty == true ? a.horaInicio : null;
      _horaFinSeleccionada = a.horaFin?.isNotEmpty == true ? a.horaFin : null;
      _estadoCita = a.estadoCita ?? 'Pendiente';
      _monto = a.monto ?? a.precio;
      _montoController.text = _monto?.toStringAsFixed(0) ?? '';
    });
    _recalcularSlots();
  }

  // ─── Cálculo de slots disponibles ─────────────────────────────────────────
  void _recalcularSlots() {
    if (_barberoSeleccionado == null) {
      setState(() => _slotsDisponibles = []);
      return;
    }

    final dartDow = _fechaSeleccionada.weekday; 
    final apiDow = dartDow - 1; 

    final horariosBarbero = _todosLosHorarios.where((h) {
      if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
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

    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(0, (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30));
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0 ? _paqueteSeleccionado!.duracionMinutos : 60;
    }
    if (durMin == 0) durMin = 30;

    final now = DateTime.now();
    final isToday = _fechaSeleccionada.year == now.year &&
                    _fechaSeleccionada.month == now.month &&
                    _fechaSeleccionada.day == now.day;
    final currentMin = now.hour * 60 + now.minute;
    final String fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    final citasBarberoHoy = _todasLasCitas.where((c) {
      if (c.barberoId != _barberoSeleccionado!.id) return false;
      if (c.estado?.toLowerCase() == 'cancelada' || c.estadoCita?.toLowerCase() == 'cancelada') return false;
      String fCita = c.fechaCita ?? '';
      if (fCita.isEmpty && c.fechaHora != null && c.fechaHora!.contains('T')) {
          fCita = c.fechaHora!.split('T')[0];
      }
      if (fCita != fechaStr) return false;
      if (c.id != null && widget.agendamiento != null && c.id == widget.agendamiento!.id) return false;
      return true;
    }).toList();

    final slots = <String>[];
    for (final h in horariosBarbero) {
      int cursor = _toMinutes(h.horaInicio);
      final end = _toMinutes(h.horaFin);
      while (cursor + durMin <= end) {
        bool solapa = false;
        if (isToday && cursor <= currentMin + 30) {
           solapa = true;
        }
        
        if (!solapa) {
           final endCursor = cursor + durMin;
           for (final c in citasBarberoHoy) {
              if (c.horaInicio == null || c.horaInicio!.isEmpty) continue;
              int startExist = _toMinutes(c.horaInicio!);
              int endExist = 0;
              if (c.horaFin != null && c.horaFin!.isNotEmpty) {
                  endExist = _toMinutes(c.horaFin!);
              } else {
                  endExist = startExist + 60; 
              }
              if (cursor < endExist && startExist < endCursor) {
                 solapa = true;
                 break;
              }
           }
        }

        if (!solapa) {
           slots.add(_fromMinutes(cursor));
        }
        cursor += 30; 
      }
    }

    final uniqueSlots = slots.toSet().toList()..sort();
    
    setState(() {
      _slotsDisponibles = uniqueSlots;
      if (_horaInicioSeleccionada != null && !uniqueSlots.contains(_horaInicioSeleccionada)) {
        _horaInicioSeleccionada = null;
        _horaFinSeleccionada = null;
      }
    });
  }

  void _seleccionarSlot(String slot) {
    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(0, (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30));
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0 ? _paqueteSeleccionado!.duracionMinutos : 60;
    }
    if (durMin == 0) durMin = 30;
    final finMin = _toMinutes(slot) + durMin;
    setState(() {
      _horaInicioSeleccionada = slot;
      _horaFinSeleccionada = _fromMinutes(finMin);
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    super.dispose();
  }

  // ─── Selector de fecha ────────────────────────────────────────────────────
  Widget _buildDaySelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Si queremos habilitar el cambio de semana como en el diálogo de barbero:
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8B081), width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _fechaSeleccionada.isBefore(now.subtract(Duration(days: now.weekday - 1)).add(const Duration(days: 7))) ? 0 : 1,
              dropdownColor: const Color(0xFF1E1E1E),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFFD8B081)),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Semana actual', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 1, child: Text('Siguiente semana', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) {
                if (val == null) return;
                setState(() {
                  DateTime base = now.subtract(Duration(days: now.weekday - 1));
                  if (val == 1) base = base.add(const Duration(days: 7));
                  // Ajustar al mismo día de la semana pero en la nueva semana
                  _fechaSeleccionada = base.add(Duration(days: _fechaSeleccionada.weekday - 1));
                  _horaInicioSeleccionada = null;
                  _horaFinSeleccionada = null;
                });
                _recalcularSlots();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(7, (i) {
            DateTime base = now.subtract(Duration(days: now.weekday - 1));
            // Detectar en qué semana estamos actualmente
            if (!_fechaSeleccionada.isBefore(base.add(const Duration(days: 7)))) {
              base = base.add(const Duration(days: 7));
            }
            final date = base.add(Duration(days: i));
            final isPast = date.isBefore(today);
            final isSelected = _fechaSeleccionada.year == date.year && _fechaSeleccionada.month == date.month && _fechaSeleccionada.day == date.day;
            
            final name = DateFormat('EEEE', 'es_ES').format(date);
            final label = name[0].toUpperCase() + name.substring(1);

            return FilterChip(
              label: Text(label),
              selected: isSelected,
              onSelected: isPast ? null : (val) {
                if (val) {
                  setState(() {
                    _fechaSeleccionada = date;
                    _horaInicioSeleccionada = null;
                    _horaFinSeleccionada = null;
                  });
                  _recalcularSlots();
                }
              },
              backgroundColor: const Color(0xFF161616),
              selectedColor: const Color(0xFFD8B081),
              labelStyle: TextStyle(
                color: isPast ? Colors.white24 : (isSelected ? Colors.black : Colors.white70),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              checkmarkColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            );
          }),
        ),
      ],
    );
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
    if (_esServicio && _serviciosSeleccionados.isEmpty) {
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
    
    final navigator = Navigator.of(context);
    
    try {
      final agendamiento = Agendamiento(
        id: widget.agendamiento?.id,
        clienteId: _clienteSeleccionado!.id!,
        barberoId: _barberoSeleccionado!.id!,
        servicioId: _esServicio && _serviciosSeleccionados.isNotEmpty ? _serviciosSeleccionados.first.id : null,
        servicioIds: _esServicio ? _serviciosSeleccionados.map((s)=>s.id!).toList() : [],
        productoIds: _productoCantidades.entries.expand((e) => List.filled(e.value, e.key)).toList(),
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

      if (mounted) {
        _mostrarExito(widget.agendamiento == null ? '✅ Cita creada exitosamente' : '✅ Cita actualizada');
        navigator.pop(true);
      }
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarExito(String msg) {
    if (!mounted) return;
    AppToast.showSuccess(context, msg);
  }

  void _mostrarError(String msg) {
    if (!mounted) return;
    AppToast.showError(context, msg);
  }

  // ─── UI Helpers ─────────────────────────────────────────────────────────────

  Widget _buildRadioOption(String title, bool isServicioOption) {
    final isSelected = _esServicio == isServicioOption;
    return GestureDetector(
      onTap: () {
        setState(() {
          _esServicio = isServicioOption;
          _serviciosSeleccionados.clear();
          _paqueteSeleccionado = null;
          _monto = null;
          _horaInicioSeleccionada = null;
          _horaFinSeleccionada = null;
        });
        _recalcularSlots();
      },
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? const Color(0xFFD8B081) : Colors.white54,
                width: 2,
              ),
            ),
            child: isSelected
                ? Center(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFD8B081),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildGridBox({
    required String label,
    required String value,
    required IconData rightIcon,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                Icon(rightIcon, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHoraInicioPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Hora de inicio', style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              icon: const Icon(Icons.access_time, color: Colors.white, size: 20),
              value: _horaInicioSeleccionada,
              dropdownColor: const Color(0xFF1E1E1E),
              hint: const Text('Hora...', style: TextStyle(color: Colors.white38, fontSize: 16)),
              items: _slotsDisponibles.map((s) => DropdownMenuItem(
                value: s,
                child: Text(_toAmPm(s), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              )).toList(),
              onChanged: (s) {
                if (s != null) _seleccionarSlot(s);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ─── UI Principal ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: AppRole.admin,
      child: Scaffold(
        backgroundColor: const Color(0xFF000000), // Fondo negro oscuro
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.agendamiento == null ? 'Nueva Cita' : 'Editar Cita',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFD8B081)))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Barbero (Selector) ──
                      SearchableSelector<Barbero>(
                        label: 'Barbero *',
                        hint: 'Selecciona un barbero...',
                        items: _barberos.where((b) {
                          if (_todosLosHorarios.isEmpty) return true; // Si no hay horarios cargados aún, mostrar todos
                          final apiDow = _fechaSeleccionada.weekday - 1;
                          return _todosLosHorarios.any((h) => 
                            h.barberoId == b.id && 
                            h.diaSemana == apiDow && 
                            h.estado == true
                          );
                        }).toList(),
                        selectedItem: _barberoSeleccionado,
                        displayText: (b) => b.nombreCompleto,
                        searchText: (b) => b.nombreCompleto,
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
                      const SizedBox(height: 24),

                      // ── Cliente ──
                      SearchableSelector<Cliente>(
                        label: 'Cliente *',
                        hint: 'Selecciona un cliente...',
                        items: _clientes,
                        selectedItem: _clienteSeleccionado,
                        displayText: (c) => c.nombreCompleto,
                        searchText: (c) => c.nombreCompleto,
                        prefixIcon: Icons.person,
                        required: true,
                        onSelected: (c) => setState(() => _clienteSeleccionado = c),
                      ),
                      const SizedBox(height: 24),

                      // ── Tipo de Cita ──
                      const Text('Tipo de Cita', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildRadioOption('Servicio', true)),
                          Expanded(child: _buildRadioOption('Paquete', false)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Añadir Servicio / Paquete ──
                      _esServicio
                          ? SearchableSelector<Servicio>(
                              label: '', // Ocultamos label nativo para que parezca de la imagen
                              hint: 'Añadir Servicio',
                              items: _servicios,
                              selectedItem: null,
                              displayText: (s) => s.nombre,
                              searchText: (s) => s.nombre,
                              prefixIcon: Icons.cut,
                              required: _serviciosSeleccionados.isEmpty,
                              onSelected: (s) {
                                if (s != null && !_serviciosSeleccionados.any((sel) => sel.id == s.id)) {
                                  setState(() {
                                    _serviciosSeleccionados.add(s);
                                    _calcularTotal();
                                  });
                                  _recalcularSlots();
                                }
                              },
                            )
                          : SearchableSelector<Paquete>(
                              label: '',
                              hint: 'Añadir Paquete',
                              items: _paquetes,
                              selectedItem: _paqueteSeleccionado,
                              displayText: (p) => p.nombre,
                              searchText: (p) => p.nombre,
                              prefixIcon: Icons.inventory_2,
                              required: true,
                              onSelected: (p) {
                                setState(() {
                                  _paqueteSeleccionado = p;
                                  _calcularTotal();
                                });
                                _recalcularSlots();
                              },
                            ),
                      
                      // Chips de servicios seleccionados (si hay más de 1)
                      if (_esServicio && _serviciosSeleccionados.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _serviciosSeleccionados.map((s) => Chip(
                            label: Text(s.nombre),
                            onDeleted: () {
                              setState(() {
                                _serviciosSeleccionados.removeWhere((sel) => sel.id == s.id);
                                _calcularTotal();
                                _horaInicioSeleccionada = null;
                                _horaFinSeleccionada = null;
                              });
                              _recalcularSlots();
                            },
                            backgroundColor: const Color(0xFF161616),
                            deleteIconColor: const Color(0xFFD8B081),
                            labelStyle: const TextStyle(color: Colors.white, fontSize: 13),
                            side: const BorderSide(color: Color(0xFF333333)),
                          )).toList(),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── Productos ──
                      SearchableSelector<Producto>(
                              label: 'Añadir Producto',
                              hint: 'Escribe el nombre del producto...',
                              items: _productos,
                              selectedItem: null,
                              displayText: (p) => p.nombre,
                              searchText: (p) => p.nombre,
                              prefixIcon: Icons.shopping_bag,
                              required: false,
                              renderItem: (p) => Row(
                                children: [
                                  Expanded(child: Text(p.nombre, style: const TextStyle(color: Colors.white, fontSize: 14))),
                                  Text('\$${p.precioVenta.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFD8B081), fontSize: 12)),
                                ],
                              ),
                              onSelected: (p) {
                                if (p != null) {
                                  setState(() {
                                    _productoCantidades[p.id!] = (_productoCantidades[p.id!] ?? 0) + 1;
                                    _calcularTotal();
                                  });
                                }
                              },
                            ),
                      if (_productoCantidades.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ..._productoCantidades.entries.map((e) {
                          final p = _productos.firstWhere((prod) => prod.id == e.key, orElse: () => Producto(nombre: 'Desconocido', categoriaId: 0, proveedorId: 0, precioCompra: 0, precioVenta: 0));
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0, left: 16, right: 16),
                            child: Row(
                              children: [
                                Expanded(child: Text(p.nombre, style: const TextStyle(color: Colors.white70))),
                                Text('\$${(p.precioVenta * e.value).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                const SizedBox(width: 12),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFD8B081), size: 20),
                                      onPressed: () {
                                        setState(() {
                                          if (e.value > 1) {
                                            _productoCantidades[e.key] = e.value - 1;
                                          } else {
                                            _productoCantidades.remove(e.key);
                                          }
                                          _calcularTotal();
                                        });
                                      },
                                    ),
                                    Text('${e.value}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline, color: Color(0xFFD8B081), size: 20),
                                      onPressed: () {
                                        setState(() {
                                          _productoCantidades[e.key] = e.value + 1;
                                          _calcularTotal();
                                        });
                                      },
                                    ),
                                  ],
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                      const SizedBox(height: 24),

                      // ── Selecciona los días (Weekday Selector) ──
                      const Text('Selecciona el día:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      _buildDaySelector(),
                      const SizedBox(height: 24),

                      // ── Cuadrícula: Hora Inicio, Hora Fin, Monto ──
                      Row(
                        children: [
                           Expanded(child: _buildHoraInicioPicker()),
                           const SizedBox(width: 12),
                           Expanded(
                            child: _buildGridBox(
                              label: 'Hora de fin (Auto)',
                              value: _horaFinSeleccionada != null ? _toAmPm(_horaFinSeleccionada!) : '--:--',
                              rightIcon: Icons.access_time,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildGridBox(
                              label: 'Hora de fin (Auto)',
                              value: _horaFinSeleccionada != null ? _toAmPm(_horaFinSeleccionada!) : '--:--',
                              rightIcon: Icons.access_time,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Monto', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF161616),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: TextFormField(
                                    controller: _montoController,
                                    readOnly: true,
                                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      prefixText: '\$ ',
                                      prefixStyle: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Estado de la Cita ──
                      const Text('Estado de la cita', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _estadoCita,
                            dropdownColor: const Color(0xFF1E1E1E),
                            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                            items: _estadosCita.map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                            )).toList(),
                            onChanged: (e) => setState(() => _estadoCita = e!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Observaciones ──
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF161616),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextFormField(
                          initialValue: _observaciones ?? '',
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Observaciones',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                          onChanged: (v) => _observaciones = v,
                        ),
                      ),
                      const SizedBox(height: 40),

                      // ── Botones ──
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFD8B081)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: Color(0xFFD8B081), fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _guardarAgendamiento,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD8B081),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22, height: 22,
                                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                                    )
                                  : Text(
                                      widget.agendamiento == null ? 'Crear Cita' : 'Actualizar',
                                      style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}