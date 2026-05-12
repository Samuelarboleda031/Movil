import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_bloc.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_event.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_state.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/ellipsis_pagination.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/dashboard_service.dart';
import 'agendamiento_detalle_screen.dart';

class AgendamientosScreen extends StatefulWidget {
  final AppRole role;

  const AgendamientosScreen({super.key, this.role = AppRole.admin}); // Default a admin por compatibilidad

  @override
  State<AgendamientosScreen> createState() => _AgendamientosScreenState();
}

class _AgendamientosScreenState extends State<AgendamientosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final BarberoService _barberoService = BarberoService();
  String _searchQuery = '';

  // Filtros de fecha para historial de barbero
  DateTime? _fechaDesde;
  DateTime? _fechaHasta;
  bool _filtroFechaActivo = false;

  // Filtros Admin
  String _filtroEstadoAdmin = 'Todos';
  int? _filtroBarberoId;
  List<Barbero> _listaBarberos = [];

  // Período para el mini dashboard de ganancias
  String _periodoGanancia = 'mensual';

  List<Agendamiento> _agendamientosFiltrados(List<Agendamiento> agendamientos) {
    var resultado = agendamientos;

    // Filtro estado Admin
    if (_filtroEstadoAdmin != 'Todos') {
      resultado = resultado.where((a) {
        final estado = (a.estadoCita ?? '').toLowerCase().trim();
        final filtro = _filtroEstadoAdmin.toLowerCase();
        
        if (filtro == 'completada') {
          return estado == 'completada' || estado == 'completado' || estado == 'finalizado' || estado == 'finalizada';
        }
        
        return estado == filtro;
      }).toList();
    }

    // Filtro barbero Admin
    if (_filtroBarberoId != null) {
      resultado = resultado.where((a) => a.barberoId == _filtroBarberoId).toList();
    }

    // Filtrar por texto de búsqueda
    final query = _searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      resultado = resultado.where((a) {
        final cliente = a.cliente?.nombreCompleto.toLowerCase() ?? a.clienteNombre?.toLowerCase() ?? '';
        final barbero = a.barbero?.nombreCompleto.toLowerCase() ?? '';
        final servicio = a.servicio?.nombre.toLowerCase() ?? '';
        final servicios = a.serviciosNombres.join(' ').toLowerCase();
        return cliente.contains(query) || barbero.contains(query) || servicio.contains(query) || servicios.contains(query);
      }).toList();
    }

    // Filtrar por rango de fechas
    if (_filtroFechaActivo && (_fechaDesde != null || _fechaHasta != null)) {
      resultado = resultado.where((a) {
        if (a.fechaCita == null || a.fechaCita!.isEmpty) return false;
        try {
          final fecha = DateTime.parse(a.fechaCita!);
          if (_fechaDesde != null) {
            final desde = DateTime(_fechaDesde!.year, _fechaDesde!.month, _fechaDesde!.day);
            if (fecha.isBefore(desde)) return false;
          }
          if (_fechaHasta != null) {
            final hasta = DateTime(_fechaHasta!.year, _fechaHasta!.month, _fechaHasta!.day, 23, 59, 59);
            if (fecha.isAfter(hasta)) return false;
          }
          return true;
        } catch (_) {
          return false;
        }
      }).toList();
    }

    return resultado;
  }

  Color _getStatusColor(String? estadoRaw) {
    final estado = (estadoRaw ?? '').toLowerCase().trim();
    if (estado == 'pendiente') {
      return AppColors.gold;
    } else if (estado == 'completada' || estado == 'completado' || estado == 'finalizado' || estado == 'finalizada') {
      return AppColors.green;
    } else if (estado == 'cancelada' || estado == 'cancelado') {
      return AppColors.red.withOpacity(0.8);
    }
    return AppColors.grey;
  }

  Widget _buildStatusBadge(String? estadoRaw) {
    final color = _getStatusColor(estadoRaw);
    String label = estadoRaw ?? 'Sin estado';
    if (label.toLowerCase() == 'finalizado') label = 'Completada';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  bool get _hayFiltrosAdminActivos => _filtroEstadoAdmin != 'Todos' || _filtroBarberoId != null || _fechaDesde != null || _searchQuery.isNotEmpty;

  void _limpiarFiltrosAdmin() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filtroEstadoAdmin = 'Todos';
      _filtroBarberoId = null;
      _fechaDesde = null;
      _fechaHasta = null;
      _filtroFechaActivo = false;
    });
  }

  Future<void> _seleccionarFechasAdmin() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      initialDateRange: _fechaDesde != null && _fechaHasta != null ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!) : null,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.gold, onPrimary: AppColors.bg, surface: AppColors.card, onSurface: AppColors.white)),
        child: child!,
      ),
    );
    if (rango != null) {
      setState(() { _fechaDesde = rango.start; _fechaHasta = rango.end; _filtroFechaActivo = true; });
    }
  }

  String _periodoAdminActivo = '';

  void _setFechaRapidaAdmin(String periodo) {
    final hoy = DateTime.now();
    setState(() {
      _periodoAdminActivo = periodo;
      _filtroFechaActivo = true;
      switch (periodo) {
        case 'hoy':
          _fechaDesde = hoy;
          _fechaHasta = hoy;
          break;
        case 'semanal':
          _fechaDesde = hoy.subtract(Duration(days: hoy.weekday - 1));
          _fechaHasta = hoy;
          break;
        case 'mensual':
          _fechaDesde = DateTime(hoy.year, hoy.month, 1);
          _fechaHasta = hoy;
          break;
      }
    });
  }

  Widget _buildFiltrosAdmin() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          // Estado chips (Ocultar para clientes)
          if (widget.role != AppRole.client) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Todos', 'Pendiente', 'Completada', 'Cancelada'].map((e) {
                  final sel = _filtroEstadoAdmin == e;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(e, style: TextStyle(color: sel ? AppColors.bg : AppColors.greyLight, fontSize: 11, fontWeight: FontWeight.w600)),
                      selected: sel,
                      onSelected: (_) => setState(() => _filtroEstadoAdmin = e),
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.card,
                      side: BorderSide(color: sel ? AppColors.gold : AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      showCheckmark: false,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 10),
            // Barbero dropdown (Ocultar para clientes)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: _filtroBarberoId != null ? AppColors.gold.withOpacity(0.15) : AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _filtroBarberoId != null ? AppColors.gold : AppColors.divider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _filtroBarberoId,
                  hint: const Text('Todos los barberos', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                  isExpanded: true,
                  dropdownColor: AppColors.card,
                  icon: Icon(Icons.keyboard_arrow_down, size: 18, color: _filtroBarberoId != null ? AppColors.gold : AppColors.grey),
                  style: const TextStyle(color: AppColors.white, fontSize: 13),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todos los barberos', style: TextStyle(color: AppColors.greyLight))),
                    ..._listaBarberos.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.nombreCompleto, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: (v) => setState(() => _filtroBarberoId = v),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Fecha: rango + botones rápidos
          Row(
            children: [
              // Selector de rango
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    _periodoAdminActivo = '';
                    _seleccionarFechasAdmin();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _filtroFechaActivo && _periodoAdminActivo.isEmpty
                          ? AppColors.gold.withOpacity(0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _filtroFechaActivo && _periodoAdminActivo.isEmpty ? AppColors.gold : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 18,
                          color: _filtroFechaActivo ? AppColors.gold : AppColors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _filtroFechaActivo && _fechaDesde != null && _fechaHasta != null
                                ? '${DateFormat('dd/MM/yy').format(_fechaDesde!)} - ${DateFormat('dd/MM/yy').format(_fechaHasta!)}'
                                : 'Filtrar por fecha',
                            style: TextStyle(
                              color: _filtroFechaActivo ? AppColors.gold : AppColors.grey,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_filtroFechaActivo)
                          GestureDetector(
                            onTap: () => setState(() {
                              _fechaDesde = null; _fechaHasta = null;
                              _filtroFechaActivo = false; _periodoAdminActivo = '';
                            }),
                            child: Icon(Icons.close, size: 16, color: AppColors.gold.withOpacity(0.8)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Hoy
              _buildQuickDateBtn('Hoy', 'hoy'),
              const SizedBox(width: 8),
              // Esta semana
              _buildQuickDateBtn('Semana', 'semanal'),
              const SizedBox(width: 8),
              // Este mes
              _buildQuickDateBtn('Mes', 'mensual'),
            ],
          ),
          if (_hayFiltrosAdminActivos) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _limpiarFiltrosAdmin,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.clear, size: 14, color: AppColors.gold),
                      SizedBox(width: 4),
                      Text('Limpiar filtros', style: TextStyle(fontSize: 12, color: AppColors.gold)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickDateBtn(String label, String periodo) {
    final sel = _periodoAdminActivo == periodo && _filtroFechaActivo;
    return GestureDetector(
      onTap: () => _setFechaRapidaAdmin(periodo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.gold.withOpacity(0.2) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? AppColors.gold : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(color: sel ? AppColors.gold : AppColors.grey, fontSize: 12),
        ),
      ),
    );
  }
  
  void _limpiarFiltrosFecha() {
    setState(() {
      _fechaDesde = null;
      _fechaHasta = null;
      _filtroFechaActivo = false;
      // Volver al período mensual por defecto
      _periodoGanancia = 'mensual';
    });
  }
  
  Future<void> _seleccionarRangoFechas() async {
    final DateTimeRange? rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _fechaDesde != null && _fechaHasta != null
          ? DateTimeRange(start: _fechaDesde!, end: _fechaHasta!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.card,
              foregroundColor: AppColors.white,
            ),
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
    
    if (rango != null) {
      final diff = rango.end.difference(rango.start).inDays;
      setState(() {
        _fechaDesde = rango.start;
        _fechaHasta = rango.end;
        _filtroFechaActivo = true;
        
        // Auto-detectar período según el rango seleccionado
        if (diff == 0) {
          _periodoGanancia = 'hoy';
        } else if (diff <= 7) {
          _periodoGanancia = 'semanal';
        } else if (diff <= 31) {
          _periodoGanancia = 'mensual';
        } else {
          _periodoGanancia = 'anual';
        }
      });
    }
  }

  // Devolver todas las citas sin filtrar por estado
  List<Agendamiento> _getCitasFinalizadas(List<Agendamiento> agendamientos) {
    print('🔍 Total de citas recibidas: ${agendamientos.length}');
    return agendamientos;
  }

  // Calcular ganancias aplicando filtros de fecha seleccionados
  double _calcularGananciasFiltradas(List<Agendamiento> agendamientos) {
    return agendamientos.where((a) {
      final estado = (a.estadoCita ?? '').toLowerCase();
      if (estado != 'finalizado' && estado != 'completada' && estado != 'completado') return false;
      
      // Aplicar filtro de fecha si está activo
      if (_filtroFechaActivo && (_fechaDesde != null || _fechaHasta != null)) {
        if (a.fechaCita == null || a.fechaCita!.isEmpty) return false;
        try {
          final fecha = DateTime.parse(a.fechaCita!);
          if (_fechaDesde != null) {
            final desde = DateTime(_fechaDesde!.year, _fechaDesde!.month, _fechaDesde!.day);
            if (fecha.isBefore(desde)) return false;
          }
          if (_fechaHasta != null) {
            final hasta = DateTime(_fechaHasta!.year, _fechaHasta!.month, _fechaHasta!.day, 23, 59, 59);
            if (fecha.isAfter(hasta)) return false;
          }
          return true;
        } catch (_) {
          return false;
        }
      }
      
      // Si no hay filtro activo, usar última semana por defecto
      final ahora = DateTime.now();
      final inicioSemana = ahora.subtract(const Duration(days: 7));
      try {
        final fechaCita = DateTime.parse(a.fechaCita ?? '');
        return fechaCita.isAfter(inicioSemana) || fechaCita.isAtSameMomentAs(inicioSemana);
      } catch (_) {
        return false;
      }
    }).fold(0.0, (sum, a) => sum + (a.monto ?? a.precio ?? 0));
  }

  Future<void> _verDetalles(Agendamiento ag) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgendamientoDetalleScreen(
          agendamiento: ag,
          role: widget.role,
        ),
      ),
    ).then((_) {
      // Opcional: Recargar si hubo cambios manteniendo el modo actual
      final state = context.read<AgendamientosBloc>().state;
      if (state is AgendamientosLoaded) {
        context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(
          page: state.currentPage, 
          estaSemana: state.isWeeklyMode
        ));
      } else {
        context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
      }
    });
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


  Future<void> _cancelarAgendas() async {
    // Si es barbero, obtener su propio ID y no mostrar selector de barberos
    Barbero? barberoSeleccionado;
    bool esBarberoRol = widget.role == AppRole.barber;
    
    if (esBarberoRol) {
      // Obtener el barbero actual del contexto
      final userContext = UserContextService();
      final barberoActual = await userContext.obtenerBarberoActual();
      if (barberoActual != null && barberoActual.id != null) {
        barberoSeleccionado = barberoActual;
      } else {
        AppToast.showError(context, 'No se pudo obtener tu información de barbero');
        return;
      }
    } else {
      // Para admin/manager, mostrar selector de barberos
      final barberosRaw = await _barberoService.obtenerBarberos();
      final List<Barbero> opcionesBarberos = [
        Barbero(id: -1, nombre: 'Todos los barberos', apellido: '', documento: '', telefono: '', email: '', direccion: '', estado: true),
        ...barberosRaw
      ];
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final esGlobal = barberoSeleccionado?.id == -1;
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD8B081), width: 0.5)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(esBarberoRol ? 'CANCELAR MIS CITAS' : (esGlobal ? 'CANCELACIÓN GLOBAL' : 'CANCELAR POR BARBERO'), 
                    style: TextStyle(color: esGlobal ? Colors.orange : const Color(0xFFD8B081), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(esBarberoRol ? 'Selecciona los días a cancelar:' : 'Selecciona barbero y días:', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Solo mostrar selector de barberos si NO es rol barbero
                    if (!esBarberoRol) ...[
                      FutureBuilder<List<Barbero>>(
                        future: _barberoService.obtenerBarberos(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator(color: AppColors.gold);
                          }
                          final opcionesBarberos = [
                            Barbero(id: -1, nombre: 'Todos los barberos', apellido: '', documento: '', telefono: '', email: '', direccion: '', estado: true),
                            ...snapshot.data!
                          ];
                          return SearchableSelector<Barbero>(
                            label: 'Barbero',
                            hint: 'Seleccionar...',
                            items: opcionesBarberos,
                            selectedItem: barberoSeleccionado,
                            displayText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                            searchText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                            onSelected: (b) => setStateDialog(() => barberoSeleccionado = b),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Si es barbero, mostrar su nombre
                    if (esBarberoRol && barberoSeleccionado != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.person, color: AppColors.gold),
                            const SizedBox(width: 8),
                            Text(
                              'Barbero: ${barberoSeleccionado?.nombreCompleto ?? 'Yo'}',
                              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    if (esBarberoRol) const SizedBox(height: 16),
                    DaySelectorWidget(
                      isGlobal: esGlobal,
                      onConfirm: (dates, motivo, {horaInicio, horaFin}) {
                         if (barberoSeleccionado != null && dates.isNotEmpty) {
                           Navigator.pop(context, {
                             'barbero': barberoSeleccionado, 
                             'fechas': dates, 
                             'motivo': motivo, 
                             'horaInicio': horaInicio, 
                             'horaFin': horaFin
                           });
                         } else {
                           AppToast.showError(context, 'Rellena todos los datos necesarios');
                         }
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      }
    );

    if (result == null) return;
    final Barbero b = result['barbero'];
    final List<DateTime> dates = result['fechas'];
    final String motivo = result['motivo'];
    
    if (mounted) {
      context.read<AgendamientosBloc>().add(CancelDiasRequested(
        barberoId: b.id!,
        fechas: dates,
        motivo: motivo,
        horaInicio: result['horaInicio'],
        horaFin: result['horaFin'],
      ));
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.clear();
    _searchQuery = '';
    _fechaDesde = null;
    _fechaHasta = null;
    _filtroFechaActivo = false;
    if (widget.role != AppRole.barber) _cargarBarberos();
  }

  Future<void> _cargarBarberos() async {
    try {
      final barberos = await _barberoService.obtenerBarberos();
      if (mounted) setState(() => _listaBarberos = barberos);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si es barbero, mostrar diseño de historial
    if (widget.role == AppRole.barber) {
      return _buildBarberoHistorialView();
    }
    
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber, AppRole.client],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Citas'),
          actions: const [],
        ),

        body: BlocConsumer<AgendamientosBloc, AgendamientosState>(
          listener: (context, state) {
            if (state is AgendamientosError) {
              AppToast.showError(context, state.message);
            } else if (state is AgendamientosActionSuccess) {
              AppToast.showSuccess(context, state.message);
            }
          },
          builder: (context, state) {
            bool isLoading = state is AgendamientosInitial || state is AgendamientosLoading || state is AgendamientosActionLoading;
            List<Agendamiento> agendamientos = [];
            Paginacion<Agendamiento>? paginacion;
            int currentPage = 1;
            bool isWeeklyMode = false;
            int totalItems = 0;

            if (state is AgendamientosLoaded) {
              agendamientos = state.agendamientos;
              paginacion = state.paginacion;
              currentPage = state.currentPage;
              isWeeklyMode = state.isWeeklyMode;
              totalItems = paginacion?.totalCount ?? agendamientos.length;
            }

            final filtrados = _agendamientosFiltrados(agendamientos);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                _buildFiltrosAdmin(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtrados.isEmpty
                          ? const Center(
                              child: Text('No hay agendamientos registrados', style: TextStyle(color: AppColors.grey)),
                            )
                          : Builder(
                              builder: (context) {
                                return RefreshIndicator(
                                  onRefresh: () async {
                                    context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1, estaSemana: false));
                                  },
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                    itemCount: filtrados.length + ((paginacion != null && paginacion.totalPages > 1) ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == filtrados.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                                          child: _buildPaginationControls(paginacion!.totalPages, currentPage),
                                        );
                                      }
                                      final ag = filtrados[index];
                                      return _buildAdminCitaCard(ag);
                                    },
                                  ),
                                );
                              }
                            ),
                    ),


              ],
            );
          },
        ),
      ),
    );
  }

  // ── TARJETA DE CITA PARA ADMIN ─────────────────────────────────────────
  Widget _buildAdminCitaCard(Agendamiento cita) {
    // Formatear hora a 12h
    String horaFormateada = AppFormat.to12h(cita.horaInicio ?? '');
    String amPm = '';
    if (horaFormateada.contains(' ')) {
      final parts = horaFormateada.split(' ');
      horaFormateada = parts[0];
      amPm = parts[1];
    }

    // Formatear fecha
    String fechaFormateada = '';
    if (cita.fechaCita != null && cita.fechaCita!.isNotEmpty) {
      try {
        final fecha = DateTime.parse(cita.fechaCita!);
        final meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
        fechaFormateada = '${fecha.day} ${meses[fecha.month - 1]} ${fecha.year}';
      } catch (e) {
        fechaFormateada = cita.fechaCita!;
      }
    }

    // Obtener nombre del cliente
    final nombreCliente = cita.clienteNombre ?? 
                         cita.cliente?.nombreCompleto ?? 
                         'Cliente';

    // Obtener nombre del servicio
    String servicio = '';
    if (cita.serviciosNombres.isNotEmpty) {
      servicio = cita.serviciosNombres.join(' + ');
    } else if (cita.servicio?.nombre != null) {
      servicio = cita.servicio!.nombre;
    } else {
      servicio = 'Servicio';
    }

    // Obtener nombre del barbero
    final nombreBarbero = cita.barbero?.nombreCompleto ?? 
                         cita.barbero?.nombre ?? 
                         'Barbero';

    // Precio
    final precio = cita.precio ?? cita.monto ?? 0;

    final statusColor = _getStatusColor(cita.estadoCita);

    return GestureDetector(
      onTap: () => _verDetalles(cita),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            if (statusColor != AppColors.grey)
              BoxShadow(
                color: statusColor.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Indicador de estado lateral
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: statusColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
            // Columna de hora y fecha
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horaFormateada,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    amPm,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fechaFormateada,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.grey,
                    ),
                  ),
                ],
              ),
            ),
            // Separador vertical
            Container(
              width: 1,
              height: 55,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.divider,
            ),
            // Información del cliente, servicio y barbero
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombreCliente,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(cita.estadoCita),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    servicio,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.grey.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Barbero: $nombreBarbero',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Precio y flecha
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormat.cop(precio.toDouble()),
                  style: const TextStyle(
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.gold,
                  size: 24,
                ),
              ],
            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cambiarEstado(Agendamiento ag) async {
    // Si es cliente, solo puede ver y quizá cancelar si quisiéramos habilitar, 
    // pero basado en su código previo, el cliente solo puede cancelar o el negocio se lo cambia.
    // Usaremos los estados correspondientes:
    final estados = widget.role == AppRole.client 
          ? ['Pendiente', 'Cancelado'] 
          : ['Pendiente', 'Confirmado', 'En Proceso', 'Finalizado', 'No Asistio', 'Cancelado'];
    
    final nuevoEstado = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Seleccionar Estado'),
        children: estados.map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, e),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(e, style: TextStyle(
              color: ag.estadoCita == e ? const Color(0xFFD8B081) : Colors.white,
              fontWeight: ag.estadoCita == e ? FontWeight.bold : FontWeight.normal,
            )),
          ),
        )).toList(),
      ),
    );

    if (nuevoEstado != null && nuevoEstado != ag.estadoCita && mounted) {
      context.read<AgendamientosBloc>().add(ChangeAgendamientoStatusRequested(
        agendamiento: ag,
        nuevoEstado: nuevoEstado,
      ));
    }
  }



  Widget _buildPaginationControls(int totalPages, int currentPage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: EllipsisPagination(
        totalPages: totalPages,
        currentPage: currentPage,
        onPageChanged: (page) {
          context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(page: page, estaSemana: false));
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VISTA DE HISTORIAL PARA BARBERO
  // ═══════════════════════════════════════════════════════════════════
  
  Widget _buildBarberoHistorialView() {
    return SessionGuard(
      allowedRoles: const [AppRole.barber],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: BlocConsumer<AgendamientosBloc, AgendamientosState>(
          listener: (context, state) {
            if (state is AgendamientosError) {
              AppToast.showError(context, state.message);
            } else if (state is AgendamientosActionSuccess) {
              AppToast.showSuccess(context, state.message);
            }
          },
          builder: (context, state) {
            bool isLoading = state is AgendamientosInitial || state is AgendamientosLoading;
            List<Agendamiento> agendamientos = [];
            Paginacion<Agendamiento>? paginacion;
            int currentPage = 1;

            if (state is AgendamientosLoaded) {
              agendamientos = state.agendamientos;
              paginacion = state.paginacion;
              currentPage = state.currentPage;
            }

            // Mostrar todas las citas sin filtro de estado
            final citasFiltradas = _agendamientosFiltrados(agendamientos);
            
            // Ganancia total del historial filtrado
            final gananciasTotal = citasFiltradas.fold(0.0, (sum, a) => sum + (a.monto ?? a.precio ?? 0));

            return SafeArea(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                  : RefreshIndicator(
                      onRefresh: () async {
                        context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
                      },
                      color: AppColors.gold,
                      backgroundColor: AppColors.card,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          // Header
                          SliverToBoxAdapter(
                            child: _buildHistorialHeader(),
                          ),
                          // Título de servicios pasados con buscador
                          SliverToBoxAdapter(
                            child: _buildServiciosPasadosHeader(),
                          ),
                          // Lista de servicios
                          citasFiltradas.isEmpty
                              ? SliverToBoxAdapter(
                                  child: _buildEmptyHistorial(),
                                )
                              : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      return _buildHistorialCard(citasFiltradas[index]);
                                    },
                                    childCount: citasFiltradas.length,
                                  ),
                                ),
                          // Paginación
                          if (paginacion != null && paginacion.totalPages > 1)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: _buildPaginationControls(paginacion.totalPages, currentPage),
                              ),
                            ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 100),
                          ),
                        ],
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHistorialHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Título y subtítulo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historial',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Text(
                    'Resumen de tu actividad',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.grey,
                    ),
                  ),
                  if (_filtroFechaActivo || _searchQuery.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                          _fechaDesde = null;
                          _fechaHasta = null;
                          _filtroFechaActivo = false;
                          _periodoGanancia = 'mensual';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear, size: 12, color: AppColors.gold),
                            SizedBox(width: 2),
                            Text(
                              'Limpiar filtros',
                              style: TextStyle(fontSize: 11, color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCards(double gananciasPeriodo, double gananciasTotal) {
    // Determinar texto del período según filtro
    String textoPeriodo = 'Esta semana';
    if (_filtroFechaActivo) {
      if (_fechaDesde != null && _fechaHasta != null) {
        final diff = _fechaHasta!.difference(_fechaDesde!).inDays;
        if (diff == 0) {
          textoPeriodo = 'Hoy';
        } else if (diff < 7) {
          textoPeriodo = '${diff + 1} días';
        } else if (diff < 30) {
          textoPeriodo = '${(diff / 7).round()} semanas';
        } else {
          textoPeriodo = '${(diff / 30).round()} meses';
        }
      } else {
        textoPeriodo = 'Período personalizado';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildResumenCard(
              icon: Icons.wallet_outlined,
              title: 'Ganancias 60%',
              subtitle: textoPeriodo,
              amount: AppFormat.cop(gananciasPeriodo * 0.6), // 60% para el barbero
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildResumenCard(
              icon: Icons.storefront_outlined,
              title: 'Total servicios',
              subtitle: textoPeriodo,
              amount: AppFormat.cop(gananciasTotal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.gold,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          // Título y subtítulo
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.grey.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          // Monto
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiciosPasadosHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Servicios pasados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
              if (_filtroFechaActivo || _searchQuery.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    _limpiarFiltrosFecha();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.clear_all, size: 16, color: AppColors.gold),
                  label: const Text('Limpiar', style: TextStyle(color: AppColors.gold, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Buscador mejorado
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search, color: AppColors.grey, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppColors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Buscar cliente o servicio...',
                      hintStyle: TextStyle(color: AppColors.grey, fontSize: 14),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20, color: AppColors.grey),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Fila de filtros de fecha
          Row(
            children: [
              // Botón de filtro por fecha
              Expanded(
                child: GestureDetector(
                  onTap: _seleccionarRangoFechas,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: _filtroFechaActivo 
                          ? AppColors.gold.withOpacity(0.15) 
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _filtroFechaActivo ? AppColors.gold : AppColors.divider,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined, 
                          size: 18, 
                          color: _filtroFechaActivo ? AppColors.gold : AppColors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _filtroFechaActivo && _fechaDesde != null && _fechaHasta != null
                                ? '${DateFormat('dd/MM/yy').format(_fechaDesde!)} - ${DateFormat('dd/MM/yy').format(_fechaHasta!)}'
                                : 'Filtrar por fecha',
                            style: TextStyle(
                              color: _filtroFechaActivo ? AppColors.gold : AppColors.grey,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_filtroFechaActivo)
                          GestureDetector(
                            onTap: _limpiarFiltrosFecha,
                            child: Icon(Icons.close, size: 16, color: AppColors.gold.withOpacity(0.8)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Botón de filtro rápido - Hoy
              GestureDetector(
                onTap: () {
                  final hoy = DateTime.now();
                  setState(() {
                    _fechaDesde = hoy;
                    _fechaHasta = hoy;
                    _filtroFechaActivo = true;
                    // Sincronizar con el mini dashboard de ganancias
                    _periodoGanancia = 'hoy';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _periodoGanancia == 'hoy' && _filtroFechaActivo
                        ? AppColors.gold.withOpacity(0.2)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _periodoGanancia == 'hoy' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    'Hoy',
                    style: TextStyle(
                      color: _periodoGanancia == 'hoy' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón de filtro rápido - Esta semana
              GestureDetector(
                onTap: () {
                  final hoy = DateTime.now();
                  final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
                  setState(() {
                    _fechaDesde = inicioSemana;
                    _fechaHasta = hoy;
                    _filtroFechaActivo = true;
                    // Sincronizar con el mini dashboard de ganancias
                    _periodoGanancia = 'semanal';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _periodoGanancia == 'semanal' && _filtroFechaActivo
                        ? AppColors.gold.withOpacity(0.2)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _periodoGanancia == 'semanal' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    'Esta semana',
                    style: TextStyle(
                      color: _periodoGanancia == 'semanal' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Botón de filtro rápido - Este mes
              GestureDetector(
                onTap: () {
                  final hoy = DateTime.now();
                  setState(() {
                    _fechaDesde = DateTime(hoy.year, hoy.month, 1);
                    _fechaHasta = hoy;
                    _filtroFechaActivo = true;
                    // Sincronizar con el mini dashboard de ganancias
                    _periodoGanancia = 'mensual';
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _periodoGanancia == 'mensual' && _filtroFechaActivo
                        ? AppColors.gold.withOpacity(0.2)
                        : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _periodoGanancia == 'mensual' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    'Este mes',
                    style: TextStyle(
                      color: _periodoGanancia == 'mensual' && _filtroFechaActivo
                          ? AppColors.gold
                          : AppColors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialCard(Agendamiento cita) {
    // Formatear hora a 12h
    String horaFormateada = AppFormat.to12h(cita.horaInicio ?? '');
    String amPm = '';
    if (horaFormateada.contains(' ')) {
      final parts = horaFormateada.split(' ');
      horaFormateada = parts[0];
      amPm = parts[1];
    }

    // Formatear fecha
    String fechaFormateada = '';
    try {
      if (cita.fechaCita != null && cita.fechaCita!.isNotEmpty) {
        final fecha = DateTime.parse(cita.fechaCita!);
        fechaFormateada = DateFormat('d MMM yyyy', 'es').format(fecha).toLowerCase();
      }
    } catch (_) {
      fechaFormateada = cita.fechaCita ?? '';
    }

    // Nombre del cliente
    final nombreCliente = cita.cliente?.nombreCompleto ?? 
                         cita.clienteNombre ?? 
                         'Cliente';

    // Servicio
    String servicio = '';
    if (cita.serviciosNombres.isNotEmpty) {
      servicio = cita.serviciosNombres.join(' + ');
    } else if (cita.servicio?.nombre != null) {
      servicio = cita.servicio!.nombre;
    } else {
      servicio = 'Servicio';
    }

    // Precio
    final precio = cita.monto ?? cita.precio ?? 0;

    final statusColor = _getStatusColor(cita.estadoCita);

    return GestureDetector(
      onTap: () => _verDetalles(cita),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Indicador lateral
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  color: statusColor,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
            // Columna de hora
            SizedBox(
              width: 55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horaFormateada,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                    ),
                  ),
                  Text(
                    amPm,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fechaFormateada,
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.grey.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Divisor
            Container(
              width: 1,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: AppColors.divider,
            ),
            // Información del cliente y servicio
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nombreCliente,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusBadge(cita.estadoCita),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    servicio,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.grey.withOpacity(0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Precio y flecha
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormat.cop(precio),
                  style: const TextStyle(
                    color: AppColors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.gold,
                  size: 20,
                ),
              ],
            ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistorial() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: AppColors.gold.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _filtroFechaActivo || _searchQuery.isNotEmpty
                ? 'No hay citas que coincidan con los filtros aplicados'
                : 'No tienes citas en tu historial',
            style: const TextStyle(
              color: AppColors.grey,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MINI DASHBOARD GANANCIA 60% PARA BARBERO
  // ═══════════════════════════════════════════════════════════════════
  
  String _getNombrePeriodoGanancia() {
    switch (_periodoGanancia) {
      case 'hoy': return 'Hoy';
      case 'semanal': return 'Semanal';
      case 'mensual': return 'Mensual';
      case 'anual': return 'Anual';
      default: return 'Mensual';
    }
  }
  
  Widget _buildMiniGananciaPill() {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('ganancia_$_periodoGanancia'),
      future: _cargarGananciaDashboard(),
      builder: (context, snapshot) {
        final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
        final double ganancia = snapshot.hasData 
            ? (double.tryParse(snapshot.data!['gananciasBarberos']?.toString() ?? '0') ?? 0)
            : 0;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: GestureDetector(
            onTap: () => _mostrarSelectorPeriodoGanancia(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF9A7040), Color(0xFFC9A96E), Color(0xFFE0C080)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bg.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.bg,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'MI GANANCIA (${_getNombrePeriodoGanancia()})',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.bg,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: AppColors.bg.withOpacity(0.8),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        if (isLoading)
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          )
                        else
                          Text(
                            AppFormat.cop(ganancia),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.bg,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Future<Map<String, dynamic>> _cargarGananciaDashboard() async {
    try {
      final dashboardService = DashboardService();
      final authService = AuthService();
      final barberoService = BarberoService();
      
      final user = await authService.getCurrentUser();
      final fbUser = authService.currentUser;
      final barberos = await barberoService.obtenerBarberos();
      final emailBuscado = user?.correo ?? fbUser?.email ?? '';
      
      final barberoLocal = barberos.firstWhere(
        (b) => (b.email ?? '').toLowerCase() == emailBuscado.toLowerCase(),
        orElse: () => throw Exception('Perfil no encontrado'),
      );
      
      // Cargar ganancia según el período seleccionado
      return await dashboardService.obtenerGanancias(_periodoGanancia, barberoLocal.nombre);
    } catch (e) {
      print('❌ Error cargando ganancia: $e');
      return {'gananciasBarberos': 0};
    }
  }
  
  void _mostrarSelectorPeriodoGanancia() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccione Periodo',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
              _buildPeriodoOption(ctx, 'hoy', 'Hoy', Icons.today),
              _buildPeriodoOption(ctx, 'semanal', 'Esta Semana', Icons.view_week),
              _buildPeriodoOption(ctx, 'mensual', 'Este Mes', Icons.calendar_month),
              _buildPeriodoOption(ctx, 'anual', 'Este Año', Icons.calendar_today),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildPeriodoOption(BuildContext ctx, String value, String label, IconData icon) {
    final bool isSelected = _periodoGanancia == value;
    return ListTile(
      leading: Icon(icon, color: AppColors.gold),
      title: Text(
        label, 
        style: TextStyle(
          color: AppColors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected 
          ? const Icon(Icons.check, color: AppColors.gold)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() {
          _periodoGanancia = value;
        });
      },
    );
  }

}

class DaySelectorWidget extends StatefulWidget {
  final Function(List<DateTime>, String, {String? horaInicio, String? horaFin}) onConfirm;
  final bool isGlobal;

  const DaySelectorWidget({super.key, required this.onConfirm, required this.isGlobal});

  @override
  State<DaySelectorWidget> createState() => _DaySelectorWidgetState();
}

class _DaySelectorWidgetState extends State<DaySelectorWidget> {
  int _currentTab = 0; // 0: Hora, 1: Día, 2: Días, 3: Semanal
  
  // Para Días y Semanal
  String _selectedWeek = 'Semana actual';
  final List<DateTime> _selectedDates = [];
  
  // Para Hora y Día
  DateTime? _fechaHora;
  TimeOfDay? _horaInicio;
  TimeOfDay? _horaFin;

  final TextEditingController _motivoController = TextEditingController();

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  List<DateTime> _getWeekDays(String weekType) {
    DateTime now = DateTime.now();
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs como en web
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTab(0, '⏰ Por Hora'),
              _buildTab(1, '📅 Un Día'),
              _buildTab(2, '🗓 Varios Días'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        if (_currentTab == 0) ...[
          // HORA
          Text('Cancela citas dentro de un rango de horas.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          _buildDateField(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTimeField(true)),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('-', style: TextStyle(color: Colors.white))),
              Expanded(child: _buildTimeField(false)),
            ],
          ),
        ] else if (_currentTab == 1) ...[
          // DÍA
          Text('Cancela todas las citas en una fecha específica.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          _buildDateField(),
        ] else if (_currentTab == 2) ...[
          // VARIOS DÍAS
          _buildWeekDropdown(),
          const SizedBox(height: 12),
          _buildChips(weekDays, today),
        ],

        const SizedBox(height: 20),
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
        const SizedBox(height: 10),
        if (widget.isGlobal)
          const Text(
            '* Nota: Esta acción cancelará las citas de TODOS los barberos en los días o rango seleccionados.',
            style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            if (_currentTab == 1) { // Día
              if (_fechaHora == null) {
                AppToast.showError(context, 'Selecciona una fecha');
                return;
              }
              widget.onConfirm([_fechaHora!], _motivoController.text.trim());
            } else if (_currentTab == 2) { // Varios Días
              if (_selectedDates.isEmpty) return;
              widget.onConfirm(_selectedDates, _motivoController.text.trim());
            } else { // Por Hora
              if (_fechaHora == null || _horaInicio == null || _horaFin == null) return;
              
              final startMins = _horaInicio!.hour * 60 + _horaInicio!.minute;
              final endMins = _horaFin!.hour * 60 + _horaFin!.minute;
              if (startMins >= endMins) {
                AppToast.showError(context, 'La hora de inicio debe ser anterior a la hora de fin');
                return;
              }

              final hs = '${_horaInicio!.hour.toString().padLeft(2, '0')}:${_horaInicio!.minute.toString().padLeft(2, '0')}';
              final hf = '${_horaFin!.hour.toString().padLeft(2, '0')}:${_horaFin!.minute.toString().padLeft(2, '0')}';
              
              widget.onConfirm([_fechaHora!], _motivoController.text.trim(), horaInicio: hs, horaFin: hf);
            }
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 45),
            backgroundColor: const Color(0xFFD8B081),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('CONFIRMAR SELECCIÓN'),
        ),
      ],
    );
  }

  Widget _buildTab(int index, String label) {
    final act = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: act ? Colors.red.withOpacity(0.1) : Colors.transparent,
          border: Border(bottom: BorderSide(color: act ? Colors.redAccent : Colors.transparent, width: 2)),
        ),
        child: Text(label, style: TextStyle(color: act ? Colors.redAccent : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildWeekDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B081), width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
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
    );
  }

  Widget _buildChips(List<DateTime> weekDays, DateTime today) {
    return Wrap(
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
              if (val) _selectedDates.add(date);
              else _selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
            });
          },
          backgroundColor: const Color(0xFF2A2A2A),
          selectedColor: Colors.redAccent,
          labelStyle: TextStyle(
            color: isPast ? Colors.white24 : (isSelected ? Colors.white : Colors.white70),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          checkmarkColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        );
      }).toList(),
    );
  }

  Widget _buildDateField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B081), width: 1.5),
      ),
      child: TextButton.icon(
        icon: const Icon(Icons.calendar_today, color: Color(0xFFD8B081)),
        label: Text(_fechaHora != null ? DateFormat('dd/MM/yyyy').format(_fechaHora!) : 'Seleccionar Fecha', style: const TextStyle(color: Colors.white)),
        onPressed: () async {
          final now = DateTime.now();
          final d = await showDatePicker(
            context: context, 
            initialDate: now, 
            firstDate: now, 
            lastDate: now.add(const Duration(days: 365)),
            builder: (context, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Color(0xFFD8B081), onPrimary: Colors.black, surface: Color(0xFF2A2A2A), onSurface: Colors.white),
              ),
              child: child!,
            ),
          );
          if (d != null) setState(() => _fechaHora = d);
        },
      ),
    );
  }

  Widget _buildTimeField(bool isStart) {
    final tVal = isStart ? _horaInicio : _horaFin;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8B081), width: 1.5),
      ),
      child: TextButton.icon(
        icon: Icon(Icons.access_time, color: isStart ? const Color(0xFFD8B081) : Colors.redAccent),
        label: Text(tVal != null ? tVal.format(context) : (isStart ? 'Inicio' : 'Fin'), style: const TextStyle(color: Colors.white)),
        onPressed: () async {
          final t = await showTimePicker(
            context: context, 
            initialTime: TimeOfDay(hour: isStart ? 8 : 18, minute: 0),
            builder: (context, child) => Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: Color(0xFFD8B081), onPrimary: Colors.black, surface: Color(0xFF2A2A2A), onSurface: Colors.white),
              ),
              child: child!,
            ),
          );
          if (t != null) setState(() => isStart ? _horaInicio = t : _horaFin = t);
        },
      ),
    );
  }
}
