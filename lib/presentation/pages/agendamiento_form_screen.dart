import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/servicio_service.dart';
import 'package:parte_movil/data/datasources/paquete_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/producto_service.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/core/utils/app_format.dart';

// ─── Theme constants ─────────────────────────────────────────────────────────
// Usando la paleta oficial del proyecto (AppColors / globals.css)

const _kBg        = Color(0xFF111111);          // --black-secondary
const _kSurface   = Color(0xFF1A1919);          // --gray-darkest  (cards)
const _kSurface2  = Color(0xFF2A2A2A);          // --gray-darker
const _kBorder    = Color(0xFF3A3A3A);          // --gray-dark
const _kBorderHover = Color(0xFF4A4A4A);        // ligeramente más claro
const _kGold      = Color(0xFFE0C080);          // goldLight
const _kGoldMid   = Color(0xFFD8B081);          // --orange-primary
const _kGoldDark  = Color(0xFF9A7040);          // goldDeep
const _kGoldTint  = Color(0xFF2A1F0E);          // tinte dorado sobre card
const _kGoldBorder = Color(0xFF5A3A18);         // borde dorado visible
const _kGoldText  = Color(0xFFD8B081);          // --orange-primary
const _kText      = Color(0xFFFFFFFF);          // --white-primary
const _kTextMuted = Color(0xFFD0D0D0);          // --gray-lightest
const _kTextDim   = Color(0xFFB0B0B0);          // --gray-lighter
const _kTextFaint = Color(0xFF888888);          // --gray-light
const _kRadius    = 14.0;
const _kRadiusMd  = 10.0;
const _kRadiusSm  = 8.0;

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
  return '$h:${m.toString().padLeft(2, '0')} $period';
}

// ─── Widget Principal ─────────────────────────────────────────────────────────

class AgendamientoFormScreen extends StatefulWidget {
  final Agendamiento? agendamiento;
  final AppRole role;

  const AgendamientoFormScreen({
    super.key,
    this.agendamiento,
    this.role = AppRole.admin,
  });

  @override
  State<AgendamientoFormScreen> createState() => _AgendamientoFormScreenState();
}

