import 'dart:convert';
import 'package:flutter/material.dart';
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

// ─── Theme constants ─────────────────────────────────────────────────────────

const _kBg = Color(0xFF0A0A0A);
const _kSurface = Color(0xFF141414);
const _kSurface2 = Color(0xFF1A1A1A);
const _kBorder = Color(0xFF252525);
const _kBorderHover = Color(0xFF3A3A3A);
const _kGold = Color(0xFFE0C070);
const _kGoldMid = Color(0xFFC9A04E);
const _kGoldDark = Color(0xFF9A6A25);
const _kGoldTint = Color(0xFF1A1408);
const _kGoldBorder = Color(0xFF4A3010);
const _kGoldText = Color(0xFF9A7030);
const _kText = Colors.white;
const _kTextMuted = Color(0xFFAAAAAA);
const _kTextDim = Color(0xFF666666);
const _kTextFaint = Color(0xFF444444);
const _kRadius = 14.0;
const _kRadiusMd = 10.0;
const _kRadiusSm = 8.0;

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
  List<HorarioBarbero> _todosLosHorarios = [];

  Cliente? _clienteSeleccionado;
  Barbero? _barberoSeleccionado;
  List<Servicio> _serviciosSeleccionados = [];
  Paquete? _paqueteSeleccionado;
  Map<int, int> _productoCantidades = {};
  bool _esServicio = true;

  DateTime _fechaSeleccionada = DateTime.now().add(const Duration(days: 1));
  String? _horaInicioSeleccionada;
  String? _horaFinSeleccionada;
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
      'color': const Color(0xFF1E1810),
      'textColor': _kGoldMid,
      'border': const Color(0xFF4A3A15),
    },
    {
      'label': 'Completada',
      'color': const Color(0xFF0F1E14),
      'textColor': const Color(0xFF5EAA7C),
      'border': const Color(0xFF1F5535),
    },
    {
      'label': 'Cancelada',
      'color': const Color(0xFF1E0F0F),
      'textColor': const Color(0xFFAA5E5E),
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
        ProductoService().getProductos(pageSize: 1000),
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
        _productos = results[4] as List<Producto>;
        _todasLasCitas = (results[5] as Paginacion<Agendamiento>).items;
        _todosLosHorarios = results[6] as List<HorarioBarbero>;
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
      _mostrarError('Error al cargar datos: $e');
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
    final dartDow = _fechaSeleccionada.weekday;
    final apiDow = dartDow % 7;

    final horariosBarbero = _todosLosHorarios.where((h) {
      if (h.barberoId != (_barberoSeleccionado!.id ?? 0)) return false;
      return h.diaSemana == apiDow || (dartDow == 7 && h.diaSemana == 7);
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
    final String fechaStr = DateFormat('yyyy-MM-dd').format(_fechaSeleccionada);

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
        if (isToday && cursor <= currentMin + 30) solapa = true;
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
              ? '✅ Cita creada exitosamente'
              : '✅ Cita actualizada',
        );
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

  /// Avatar o icono fallback
  Widget _buildAvatar(String? foto, IconData fallback, {double size = 36}) {
    if (foto == null || foto.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2D2D2D), width: 0.5),
        ),
        child: Icon(fallback, color: const Color(0xFF888888), size: size * 0.5),
      );
    }

    Widget image;
    if (foto.startsWith('http')) {
      image = Image.network(
        foto,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Icon(fallback, color: const Color(0xFF888888), size: size * 0.5),
      );
    } else {
      try {
        // Asumimos base64 si no es URL
        final cleanBase64 = foto.contains(',') ? foto.split(',')[1] : foto;
        image = Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(fallback, color: const Color(0xFF888888), size: size * 0.5),
        );
      } catch (_) {
        image = Icon(
          fallback,
          color: const Color(0xFF888888),
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
        border: Border.all(color: const Color(0xFF2D2D2D), width: 0.5),
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

  /// Selector de servicios searchable
  Widget _buildServiciosList() => SearchableSelector<Servicio>(
    label: '',
    hint: 'Buscar y añadir servicios...',
    items: _servicios,
    selectedItem: null,
    displayText: (s) => s.nombre,
    searchText: (s) => s.nombre,
    prefixIcon: Icons.cut,
    required: _serviciosSeleccionados.isEmpty,
    renderItem: (s) {
      final isSelected = _serviciosSeleccionados.any((sel) => sel.id == s.id);
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _kGoldTint : _kSurface,
          borderRadius: BorderRadius.circular(_kRadius),
          border: Border.all(
            color: isSelected ? _kGoldDark : _kBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? _kGoldMid : const Color(0xFF333333),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.nombre,
                    style: TextStyle(
                      color: isSelected ? _kText : _kTextMuted,
                      fontSize: 14,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${s.duracionMinutos} min · \$${s.precio.toStringAsFixed(0)}',
                    style: const TextStyle(color: _kTextDim, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check : Icons.add,
              size: 16,
              color: isSelected ? _kGoldMid : _kTextFaint,
            ),
          ],
        ),
      );
    },
    onSelected: (s) {
      if (s != null) {
        setState(() {
          if (!_serviciosSeleccionados.any((sel) => sel.id == s.id)) {
            _serviciosSeleccionados.add(s);
            _calcularTotal();
            _horaInicioSeleccionada = null;
            _horaFinSeleccionada = null;
          }
        });
        _recalcularSlots();
      }
    },
  );

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

  /// Sección de productos
  Widget _buildProductosSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SearchableSelector<Producto>(
        label: '',
        hint: 'Añadir producto...',
        items: _productos,
        selectedItem: null,
        displayText: (p) => p.nombre,
        searchText: (p) => p.nombre,
        prefixIcon: Icons.shopping_bag_outlined,
        required: false,
        renderItem: (p) => Row(
          children: [
            Expanded(
              child: Text(
                p.nombre,
                style: const TextStyle(color: _kText, fontSize: 14),
              ),
            ),
            Text(
              '\$${p.precioVenta.toStringAsFixed(0)}',
              style: const TextStyle(color: _kGoldText, fontSize: 12),
            ),
          ],
        ),
        onSelected: (p) {
          if (p != null) {
            setState(() {
              _productoCantidades[p.id!] =
                  (_productoCantidades[p.id!] ?? 0) + 1;
              _calcularTotal();
            });
          }
        },
      ),
      if (_productoCantidades.isNotEmpty) ...[
        const SizedBox(height: 8),
        ..._productoCantidades.entries.map((e) {
          final p = _productos.firstWhere(
            (prod) => prod.id == e.key,
            orElse: () =>
                Producto(nombre: 'Desconocido', categoriaId: 0, precioVenta: 0),
          );
          return Container(
            margin: const EdgeInsets.only(bottom: 1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _kSurface2, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    p.nombre,
                    style: const TextStyle(color: _kTextMuted, fontSize: 13),
                  ),
                ),
                Text(
                  '\$${(p.precioVenta * e.value).toStringAsFixed(0)}',
                  style: const TextStyle(color: _kTextDim, fontSize: 12),
                ),
                const SizedBox(width: 12),
                _QtyControl(
                  value: e.value,
                  onDecrement: () => setState(() {
                    if (e.value > 1) {
                      _productoCantidades[e.key] = e.value - 1;
                    } else {
                      _productoCantidades.remove(e.key);
                    }
                    _calcularTotal();
                  }),
                  onIncrement: () => setState(() {
                    _productoCantidades[e.key] = e.value + 1;
                    _calcularTotal();
                  }),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ],
  );

  /// Selector de semana + días
  Widget _buildDaySelector() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfCurrentWeek = today.subtract(
      Duration(days: today.weekday - 1),
    );
    final startOfNextWeek = startOfCurrentWeek.add(const Duration(days: 7));
    final fechaSelDate = DateTime(
      _fechaSeleccionada.year,
      _fechaSeleccionada.month,
      _fechaSeleccionada.day,
    );
    final isNextWeek = !fechaSelDate.isBefore(startOfNextWeek);
    final base = isNextWeek ? startOfNextWeek : startOfCurrentWeek;

    final weekStart = base;
    final weekEnd = base.add(const Duration(days: 6));
    final monthFmt = DateFormat('d MMM', 'es_ES');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nav semana
        Row(
          children: [
            _WeekArrow(
              icon: Icons.chevron_left,
              onTap: isNextWeek
                  ? () {
                      setState(() {
                        _fechaSeleccionada = startOfCurrentWeek.add(
                          Duration(days: _fechaSeleccionada.weekday - 1),
                        );
                        _horaInicioSeleccionada = null;
                        _horaFinSeleccionada = null;
                      });
                      _recalcularSlots();
                    }
                  : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${monthFmt.format(weekStart)} – ${monthFmt.format(weekEnd)} ${weekEnd.year}',
                  style: const TextStyle(color: _kTextDim, fontSize: 13),
                ),
              ),
            ),
            _WeekArrow(
              icon: Icons.chevron_right,
              onTap: !isNextWeek
                  ? () {
                      setState(() {
                        _fechaSeleccionada = startOfNextWeek.add(
                          Duration(days: _fechaSeleccionada.weekday - 1),
                        );
                        _horaInicioSeleccionada = null;
                        _horaFinSeleccionada = null;
                      });
                      _recalcularSlots();
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Grilla 7 días
        Row(
          children: List.generate(7, (i) {
            final date = base.add(Duration(days: i));
            final isPast = date.isBefore(today);
            final isSelected = fechaSelDate == date;
            final isToday = date == today;
            const dayNames = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

            return Expanded(
              child: GestureDetector(
                onTap: isPast
                    ? null
                    : () {
                        setState(() {
                          _fechaSeleccionada = date;
                          _horaInicioSeleccionada = null;
                          _horaFinSeleccionada = null;
                        });
                        _recalcularSlots();
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _kGoldTint : Colors.transparent,
                    borderRadius: BorderRadius.circular(_kRadiusMd),
                    border: Border.all(
                      color: isSelected ? _kGoldDark : Colors.transparent,
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        dayNames[i],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? const Color(0xFF333333)
                              : isSelected
                              ? _kGoldText
                              : _kTextDim,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isPast
                              ? const Color(0xFF333333)
                              : isSelected
                              ? _kGold
                              : isToday
                              ? _kText
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
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
                color: sel ? _kGold : const Color(0xFF888888),
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
    return GestureDetector(
      onTap: () => setState(() {
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
            foregroundColor: const Color(0xFF888888),
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
            child: Container(height: 0.5, color: const Color(0xFF1F1F1F)),
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
                                _recalcularSlots();
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
                      _buildServicioChips(),

                      _buildDivider(),

                      // ── Productos ──
                      _sectionLabel('Productos (opcional)'),
                      _buildProductosSection(),

                      _buildDivider(),

                      // ── Fecha ──
                      _sectionLabel('Fecha'),
                      _buildDaySelector(),
                      const SizedBox(height: 16),
                      _sectionLabel('Horarios disponibles'),
                      _buildSlots(),
                      const SizedBox(height: 16),
                      _buildTimeRow(),
                      const SizedBox(height: 10),
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

  Widget _buildDivider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(color: Color(0xFF1A1A1A), thickness: 0.5, height: 0),
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

class _QtyControl extends StatelessWidget {
  final int value;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  const _QtyControl({
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QtyBtn(icon: Icons.remove, onTap: onDecrement),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: const TextStyle(
            color: _kText,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        _QtyBtn(icon: Icons.add, onTap: onIncrement),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _kBorder, width: 0.5),
        ),
        child: Icon(icon, size: 14, color: _kGoldMid),
      ),
    );
  }
}

class _WeekArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _WeekArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _kSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kBorder, width: 0.5),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? const Color(0xFF888888) : _kTextFaint,
        ),
      ),
    );
  }
}