class _AgendamientoFormScreenState extends State<AgendamientoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final AgendamientoService _agendamientoService = AgendamientoService();
  final ClienteService _clienteService = ClienteService();
  final BarberoService _barberoService = BarberoService();
  final ServicioService _servicioService = ServicioService();
  final PaqueteService _paqueteService = PaqueteService();
  final AuthService _authService = AuthService();
  final UserContextService _userContextService = UserContextService();

  List<Cliente> _clientes = [];
  List<Barbero> _barberos = [];
  List<Servicio> _servicios = [];
  List<Paquete> _paquetes = [];
  List<Producto> _productos = [];
  List<Agendamiento> _todasLasCitas = [];
  List<HorarioSemanal> _todosLosHorarios = [];

  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  List<Servicio> _serviciosSeleccionados = [];
  Paquete? _paqueteSeleccionado;
  Map<int, int> _productoCantidades = {};
  final Map<int, TextEditingController> _productoCantidadCtrls = {};
  bool _esServicio = true;

  // Buscador de servicios (igual que en paquetes)
  final _buscarServicioAgendCtrl = TextEditingController();
  String _busquedaServicioAgend = '';
  bool _mostrarResultadosAgend = false;

  // Buscador de productos
  final _buscarProductoCtrl = TextEditingController();
  String _busquedaProducto = '';
  bool _mostrarResultadosProducto = false;

  static DateTime _defaultFecha() {
    final now = DateTime.now();
    if (now.hour >= 23) return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _fechaSeleccionada = _defaultFecha();
  String? _horaInicioSeleccionada = DateTime.now().hour >= 23 ? '10:30' : null;
  String? _horaFinSeleccionada = DateTime.now().hour >= 23 ? '11:00' : null;
  List<String> _slotsDisponibles = [];

  String _estadoCita = 'Pendiente';
  double? _monto;
  String? _observaciones;
  bool _isLoading = false;
  bool _isLoadingData = true;

  final TextEditingController _montoController = TextEditingController();

  // Estado index para ciclado
  final List<Map<String, dynamic>> _estadosCita = [
    {
      'label': 'Pendiente',
      'color': const Color(0xFF2A1F0E),          // _kGoldTint
      'textColor': const Color(0xFFD8B081),       // --orange-primary
      'border': const Color(0xFF5A3A18),          // _kGoldBorder
    },
    {
      'label': 'Completada',
      'color': const Color(0xFF0F2018),
      'textColor': const Color(0xFF7AAB8A),       // --status-green
      'border': const Color(0xFF1F5535),
    },
    {
      'label': 'Cancelada',
      'color': const Color(0xFF2A1010),
      'textColor': const Color(0xFFB07070),       // --status-red
      'border': const Color(0xFF552020),
    },
  ];
  int _estadoIndex = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatos().then((_) {
      if (widget.agendamiento != null && mounted) {
        _rellenarFormulario(widget.agendamiento!);
      }
    });
  }

  @override
  void dispose() {
    _montoController.dispose();
    _buscarServicioAgendCtrl.dispose();
    _buscarProductoCtrl.dispose();
    for (final c in _productoCantidadCtrls.values) c.dispose();
    super.dispose();
  }

  // ─── Carga de datos ────────────────────────────────────────────────────────

  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        _clienteService.obtenerClientes(),
        _barberoService.obtenerBarberos(),
        _servicioService.obtenerServicios(),
        _paqueteService.obtenerPaquetes(),
        ProductoService().getProductos(pageSize: 100),
        _agendamientoService.obtenerAgendamientos(),
        _barberoService.obtenerHorariosBarberos(),
      ]);

      if (!mounted) return;
      setState(() {
        _clientes = (results[0] as List<Cliente>)
            .where((c) => c.estado ?? true)
            .toList();
        final listBarberRaw =
            (results[1] as List<Barbero>)
                .where((b) => b.estado ?? true)
                .toList()
              ..sort(
                (a, b) => a.nombreCompleto.toLowerCase().compareTo(
                  b.nombreCompleto.toLowerCase(),
                ),
              );
        _barberos = listBarberRaw;
        _servicios = results[2] as List<Servicio>;
        _paquetes = results[3] as List<Paquete>;
        _productos = (results[4] as Paginacion<Producto>).items;
        _todasLasCitas = (results[5] as Paginacion<Agendamiento>).items;
        _todosLosHorarios = results[6] as List<HorarioSemanal>;
        _isLoadingData = false;
      });

      Cliente? autoCliente;
      Barbero? autoBarber;

      if (widget.agendamiento == null) {
        if (widget.role == AppRole.client) {
          autoCliente = await _userContextService.obtenerClienteActual(
            clientesCache: _clientes,
          );
        } else if (widget.role == AppRole.barber) {
          autoBarber = await _userContextService.obtenerBarberoActual(
            barberosCache: _barberos,
          );
        }
      }

      if (!mounted) return;
      setState(() {
        _clienteSeleccionado = autoCliente ?? _clienteSeleccionado;
        _barberoSeleccionado = autoBarber ?? _barberoSeleccionado;
        _recalcularSlots();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingData = false);
      _mostrarError(limpiarError(e));
    }
  }

  // ─── Lógica de negocio ─────────────────────────────────────────────────────

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
        _serviciosSeleccionados = _servicios
            .where((s) => a.servicioIds.contains(s.id))
            .toList();
        _esServicio = true;
      } else if (a.servicioId != null) {
        try {
          final serv = _servicios.firstWhere((s) => s.id == a.servicioId);
          _serviciosSeleccionados = [serv];
          _esServicio = true;
        } catch (_) {
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
          _paqueteSeleccionado = _paquetes.firstWhere(
            (p) => p.id == a.paqueteId,
          );
        } catch (_) {
          _paqueteSeleccionado = a.paquete;
        }
        _esServicio = false;
      }
      if (a.fechaCita != null && a.fechaCita!.isNotEmpty) {
        _fechaSeleccionada =
            DateTime.tryParse(a.fechaCita!) ?? _fechaSeleccionada;
      }
      _horaInicioSeleccionada = a.horaInicio?.isNotEmpty == true
          ? a.horaInicio
          : null;
      _horaFinSeleccionada = a.horaFin?.isNotEmpty == true ? a.horaFin : null;

      final idx = _estadosCita.indexWhere(
        (e) => e['label'] == (a.estadoCita ?? 'Pendiente'),
      );
      _estadoIndex = idx >= 0 ? idx : 0;
      _estadoCita = _estadosCita[_estadoIndex]['label'] as String;

      _monto = a.monto ?? a.precio;
      _montoController.text = _monto?.toStringAsFixed(0) ?? '';
    });
    _recalcularSlots();
  }

  void _recalcularSlots() {
    if (_barberoSeleccionado == null) {
      setState(() => _slotsDisponibles = []);
      return;
    }
    final dartDow = _fechaSeleccionada.weekday; // 1..7
    final fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

    // Buscar el HorarioSemanal activo para este barbero que cubra la fecha seleccionada
    final horarioSemanal = _todosLosHorarios.where((h) {
      if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
      if (h.estado != 'Activo') return false;
      if (h.fechaInicioSemana.compareTo(fechaStr) <= 0 && h.fechaFinSemana.compareTo(fechaStr) >= 0) return true;
      return false;
    }).toList();

    // Obtener los detalles que coincidan con el día de la semana
    final horariosBarbero = horarioSemanal.expand((h) => h.detalles).where((d) {
      return d.diaSemana == dartDow || (dartDow == 7 && d.diaSemana == 0);
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
      durMin = _serviciosSeleccionados.fold(
        0,
        (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30),
      );
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30;

    final now = DateTime.now();
    final isToday =
        _fechaSeleccionada.year == now.year &&
        _fechaSeleccionada.month == now.month &&
        _fechaSeleccionada.day == now.day;
    final currentMin = now.hour * 60 + now.minute;

    final citasBarberoHoy = _todasLasCitas.where((c) {
      if (c.barberoId != _barberoSeleccionado!.id) return false;
      if (c.estado?.toLowerCase() == 'cancelada' ||
          c.estadoCita?.toLowerCase() == 'cancelada')
        return false;
      String fCita = c.fechaCita ?? '';
      if (fCita.isEmpty && c.fechaHora != null && c.fechaHora!.contains('T')) {
        fCita = c.fechaHora!.split('T')[0];
      }
      if (fCita != fechaStr) return false;
      if (c.id != null &&
          widget.agendamiento != null &&
          c.id == widget.agendamiento!.id)
        return false;
      return true;
    }).toList();

    final slots = <String>[];
    for (final h in horariosBarbero) {
      int cursor = _toMinutes(h.horaInicio);
      final end = _toMinutes(h.horaFin);
      while (cursor + durMin <= end) {
        bool solapa = false;
        if (isToday && cursor < currentMin + 30) solapa = true;
        if (!solapa) {
          final endCursor = cursor + durMin;
          for (final c in citasBarberoHoy) {
            if (c.horaInicio == null || c.horaInicio!.isEmpty) continue;
            int startExist = _toMinutes(c.horaInicio!);
            int endExist = (c.horaFin != null && c.horaFin!.isNotEmpty)
                ? _toMinutes(c.horaFin!)
                : startExist + 60;
            if (cursor < endExist && startExist < endCursor) {
              solapa = true;
              break;
            }
          }
        }
        if (!solapa) slots.add(_fromMinutes(cursor));
        cursor += 30;
      }
    }

    final uniqueSlots = slots.toSet().toList()..sort();
    setState(() {
      _slotsDisponibles = uniqueSlots;
      if (_horaInicioSeleccionada != null &&
          !uniqueSlots.contains(_horaInicioSeleccionada)) {
        _horaInicioSeleccionada = null;
        _horaFinSeleccionada = null;
      }
    });
  }

  void _seleccionarSlot(String slot) {
    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(
        0,
        (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30),
      );
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30;
    setState(() {
      _horaInicioSeleccionada = slot;
      _horaFinSeleccionada = _fromMinutes(_toMinutes(slot) + durMin);
    });
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

    // Validar anticipación de 30 minutos para citas de hoy
    final now = DateTime.now();
    final isToday = _fechaSeleccionada.year == now.year &&
        _fechaSeleccionada.month == now.month &&
        _fechaSeleccionada.day == now.day;
    if (isToday) {
      final startMin = _toMinutes(_horaInicioSeleccionada!);
      final currentMin = now.hour * 60 + now.minute;
      if (startMin < currentMin + 30) {
        _mostrarError('Las citas para hoy deben ser con al menos 30 min de anticipación', centered: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final agendamiento = Agendamiento(
        id: widget.agendamiento?.id,
        clienteId: _clienteSeleccionado!.id!,
        barberoId: _barberoSeleccionado!.id!,
        servicioId: _esServicio && _serviciosSeleccionados.isNotEmpty
            ? _serviciosSeleccionados.first.id
            : null,
        servicioIds: _esServicio
            ? _serviciosSeleccionados.map((s) => s.id!).toList()
            : [],
        productoIds: _productoCantidades.entries
            .expand((e) => List.filled(e.value, e.key))
            .toList(),
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
        _mostrarExito(
          widget.agendamiento == null
              ? '¡Cita creada exitosamente! La cita ha sido registrada.'
              : '¡Cita actualizada exitosamente! Los cambios han sido guardados correctamente.',
        );
        navigator.pop(true);
      }
    } catch (e) {
      _mostrarError(limpiarError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarExito(String msg) {
    if (!mounted) return;
    AppToast.showSuccess(context, msg);
  }

  void _mostrarError(String msg, {bool centered = false}) {
    if (!mounted) return;
    AppToast.showError(context, msg, centered: centered);
  }


  // ─── UI Helpers ────────────────────────────────────────────────────────────

  /// Etiqueta de sección en mayúsculas pequeñas
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: _kTextDim,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.08 * 11,
      ),
    ),
  );

  void _recalculateSlotsAndRefresh() {
    _recalcularSlots();
  }

  void _showClienteSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seleccionar Cliente',
              style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _clientes.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final c = _clientes[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: _buildAvatar(c.fotoPerfil, Icons.person_outline, size: 40),
                    title: Text(
                      c.nombreCompleto,
                      style: const TextStyle(color: _kText, fontSize: 16),
                    ),
                    onTap: () {
                      setState(() {
                        _clienteSeleccionado = c;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBarberoSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Seleccionar Barbero',
              style: TextStyle(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _barberos.length,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemBuilder: (context, index) {
                  final b = _barberos[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    leading: _buildAvatar(b.fotoPerfil, Icons.cut, size: 40),
                    title: Text(
                      b.nombreCompleto,
                      style: const TextStyle(color: _kText, fontSize: 16),
                    ),
                    onTap: () {
                      setState(() {
                        _barberoSeleccionado = b;
                        _horaInicioSeleccionada = null;
                        _horaFinSeleccionada = null;
                      });
                      final nextWorkDay = _findFirstWorkingDay(_fechaSeleccionada);
                      if (nextWorkDay != _fechaSeleccionada) {
                        setState(() {
                          _fechaSeleccionada = nextWorkDay;
                        });
                      }
                      _recalculateSlotsAndRefresh();
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Avatar o icono fallback
  Widget _buildAvatar(String? foto, IconData fallback, {double size = 36}) {
    if (foto == null || foto.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kBorder, width: 0.5),
        ),
        child: Icon(fallback, color: _kTextFaint, size: size * 0.5),
      );
    }

    Widget image;
    if (foto.startsWith('http')) {
      image = Image.network(
        foto,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, color: _kTextFaint, size: size * 0.5),
      );
    } else {
      try {
        // Asumimos base64 si no es URL
        final cleanBase64 = foto.contains(',') ? foto.split(',')[1] : foto;
        image = Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallback, color: _kTextFaint, size: size * 0.5),
        );
      } catch (_) {
        image = Icon(
          fallback,
          color: _kTextFaint,
          size: size * 0.5,
        );
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _kSurface2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(9.5), child: image),
    );
  }

  /// Card de selección (barbero / cliente)
  Widget _buildSelectorCard({
    required IconData icon,
    required String name,
    required String hint,
    required VoidCallback? onTap,
    String? foto,
    bool locked = false,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: Row(
        children: [
          _buildAvatar(foto, icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: const TextStyle(color: _kTextDim, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(
            locked ? Icons.lock_outline : Icons.keyboard_arrow_down,
            color: _kTextFaint,
            size: 20,
          ),
        ],
      ),
    ),
  );

  /// Toggle Servicio / Paquete
  Widget _buildTypeToggle() => Row(
    children: [
      _buildToggleOption('Servicio', Icons.cut, true),
      const SizedBox(width: 8),
      _buildToggleOption('Paquete', Icons.inventory_2_outlined, false),
    ],
  );

  Widget _buildToggleOption(String label, IconData icon, bool isService) {
    final selected = _esServicio == isService;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _esServicio = isService;
            _serviciosSeleccionados.clear();
            _paqueteSeleccionado = null;
            _monto = null;
            _horaInicioSeleccionada = null;
            _horaFinSeleccionada = null;
            _buscarServicioAgendCtrl.clear();
            _busquedaServicioAgend = '';
            _mostrarResultadosAgend = false;
            _productoCantidades.clear();
            for (final c in _productoCantidadCtrls.values) c.dispose();
            _productoCantidadCtrls.clear();
            _buscarProductoCtrl.clear();
            _busquedaProducto = '';
            _mostrarResultadosProducto = false;
          });
          _recalcularSlots();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _kGoldTint : _kSurface,
            borderRadius: BorderRadius.circular(_kRadiusMd),
            border: Border.all(
              color: selected ? _kGoldDark : _kBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? _kGoldMid : _kTextDim),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _kGold : _kTextDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selector de servicios - buscador con lista desplegable (igual que en paquetes)
  Widget _buildServiciosList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _buscarServicioAgendCtrl,
          style: TextStyle(color: _kText, fontSize: 13),
          onChanged: (val) => setState(() {
            _busquedaServicioAgend = val;
            _mostrarResultadosAgend = true;
          }),
          onTap: () => setState(() => _mostrarResultadosAgend = true),
          decoration: InputDecoration(
            hintText: 'Buscar servicio...',
            hintStyle: TextStyle(color: _kTextFaint, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: _kGoldMid, size: 20),
            suffixIcon: _buscarServicioAgendCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: _kTextFaint),
                    onPressed: () => setState(() {
                      _buscarServicioAgendCtrl.clear();
                      _busquedaServicioAgend = '';
                      _mostrarResultadosAgend = false;
                    }),
                  )
                : _mostrarResultadosAgend
                    ? IconButton(
                        icon: Icon(Icons.keyboard_arrow_up, color: _kTextFaint, size: 22),
                        onPressed: () => setState(() => _mostrarResultadosAgend = false),
                      )
                    : IconButton(
                        icon: Icon(Icons.keyboard_arrow_down, color: _kTextFaint, size: 22),
                        onPressed: () => setState(() => _mostrarResultadosAgend = true),
                      ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kBorder, width: 0.5),
              borderRadius: BorderRadius.circular(_kRadiusMd),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kGoldDark, width: 0.5),
              borderRadius: BorderRadius.circular(_kRadiusMd),
            ),
            filled: true,
            fillColor: _kSurface,
          ),
        ),
        if (_mostrarResultadosAgend) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: _kBorder, width: 0.5),
            ),
            child: Builder(builder: (_) {
              final query = _busquedaServicioAgend.toLowerCase();
              final selIds = _serviciosSeleccionados.map((s) => s.id).toSet();
              final resultados = _servicios
                  .where((s) => (s.estado ?? true) &&
                      (query.isEmpty || s.nombre.toLowerCase().contains(query)))
                  .toList();
              
              // Ordenar: No seleccionados primero, seleccionados al final
              resultados.sort((a, b) {
                final aSel = selIds.contains(a.id);
                final bSel = selIds.contains(b.id);
                if (aSel && !bSel) return 1;
                if (!aSel && bSel) return -1;
                return 0;
              });

              if (resultados.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No se encontraron servicios',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kTextFaint, fontSize: 13)),
                );
              }
              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: resultados.length,
                itemBuilder: (context, i) {
                  final s = resultados[i];
                  final yaSeleccionado = selIds.contains(s.id);
                  return InkWell(
                    onTap: yaSeleccionado ? null : () {
                      setState(() {
                        _serviciosSeleccionados.add(s);
                        _buscarServicioAgendCtrl.clear();
                        _busquedaServicioAgend = '';
                        _mostrarResultadosAgend = false;
                        _calcularTotal();
                        _horaInicioSeleccionada = null;
                        _horaFinSeleccionada = null;
                      });
                      _recalcularSlots();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          if (!yaSeleccionado) ...[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _kSurface2,
                                borderRadius: BorderRadius.circular(8),
                                image: s.imagen != null && s.imagen!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(s.imagen!),
                                        fit: BoxFit.cover)
                                    : null,
                              ),
                              child: s.imagen == null || s.imagen!.isEmpty
                                  ? Icon(Icons.content_cut, color: _kGoldMid, size: 18)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (yaSeleccionado) const SizedBox(width: 50),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.nombre,
                                    style: TextStyle(
                                      color: yaSeleccionado ? _kTextFaint : _kText,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    )),
                                const SizedBox(height: 2),
                                Text(
                                  yaSeleccionado
                                      ? 'Ya esta en esta cita'
                                      : '${AppFormat.duracion(s.duracionMinutos)}  \$${s.precio.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: yaSeleccionado ? _kGoldMid.withOpacity(0.6) : _kTextDim,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (yaSeleccionado)
                            Icon(Icons.check_circle, color: _kGoldMid, size: 18)
                          else
                            Icon(Icons.add_circle_outline, color: _kGoldMid, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
        if (_serviciosSeleccionados.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _serviciosSeleccionados.length,
              itemBuilder: (ctx, i) {
                final s = _serviciosSeleccionados[i];
                return _selectedServicioCard(s);
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectedServicioCard(Servicio s) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kGoldTint,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        border: Border.all(color: _kGoldMid, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _kSurface2,
              borderRadius: BorderRadius.circular(8),
              image: (s.imagen != null && s.imagen!.isNotEmpty)
                  ? DecorationImage(image: NetworkImage(s.imagen!), fit: BoxFit.cover)
                  : null,
            ),
            child: (s.imagen == null || s.imagen!.isEmpty)
                ? Icon(Icons.content_cut, color: _kGoldMid, size: 16)
                : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kGold, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('\$${s.precio.toStringAsFixed(0)}  ·  ${AppFormat.duracion(s.duracionMinutos)}',
                    style: const TextStyle(color: _kTextDim, fontSize: 10)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _serviciosSeleccionados.removeWhere((sel) => sel.id == s.id);
                _calcularTotal();
                _horaInicioSeleccionada = null;
                _horaFinSeleccionada = null;
              });
              _recalcularSlots();
            },
            child: const Icon(Icons.close, color: _kTextFaint, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _selectedProductoCard(Producto p, int productId, int qty) {
    final sinStock = p.cantidad > 0 && qty >= p.cantidad;
    // Obtener o crear el controller para este producto
    final ctrl = _productoCantidadCtrls.putIfAbsent(
      productId, () => TextEditingController(text: '$qty'),
    );
    // Sincronizar texto si fue modificado externamente (+/-)
    if (ctrl.text != '$qty') {
      ctrl.value = TextEditingValue(
        text: '$qty',
        selection: TextSelection.collapsed(offset: '$qty'.length),
      );
    }

    return Container(
      width: 162,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadiusMd),
        border: Border.all(
          color: sinStock ? const Color(0xFFB07070) : _kBorder,
          width: sinStock ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Nombre + X ──
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: _kSurface2,
                  borderRadius: BorderRadius.circular(6),
                  image: (p.imagenProduc != null && p.imagenProduc!.isNotEmpty)
                      ? DecorationImage(image: NetworkImage(p.imagenProduc!), fit: BoxFit.cover)
                      : null,
                ),
                child: (p.imagenProduc == null || p.imagenProduc!.isEmpty)
                    ? Icon(Icons.shopping_bag_outlined, color: _kGoldMid, size: 13)
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _kText, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              GestureDetector(
                onTap: () {
                  ctrl.dispose();
                  _productoCantidadCtrls.remove(productId);
                  setState(() {
                    _productoCantidades.remove(productId);
                    _calcularTotal();
                  });
                },
                child: const Icon(Icons.close, color: _kTextFaint, size: 14),
              ),
            ],
          ),
          // ── Precio + indicador stock ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('\$${(p.precioVenta * qty).toStringAsFixed(0)}',
                  style: const TextStyle(color: _kGoldMid, fontSize: 10, fontWeight: FontWeight.bold)),
              if (sinStock) ...[
                const SizedBox(height: 2),
                Text('Máx: ${p.cantidad}',
                    style: const TextStyle(color: Color(0xFFB07070), fontSize: 9, fontWeight: FontWeight.w500)),
              ],
            ],
          ),
          // ── Controles de cantidad ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Botón −
              _hQtyBtn(Icons.remove, enabled: qty > 0, onTap: () {
                final nv = qty > 1 ? qty - 1 : null;
                if (nv != null) {
                  ctrl.value = TextEditingValue(
                    text: '$nv',
                    selection: TextSelection.collapsed(offset: '$nv'.length),
                  );
                  setState(() {
                    _productoCantidades[productId] = nv;
                    _calcularTotal();
                  });
                } else {
                  ctrl.dispose();
                  _productoCantidadCtrls.remove(productId);
                  setState(() {
                    _productoCantidades.remove(productId);
                    _calcularTotal();
                  });
                }
              }),
              // Campo de cantidad editable
              SizedBox(
                width: 38,
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: TextStyle(
                    color: sinStock ? const Color(0xFFB07070) : _kGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: sinStock ? const Color(0xFF552020) : _kBorder,
                        width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: sinStock ? const Color(0xFFB07070) : _kGoldBorder,
                        width: 1,
                      ),
                    ),
                    filled: true,
                    fillColor: _kSurface2,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n == null || n < 1) return; // esperar a que termine de escribir
                    if (p.cantidad > 0 && n > p.cantidad) {
                      // Supera stock: clamp y mostrar error
                      ctrl.value = TextEditingValue(
                        text: '${p.cantidad}',
                        selection: TextSelection.collapsed(offset: '${p.cantidad}'.length),
                      );
                      setState(() {
                        _productoCantidades[productId] = p.cantidad;
                        _calcularTotal();
                      });
                      _mostrarError(
                        'Stock máximo: ${p.cantidad} unidades de "${p.nombre}"',
                        centered: true,
                      );
                    } else {
                      setState(() {
                        _productoCantidades[productId] = n;
                        _calcularTotal();
                      });
                    }
                  },
                  onEditingComplete: () {
                    final n = int.tryParse(ctrl.text);
                    if (n == null || n < 1) {
                      // Si dejó vacío o 0, eliminar producto
                      ctrl.dispose();
                      _productoCantidadCtrls.remove(productId);
                      setState(() {
                        _productoCantidades.remove(productId);
                        _calcularTotal();
                      });
                    }
                    FocusScope.of(context).unfocus();
                  },
                ),
              ),
              // Botón +
              GestureDetector(
                onTap: () {
                  if (sinStock) {
                    _mostrarError(
                      'Stock máximo alcanzado: ${p.cantidad} unidades de "${p.nombre}"',
                      centered: true,
                    );
                    return;
                  }
                  final nv = qty + 1;
                  ctrl.value = TextEditingValue(
                    text: '$nv',
                    selection: TextSelection.collapsed(offset: '$nv'.length),
                  );
                  setState(() {
                    _productoCantidades[productId] = nv;
                    _calcularTotal();
                  });
                },
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                    color: _kSurface2,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: sinStock ? const Color(0xFF552020) : _kGoldBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(Icons.add, size: 14,
                      color: sinStock ? const Color(0xFFB07070) : _kGoldMid),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Selector de paquete
  Widget _buildPaqueteSelector() => SearchableSelector<Paquete>(
    label: '',
    hint: 'Selecciona un paquete...',
    items: _paquetes,
    selectedItem: _paqueteSeleccionado,
    displayText: (p) => p.nombre,
    searchText: (p) => p.nombre,
    prefixIcon: Icons.inventory_2_outlined,
    required: true,
    onSelected: (p) {
      setState(() {
        _paqueteSeleccionado = p;
        _calcularTotal();
      });
      _recalcularSlots();
    },
  );

  /// Chips de servicios seleccionados
  Widget _buildServicioChips() {
    if (_serviciosSeleccionados.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: _serviciosSeleccionados
            .map(
              (s) => _ServiceChip(
                label: s.nombre,
                onRemove: () {
                  setState(() {
                    _serviciosSeleccionados.removeWhere(
                      (sel) => sel.id == s.id,
                    );
                    _calcularTotal();
                    _horaInicioSeleccionada = null;
                    _horaFinSeleccionada = null;
                  });
                  _recalcularSlots();
                },
              ),
            )
            .toList(),
      ),
    );
  }

  /// Seccion de productos - buscador con lista desplegable
  Widget _buildProductosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Buscador ──
        TextField(
          controller: _buscarProductoCtrl,
          style: TextStyle(color: _kText, fontSize: 13),
          onChanged: (val) => setState(() {
            _busquedaProducto = val;
            _mostrarResultadosProducto = true;
          }),
          onTap: () => setState(() => _mostrarResultadosProducto = true),
          decoration: InputDecoration(
            hintText: 'Buscar producto...',
            hintStyle: TextStyle(color: _kTextFaint, fontSize: 13),
            prefixIcon: Icon(Icons.search, color: _kGoldMid, size: 20),
            suffixIcon: _buscarProductoCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, size: 18, color: _kTextFaint),
                    onPressed: () => setState(() {
                      _buscarProductoCtrl.clear();
                      _busquedaProducto = '';
                      _mostrarResultadosProducto = false;
                    }),
                  )
                : _mostrarResultadosProducto
                    ? IconButton(
                        icon: Icon(Icons.keyboard_arrow_up, color: _kTextFaint, size: 22),
                        onPressed: () => setState(() => _mostrarResultadosProducto = false),
                      )
                    : IconButton(
                        icon: Icon(Icons.keyboard_arrow_down, color: _kTextFaint, size: 22),
                        onPressed: () => setState(() => _mostrarResultadosProducto = true),
                      ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kBorder, width: 0.5),
              borderRadius: BorderRadius.circular(_kRadiusMd),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kGoldDark, width: 0.5),
              borderRadius: BorderRadius.circular(_kRadiusMd),
            ),
            filled: true,
            fillColor: _kSurface,
          ),
        ),

        // ── Resultados ──
        if (_mostrarResultadosProducto) ...[
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(_kRadiusMd),
              border: Border.all(color: _kBorder, width: 0.5),
            ),
            child: Builder(builder: (_) {
              final query = _busquedaProducto.toLowerCase();
              final selIds = _productoCantidades.keys.toSet();
              final resultados = _productos
                  .where((p) => (query.isEmpty || p.nombre.toLowerCase().contains(query)))
                  .toList();

              // Ordenar: No seleccionados primero, seleccionados al final
              resultados.sort((a, b) {
                final aSel = selIds.contains(a.id);
                final bSel = selIds.contains(b.id);
                if (aSel && !bSel) return 1;
                if (!aSel && bSel) return -1;
                return 0;
              });

              if (resultados.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No se encontraron productos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _kTextFaint, fontSize: 13)),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: resultados.length,
                itemBuilder: (context, i) {
                  final p = resultados[i];
                  final cantActual = _productoCantidades[p.id] ?? 0;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _productoCantidades[p.id!] = cantActual + 1;
                        _buscarProductoCtrl.clear();
                        _busquedaProducto = '';
                        _mostrarResultadosProducto = false;
                        _calcularTotal();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _kSurface2,
                              borderRadius: BorderRadius.circular(8),
                              image: (p.imagenProduc != null && p.imagenProduc!.isNotEmpty)
                                  ? DecorationImage(
                                      image: NetworkImage(p.imagenProduc!),
                                      fit: BoxFit.cover)
                                  : null,
                            ),
                            child: (p.imagenProduc == null || p.imagenProduc!.isEmpty)
                                ? Icon(Icons.shopping_bag_outlined, color: _kGoldMid, size: 18)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nombre,
                                    style: TextStyle(
                                        color: _kText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${p.precioVenta.toStringAsFixed(0)}',
                                  style: TextStyle(color: _kTextDim, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          if (cantActual > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _kGoldTint,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _kGoldBorder, width: 0.5),
                              ),
                              child: Text('x$cantActual',
                                  style: TextStyle(
                                      color: _kGoldMid,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                            )
                          else
                            Icon(Icons.add_circle_outline, color: _kGoldMid, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],

        // ── Productos seleccionados ──
        if (_productoCantidades.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 118,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productoCantidades.length,
              itemBuilder: (ctx, i) {
                final entry = _productoCantidades.entries.toList()[i];
                final p = _productos.firstWhere(
                  (prod) => prod.id == entry.key,
                  orElse: () => Producto(nombre: 'Desconocido', categoriaId: 0, precioVenta: 0),
                );
                return _selectedProductoCard(p, entry.key, entry.value);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _hQtyBtn(IconData icon, {required bool enabled, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: enabled ? _kGoldBorder : _kBorder, width: 0.5),
        ),
        child: Icon(icon, size: 14, color: enabled ? _kGoldMid : _kTextFaint),
      ),
    );
  }

  /// Selector de semana + días
  // ── Estado del calendario inline ──────────────────────────────────────────
  late DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Widget _buildDaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCalendarMonthNav(),
        const SizedBox(height: 10),
        _buildCalendarWeekHeader(),
        const SizedBox(height: 6),
        _buildCalendarMonthGrid(_calendarMonth),
      ],
    );
  }

  Widget _buildCalendarMonthNav() {
    const meses = [
      'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre',
    ];
    final label = '${meses[_calendarMonth.month - 1]} ${_calendarMonth.year}';
    final now = DateTime.now();
    final isCurrentMonth = _calendarMonth.year == now.year && _calendarMonth.month == now.month;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: isCurrentMonth ? null : () => setState(() {
            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
          }),
          icon: Icon(Icons.chevron_left,
              color: isCurrentMonth ? _kTextFaint : _kGoldMid, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        Text(label,
            style: const TextStyle(
                color: _kText, fontSize: 14, fontWeight: FontWeight.w600)),
        IconButton(
          onPressed: () => setState(() {
            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
          }),
          icon: const Icon(Icons.chevron_right, color: _kGoldMid, size: 22),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildCalendarWeekHeader() {
    const days = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];
    return Row(
      children: days.map((d) => Expanded(
        child: Center(
          child: Text(d,
              style: const TextStyle(
                  color: _kTextDim, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarMonthGrid(DateTime month) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = (firstDay.weekday - 1) % 7;
    final fechaSelDate = DateTime(
        _fechaSeleccionada.year, _fechaSeleccionada.month, _fechaSeleccionada.day);

    final cells = <Widget>[];
    for (int i = 0; i < offset; i++) cells.add(const SizedBox.shrink());

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isPast = date.isBefore(today);
      final isSelected = date == fechaSelDate;
      final isToday = date == today;

      cells.add(GestureDetector(
        onTap: isPast ? null : () {
          setState(() {
            _fechaSeleccionada = date;
            _horaInicioSeleccionada = null;
            _horaFinSeleccionada = null;
          });
          _recalcularSlots();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected ? _kGoldTint : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? _kGoldDark : Colors.transparent,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isPast
                    ? _kSurface2
                    : isSelected
                        ? _kGold
                        : isToday
                            ? _kGoldMid
                            : _kTextFaint,
              ),
            ),
          ),
        ),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }

  /// Slots de hora
  Widget _buildSlots() {
    if (_barberoSeleccionado == null) {
      return const Text(
        'Selecciona un barbero primero',
        style: TextStyle(color: _kTextFaint, fontSize: 13),
      );
    }
    if (_slotsDisponibles.isEmpty) {
      return const Text(
        'Sin disponibilidad para este día',
        style: TextStyle(color: _kTextFaint, fontSize: 13),
      );
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _slotsDisponibles.map((slot) {
        final sel = slot == _horaInicioSeleccionada;
        return GestureDetector(
          onTap: () => _seleccionarSlot(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: sel ? _kGoldTint : _kSurface,
              borderRadius: BorderRadius.circular(_kRadiusSm),
              border: Border.all(color: sel ? _kGoldMid : _kBorder, width: 0.5),
            ),
            child: Text(
              _toAmPm(slot),
              style: TextStyle(
                fontSize: 13,
                fontWeight: sel ? FontWeight.w500 : FontWeight.normal,
                color: sel ? _kGold : _kTextFaint,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Fila hora inicio + fin
  Widget _buildTimeRow() => Row(
    children: [
      Expanded(
        child: _TimeBox(
          label: 'Inicio',
          value: _horaInicioSeleccionada != null
              ? _toAmPm(_horaInicioSeleccionada!)
              : '--:--',
          hasValue: _horaInicioSeleccionada != null,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: _TimeBox(
          label: 'Fin (auto)',
          value: _horaFinSeleccionada != null
              ? _toAmPm(_horaFinSeleccionada!)
              : '--:--',
          hasValue: _horaFinSeleccionada != null,
        ),
      ),
    ],
  );

  /// Caja de monto
  Widget _buildAmountBox() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: _kGoldTint,
      borderRadius: BorderRadius.circular(_kRadius),
      border: Border.all(color: _kGoldBorder, width: 0.5),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Total estimado',
          style: TextStyle(color: _kGoldText, fontSize: 12),
        ),
        Text(
          _monto != null && _monto! > 0
              ? '\$${NumberFormat('#,###', 'es_CO').format(_monto!.toInt())}'
              : '\$0',
          style: const TextStyle(
            color: _kGold,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  /// Badge de estado tap-able
  Widget _buildEstadoBadge() {
    final estado = _estadosCita[_estadoIndex];
    final isRestrictedRole = widget.role == AppRole.client || widget.role == AppRole.barber;

    return GestureDetector(
      onTap: isRestrictedRole
          ? null
          : () => setState(() {
                _estadoIndex = (_estadoIndex + 1) % _estadosCita.length;
                _estadoCita = _estadosCita[_estadoIndex]['label'] as String;
              }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(color: _kBorder, width: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Estado de la cita',
              style: TextStyle(color: _kTextMuted, fontSize: 14),
            ),
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_estadoIndex),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: estado['color'] as Color,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: estado['border'] as Color,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      estado['label'] as String,
                      style: TextStyle(
                        color: estado['textColor'] as Color,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                if (!isRestrictedRole) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: _kTextFaint, size: 20),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Botones cancelar / guardar
  Widget _buildButtons() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _kBorderHover, width: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_kRadius),
            ),
            foregroundColor: _kTextFaint,
          ),
          child: const Text(
            'Cancelar',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        flex: 2,
        child: GestureDetector(
          onTap: _isLoading ? null : _guardarAgendamiento,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_kGoldDark, _kGoldMid, _kGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(_kRadius),
            ),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF111111),
                      ),
                    )
                  : Text(
                      widget.agendamiento == null
                          ? '✓  Crear cita'
                          : '✓  Actualizar',
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    ],
  );

  // ─── UI Principal ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [
        AppRole.admin,
        AppRole.manager,
        AppRole.barber,
        AppRole.client,
      ],
      child: Scaffold(
        backgroundColor: _kBg,
        appBar: AppBar(
          backgroundColor: _kBg,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _kText),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.agendamiento == null ? 'Nueva cita' : 'Editar cita',
            style: const TextStyle(
              color: _kText,
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(0.5),
            child: Container(height: 0.5, color: _kSurface2),
          ),
          actions: [
            GestureDetector(
              onTap: _isLoading ? null : _guardarAgendamiento,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kGoldDark, _kGold]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.agendamiento == null ? 'Guardar' : 'Actualizar',
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoadingData
            ? const Center(child: CircularProgressIndicator(color: _kGoldMid))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Barbero ──
                      _sectionLabel('Barbero'),
                      widget.role == AppRole.barber
                          ? _buildSelectorCard(
                              icon: Icons.cut,
                              name:
                                  _barberoSeleccionado?.nombreCompleto ?? 'Tú',
                              hint: 'Tu perfil como barbero',
                              foto: _barberoSeleccionado?.fotoPerfil,
                              onTap: null,
                              locked: true,
                            )
                          : _barberoSeleccionado != null
                              ? _buildSelectorCard(
                                  icon: Icons.cut,
                                  name: _barberoSeleccionado!.nombreCompleto,
                                  hint: 'Barbero seleccionado',
                                  foto: _barberoSeleccionado!.fotoPerfil,
                                  onTap: () => _showBarberoSelector(),
                                )
                              : SearchableSelector<Barbero>(
                                  label: '',
                                  hint: 'Selecciona un barbero...',
                                  items: _barberos,
                                  selectedItem: _barberoSeleccionado,
                                  displayText: (b) => b.nombreCompleto,
                                  searchText: (b) => b.nombreCompleto,
                                  prefixIcon: Icons.badge_outlined,
                                  required: true,
                                  renderItem: (b) => Row(
                                    children: [
                                      _buildAvatar(
                                        b.fotoPerfil,
                                        Icons.cut,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        b.nombreCompleto,
                                        style: const TextStyle(
                                          color: _kText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onSelected: (b) {
                                    setState(() {
                                      _barberoSeleccionado = b;
                                      _horaInicioSeleccionada = null;
                                      _horaFinSeleccionada = null;
                                    });
                                    final nextWorkDay = _findFirstWorkingDay(_fechaSeleccionada);
                                    if (nextWorkDay != _fechaSeleccionada) {
                                      setState(() {
                                        _fechaSeleccionada = nextWorkDay;
                                      });
                                    }
                                    _recalculateSlotsAndRefresh();
                                  },
                                ),
                      const SizedBox(height: 20),

                      // ── Cliente ──
                      _sectionLabel('Cliente'),
                      widget.role == AppRole.client
                          ? _buildSelectorCard(
                              icon: Icons.person_outline,
                              name:
                                  _clienteSeleccionado?.nombreCompleto ?? 'Tú',
                              hint: 'Tu perfil como cliente',
                              foto: _clienteSeleccionado?.fotoPerfil,
                              onTap: null,
                              locked: true,
                            )
                          : _clienteSeleccionado != null
                              ? _buildSelectorCard(
                                  icon: Icons.person_outline,
                                  name: _clienteSeleccionado!.nombreCompleto,
                                  hint: 'Cliente seleccionado',
                                  foto: _clienteSeleccionado!.fotoPerfil,
                                  onTap: () => _showClienteSelector(),
                                )
                              : SearchableSelector<Cliente>(
                                  label: '',
                                  hint: 'Selecciona un cliente...',
                                  items: _clientes,
                                  selectedItem: _clienteSeleccionado,
                                  displayText: (c) => c.nombreCompleto,
                                  searchText: (c) => c.nombreCompleto,
                                  prefixIcon: Icons.person_outline,
                                  required: true,
                                  renderItem: (c) => Row(
                                    children: [
                                      _buildAvatar(
                                        c.fotoPerfil,
                                        Icons.person_outline,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        c.nombreCompleto,
                                        style: const TextStyle(
                                          color: _kText,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onSelected: (c) =>
                                      setState(() => _clienteSeleccionado = c),
                                ),

                      _buildDivider(),

                      // ── Tipo de cita ──
                      _sectionLabel('Tipo de cita'),
                      _buildTypeToggle(),
                      const SizedBox(height: 16),
                      _esServicio
                          ? _buildServiciosList()
                          : _buildPaqueteSelector(),

                      _buildDivider(),

                      // ── Productos (solo si hay servicio o paquete seleccionado) ──
                      if (_serviciosSeleccionados.isNotEmpty || _paqueteSeleccionado != null) ...[
                        _sectionLabel('Productos (opcional)'),
                        _buildProductosSection(),
                        _buildDivider(),
                      ] else
                        _buildDivider(),

                      // ── Fecha y hora ──
                      _sectionLabel('Fecha y hora'),
                      _buildDateTimePickerCard(),
                      const SizedBox(height: 16),
                      _buildAmountBox(),

                      _buildDivider(),

                      // ── Estado ──
                      _buildEstadoBadge(),
                      const SizedBox(height: 20),

                      // ── Observaciones ──
                      _sectionLabel('Observaciones'),
                      TextFormField(
                        initialValue: _observaciones ?? '',
                        maxLines: 3,
                        style: const TextStyle(
                          color: _kTextMuted,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'Agrega notas o instrucciones para el barbero...',
                          hintStyle: const TextStyle(
                            color: Color(0xFF444444),
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: _kSurface,
                          contentPadding: const EdgeInsets.all(14),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_kRadius),
                            borderSide: BorderSide(color: _kBorder, width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_kRadius),
                            borderSide: BorderSide(color: _kBorder, width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(_kRadius),
                            borderSide: const BorderSide(
                              color: _kGoldDark,
                              width: 0.5,
                            ),
                          ),
                        ),
                        onChanged: (v) => _observaciones = v,
                      ),
                      const SizedBox(height: 32),

                      // ── Botones ──
                      _buildButtons(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String formatSpanishDate(DateTime date) {
    final raw = DateFormat("EEEE, d 'de' MMMM", 'es').format(date);
    if (raw.isEmpty) return '';
    return raw[0].toUpperCase() + raw.substring(1);
  }

  String _getBarberWorkHoursString(DateTime date) {
    if (_barberoSeleccionado == null) return '';
    final dartDow = date.weekday;
    final fechaStr = DateFormat('yyyy-MM-dd').format(date);

    final horarioSemanal = _todosLosHorarios.where((h) {
      if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
      if (h.estado != 'Activo') return false;
      if (h.fechaInicioSemana.compareTo(fechaStr) <= 0 && h.fechaFinSemana.compareTo(fechaStr) >= 0) return true;
      return false;
    }).toList();

    final horariosBarbero = horarioSemanal.expand((h) => h.detalles).where((d) {
      return d.diaSemana == dartDow || (dartDow == 7 && d.diaSemana == 0);
    }).toList();

    if (horariosBarbero.isEmpty) return 'No trabaja';

    return horariosBarbero.map((d) => "${_toAmPm(d.horaInicio)} - ${_toAmPm(d.horaFin)}").join(', ');
  }

  DateTime _findFirstWorkingDay(DateTime start) {
    if (_barberoSeleccionado == null) return start;
    DateTime date = start;
    for (int i = 0; i < 7; i++) {
      if (_getBarberWorkHoursString(date) != 'No trabaja') {
        return date;
      }
      date = date.add(const Duration(days: 1));
    }
    return start;
  }


  Widget _buildDateTimePickerCard() {
    final dateStr = formatSpanishDate(_fechaSeleccionada);
    
    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(
        0,
        (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30),
      );
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30;

    String timeStr = 'Seleccionar hora';
    if (_horaInicioSeleccionada != null) {
      final startFormatted = _toAmPm(_horaInicioSeleccionada!);
      if (_horaFinSeleccionada != null) {
        final endFormatted = _toAmPm(_horaFinSeleccionada!);
        timeStr = '$startFormatted - $endFormatted';
      } else {
        timeStr = startFormatted;
      }
    }

    final now = DateTime.now();
    final isToday = _fechaSeleccionada.year == now.year &&
        _fechaSeleccionada.month == now.month &&
        _fechaSeleccionada.day == now.day;
    
    bool isTimeInvalid = false;
    if (isToday && _horaInicioSeleccionada != null) {
      final startMin = _toMinutes(_horaInicioSeleccionada!);
      final currentMin = now.hour * 60 + now.minute;
      if (startMin < currentMin + 30) {
        isTimeInvalid = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(
              color: isTimeInvalid ? const Color(0xFFB07070) : _kBorder,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_outlined,
                color: _horaInicioSeleccionada != null ? _kGold : _kTextDim,
                size: 20,
              ),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () {
                  if (_barberoSeleccionado == null) {
                    _mostrarError("Selecciona un barbero primero");
                    return;
                  }
                  _showDatePickerSheet();
                },
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    color: _kText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                '|',
                style: TextStyle(color: _kTextDim.withOpacity(0.3), fontSize: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (_barberoSeleccionado == null) {
                      _mostrarError("Selecciona un barbero primero");
                      return;
                    }
                    _showTimePickerSheet();
                  },
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      color: isTimeInvalid 
                          ? const Color(0xFFB07070) 
                          : (_horaInicioSeleccionada != null ? _kText : _kTextDim),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isToday) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: isTimeInvalid ? const Color(0xFFB07070) : _kGoldMid,
              ),
              const SizedBox(width: 6),
              Text(
                'Se requiere 30 min de anticipación para hoy',
                style: TextStyle(
                  color: isTimeInvalid ? const Color(0xFFB07070) : _kGoldMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showDatePickerSheet() {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    DateTime temp = _fechaSeleccionada;
    if (temp.isBefore(todayNorm)) {
      temp = todayNorm;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 12,
          right: 12,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: const Color(0xFF1A1919),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              StatefulBuilder(builder: (ctx, setSheet) {
                final workHours = _getBarberWorkHoursString(temp);
                final worksThisDay = workHours != 'No trabaja';

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatSpanishDate(temp),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            worksThisDay
                                ? "Horario de trabajo: $workHours"
                                : "El barbero no trabaja este día",
                            style: TextStyle(
                              color: worksThisDay ? _kGoldMid : const Color(0xFFB07070),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: temp,
                        minimumDate: todayNorm,
                        maximumDate: todayNorm.add(const Duration(days: 365)),
                        minimumYear: todayNorm.year,
                        maximumYear: todayNorm.year + 1,
                        backgroundColor: Colors.transparent,
                        onDateTimeChanged: (dt) {
                          temp = dt;
                          setSheet(() {});
                        },
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF2D2D2D)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(color: _kGold, fontSize: 17),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 48, color: _kBorder),
                          Expanded(
                            child: TextButton(
                              onPressed: !worksThisDay ? null : () {
                                setState(() {
                                  _fechaSeleccionada = temp;
                                  _horaInicioSeleccionada = null;
                                  _horaFinSeleccionada = null;
                                });
                                _recalcularSlots();
                                Navigator.pop(ctx);
                              },
                              child: Text(
                                "Aceptar",
                                style: TextStyle(
                                    color: worksThisDay ? _kGold : _kTextDim,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimePickerSheet() {
    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    
    DateTime temp = _fechaSeleccionada;
    if (_horaInicioSeleccionada != null) {
      final parts = _horaInicioSeleccionada!.split(':');
      temp = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
    } else {
      temp = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        now.hour,
        ((now.minute + 15) ~/ 15) * 15,
      );
      if (temp.isBefore(now.add(const Duration(minutes: 30)))) {
        temp = now.add(const Duration(minutes: 30));
        // Ajustar a los próximos 15 minutos para que se vea limpio
        int nextMin = ((temp.minute + 14) ~/ 15) * 15;
        temp = DateTime(temp.year, temp.month, temp.day, temp.hour, nextMin);
      }
    }

    int durMin = 0;
    if (_esServicio && _serviciosSeleccionados.isNotEmpty) {
      durMin = _serviciosSeleccionados.fold(
        0,
        (sum, s) => sum + (s.duracionMinutos > 0 ? s.duracionMinutos : 30),
      );
    } else if (!_esServicio && _paqueteSeleccionado != null) {
      durMin = _paqueteSeleccionado!.duracionMinutos > 0
          ? _paqueteSeleccionado!.duracionMinutos
          : 60;
    }
    if (durMin == 0) durMin = 30;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 12,
          right: 12,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: const Color(0xFF1A1919),
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              StatefulBuilder(builder: (ctx, setSheet) {
                final timeInicioStr = "${temp.hour.toString().padLeft(2, '0')}:${temp.minute.toString().padLeft(2, '0')}";
                final timeFinStr = _fromMinutes(_toMinutes(timeInicioStr) + durMin);
                final previewLabel = "${formatSpanishDate(temp)}  ${_toAmPm(timeInicioStr)} - ${_toAmPm(timeFinStr)}";

                // Consultar disponibilidad
                final isWorkDay = _getBarberWorkHoursString(temp) != 'No trabaja';
                
                String statusMsg = '';
                bool isAvailable = false;
                Color statusColor = _kGoldMid;

                if (!isWorkDay) {
                  statusMsg = "El barbero no trabaja este día";
                  statusColor = const Color(0xFFB07070);
                } else {
                  final dartDow = temp.weekday;
                  final fechaStr = DateFormat('yyyy-MM-dd').format(temp);
                  final horarioSemanal = _todosLosHorarios.where((h) {
                    if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
                    if (h.estado != 'Activo') return false;
                    if (h.fechaInicioSemana.compareTo(fechaStr) <= 0 && h.fechaFinSemana.compareTo(fechaStr) >= 0) return true;
                    return false;
                  }).toList();

                  final horariosBarbero = horarioSemanal.expand((h) => h.detalles).where((d) {
                    return d.diaSemana == dartDow || (dartDow == 7 && d.diaSemana == 0);
                  }).toList();

                  final startMin = _toMinutes(timeInicioStr);
                  final endMin = _toMinutes(timeFinStr);

                  final isToday = temp.year == now.year && temp.month == now.month && temp.day == now.day;
                  final currentMin = now.hour * 60 + now.minute;

                  bool fitsWorkHours = false;
                  for (final h in horariosBarbero) {
                    final shiftStart = _toMinutes(h.horaInicio);
                    final shiftEnd = _toMinutes(h.horaFin);
                    if (startMin >= shiftStart && endMin <= shiftEnd) {
                      fitsWorkHours = true;
                      break;
                    }
                  }

                  if (isToday && startMin < currentMin + 30) {
                    statusMsg = "Solo se puede hacer una cita con 30 min de anticipación";
                    statusColor = const Color(0xFFB07070);
                    isAvailable = false;
                  } else if (!fitsWorkHours) {
                    final workingHoursStr = horariosBarbero.map((d) => "${_toAmPm(d.horaInicio)} - ${_toAmPm(d.horaFin)}").join(', ');
                    statusMsg = "Fuera de horario (Trabaja: $workingHoursStr)";
                    statusColor = const Color(0xFFB07070);
                  } else {
                    final citasBarberoHoy = _todasLasCitas.where((c) {
                      if (c.barberoId != _barberoSeleccionado!.id) return false;
                      if (c.estado?.toLowerCase() == 'cancelada' ||
                          c.estadoCita?.toLowerCase() == 'cancelada')
                        return false;
                      String fCita = c.fechaCita ?? '';
                      if (fCita.isEmpty && c.fechaHora != null && c.fechaHora!.contains('T')) {
                        fCita = c.fechaHora!.split('T')[0];
                      }
                      if (fCita != fechaStr) return false;
                      if (c.id != null && widget.agendamiento != null && c.id == widget.agendamiento!.id)
                        return false;
                      return true;
                    }).toList();

                    bool overlaps = false;
                    for (final c in citasBarberoHoy) {
                      if (c.horaInicio == null || c.horaInicio!.isEmpty) continue;
                      int startExist = _toMinutes(c.horaInicio!);
                      int endExist = (c.horaFin != null && c.horaFin!.isNotEmpty)
                          ? _toMinutes(c.horaFin!)
                          : startExist + 60;
                      if (startMin < endExist && startExist < endMin) {
                        overlaps = true;
                        break;
                      }
                    }

                    if (overlaps) {
                      statusMsg = "Ya tiene otra cita en este horario";
                      statusColor = const Color(0xFFB07070);
                    } else {
                      statusMsg = "Horario disponible";
                      statusColor = const Color(0xFF5EAA7C);
                      isAvailable = true;
                    }
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            previewLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusMsg,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.dateAndTime,
                        initialDateTime: temp,
                        minimumDate: todayNorm,
                        maximumDate: todayNorm.add(const Duration(days: 365)),
                        minimumYear: todayNorm.year,
                        maximumYear: todayNorm.year + 1,
                        backgroundColor: Colors.transparent,
                        onDateTimeChanged: (dt) {
                          temp = dt;
                          setSheet(() {});
                        },
                      ),
                    ),
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF2D2D2D)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                "Cancelar",
                                style: TextStyle(color: _kGold, fontSize: 17),
                              ),
                            ),
                          ),
                          Container(width: 1, height: 48, color: _kBorder),
                          Expanded(
                            child: TextButton(
                              onPressed: !isAvailable ? null : () {
                                final selectedInicio = "${temp.hour.toString().padLeft(2, '0')}:${temp.minute.toString().padLeft(2, '0')}";
                                final selectedFin = _fromMinutes(_toMinutes(selectedInicio) + durMin);

                                setState(() {
                                  _fechaSeleccionada = DateTime(temp.year, temp.month, temp.day);
                                  _horaInicioSeleccionada = selectedInicio;
                                  _horaFinSeleccionada = selectedFin;
                                });
                                Navigator.pop(ctx);
                              },
                              child: Text(
                                "Aceptar",
                                style: TextStyle(
                                    color: isAvailable ? _kGold : _kTextDim,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(color: const Color(0xFF3A3A3A), thickness: 0.5, height: 0),
  );
}

// ─── Sub-widgets reutilizables ─────────────────────────────────────────────────

class _ServiceChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _ServiceChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
      decoration: BoxDecoration(
        color: _kGoldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF6A4A15), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _kGold,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: _kGoldText),
          ),
        ],
      ),
    );
  }
}

class _TimeBox extends StatelessWidget {
  final String label;
  final String value;
  final bool hasValue;
  const _TimeBox({
    required this.label,
    required this.value,
    required this.hasValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _kTextDim, fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: hasValue ? _kText : _kTextFaint,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyControl extends StatefulWidget {
  final int productId;
  final int value;
  final int maxValue;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final ValueChanged<String>? onChanged;
  final bool isError;

  const _QtyControl({
    required this.productId,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
    this.maxValue = 9999,
    this.onChanged,
    this.isError = false,
  });

  @override
  State<_QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<_QtyControl> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(_QtyControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value.toString() != _controller.text) {
      _controller.text = widget.value.toString();
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final atLimit = widget.maxValue > 0 && widget.value >= widget.maxValue;
    final textLen = widget.value.toString().length;
    final width = 24.0 + (textLen * 8.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _QtyBtn(icon: Icons.remove, onTap: widget.onDecrement),
            const SizedBox(width: 4),
            SizedBox(
              width: width.clamp(32.0, 60.0),
              child: TextFormField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: atLimit ? const Color(0xFFB07070) : _kText,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                ),
                onChanged: widget.onChanged,
              ),
            ),
            const SizedBox(width: 4),
            _QtyBtn(
              icon: Icons.add,
              onTap: widget.onIncrement,
              disabled: atLimit,
            ),
          ],
        ),
        if (atLimit) ...[
          const SizedBox(height: 3),
          Text(
            'Has llegado al límite',
            style: const TextStyle(
              color: Color(0xFFB07070),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;
  const _QtyBtn({required this.icon, required this.onTap, this.disabled = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: disabled ? _kSurface : _kSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: disabled ? const Color(0xFF552020) : _kBorder,
            width: 0.5,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: disabled ? const Color(0xFFB07070).withOpacity(0.4) : _kGoldMid,
        ),
      ),
    );
  }
}



