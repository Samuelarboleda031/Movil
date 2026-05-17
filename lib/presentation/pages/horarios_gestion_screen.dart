import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_bloc.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_event.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_state.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/presentation/pages/agendamientos_screen.dart' show DaySelectorWidget;
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'dart:math' as math;
import 'horario_form_screen.dart';
import 'solicitudes_cambio_horario_screen.dart';
import 'citas_por_dia_screen.dart';

// ─── HELPERS LOCALES ─────────────────────────────────────────────────────────
String _formatHora12(String time) {
  if (time.isEmpty) return '--:--';
  try {
    final parts = time.split(':');
    int hour = int.parse(parts[0]);
    final minute = parts.length > 1 ? parts[1] : '00';
    final period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) hour = 12;
    if (hour > 12) hour -= 12;
    return '${hour.toString().padLeft(2, '0')}:$minute $period';
  } catch (_) {
    return time;
  }
}

// ─── COLORES GLOBALES ────────────────────────────────────────────────────────
const kBg        = AppColors.bg;
const kSurface   = AppColors.card;
const kSurface2  = AppColors.inputBg;
const kBorder    = AppColors.divider;
const kBorder2   = AppColors.inputBorder;
const kGold      = AppColors.gold;
const kTextPrim  = AppColors.whiteSecondary;
const kTextMuted = AppColors.greyLight;
const kTextDim   = AppColors.grey;

// ─── MODELO UI GRUPO ─────────────────────────────────────────────────────────
class _BarberGroup {
  final Barbero barbero;
  final List<HorarioSemanal> semanales;
  final Color color;

  _BarberGroup({required this.barbero, required this.semanales, required this.color});

  String get iniciales {
    if (barbero.nombre.isEmpty) return '??';
    final parts = barbero.nombre.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return barbero.nombre.substring(0, math.min(2, barbero.nombre.length)).toUpperCase();
  }

  int get turnosActivos => semanales.where((s) => s.estado == 'Activo').length;
}

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
class HorariosGestionScreen extends StatefulWidget {
  final AppRole role;
  const HorariosGestionScreen({super.key, required this.role});

  @override
  State<HorariosGestionScreen> createState() => _HorariosGestionScreenState();
}

class _HorariosGestionScreenState extends State<HorariosGestionScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Barbero> _barberos = [];
  AppRole _currentRole = AppRole.client;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _loadBarberos();
    _fetchCurrentRole();
  }

  Future<void> _fetchCurrentRole() async {
    final user = await AuthService().getCurrentUser();
    if (user != null && user.rolId != null) {
      if (mounted) {
        setState(() {
          _currentRole = roleForRolId(user.rolId) ?? widget.role;
        });
      }
    }
  }

  Future<void> _loadBarberos() async {
    try {
      final barberos = await BarberoService().obtenerBarberos();
      if (mounted) {
        setState(() {
          _barberos = barberos;
        });
      }
    } catch (e) {
      print('Error cargando barberos: $e');
    }
  }

  String _obtenerMesAnio() {
    final meses = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    final now = DateTime.now();
    return 'Barbería · ${meses[now.month - 1]} ${now.year}';
  }

  String _obtenerDiaSemana(int dia) {
    const nombres = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
    if (dia >= 0 && dia < nombres.length) {
      return nombres[dia];
    }
    if (dia == 7) {
      return 'Domingo';
    }
    return 'Día $dia';
  }

  Color _getColorForBarber(String nombre) {
    final colors = [
      const Color(0xFFC9A96E),
      const Color(0xFF5DCAA5),
      const Color(0xFFED93B1),
      const Color(0xFF8BA4F9),
      const Color(0xFFF2A65A),
    ];
    int hash = nombre.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  List<_BarberGroup> _getGroupedData(List<HorarioSemanal> horarios) {
    final q = _searchQuery.toLowerCase();
    final Map<int, List<HorarioSemanal>> map = {};
    for (var h in horarios) {
      if (!map.containsKey(h.barberoId)) map[h.barberoId] = [];
      map[h.barberoId]!.add(h);
    }

    List<_BarberGroup> groups = [];
    for (var entry in map.entries) {
      final barberoId = entry.key;
      final semanales = entry.value;

      Barbero barbero;
      try {
        barbero = _barberos.firstWhere((b) => b.id == barberoId);
      } catch (e) {
        barbero = Barbero(id: barberoId, nombre: semanales.first.barberoNombre ?? 'Barbero', apellido: '', documento: '', estado: true);
      }

      final barberoStr = barbero.nombreCompleto.toLowerCase();

      final semanalesFiltrados = semanales.where((s) {
        final fechasStr = '${s.fechaInicioSemana} ${s.fechaFinSemana}'.toLowerCase();
        final estadoStr = s.estado.toLowerCase();
        return q.isEmpty || barberoStr.contains(q) || fechasStr.contains(q) || estadoStr.contains(q);
      }).toList();

      if (semanalesFiltrados.isNotEmpty) {
        groups.add(_BarberGroup(
          barbero: barbero,
          semanales: semanalesFiltrados,
          color: _getColorForBarber(barbero.nombreCompleto),
        ));
      }
    }
    return groups;
  }

  void _eliminarHorario(HorarioSemanal horario, String nombreBarbero) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurface,
        title: const Text('Eliminar Horario Semanal', style: TextStyle(color: kTextPrim)),
        content: Text(
          '¿Desea eliminar el horario semanal del ${horario.fechaInicioSemana} al ${horario.fechaFinSemana} de $nombreBarbero?',
          style: const TextStyle(color: kTextMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: kTextDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<HorariosBloc>().add(DeleteHorarioSemanalRequested(horario.id!));
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarDias() async {
    Barbero? barberoSeleccionado;
    bool esBarberoRol = _currentRole == AppRole.barber;
    
    if (esBarberoRol) {
      final userContext = UserContextService();
      final barberoActual = await userContext.obtenerBarberoActual();
      if (barberoActual != null && barberoActual.id != null) {
        barberoSeleccionado = barberoActual;
      } else {
        AppToast.showError(context, 'No se pudo obtener tu información de barbero');
        return;
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!esBarberoRol) ...[
                        SearchableSelector<Barbero>(
                          label: 'Barbero',
                          hint: 'Seleccionar...',
                          items: [Barbero(id: -1, nombre: 'Todos los barberos', apellido: '', documento: '', estado: true), ..._barberos],
                          selectedItem: barberoSeleccionado,
                          displayText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                          searchText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                          onSelected: (b) => setStateDialog(() => barberoSeleccionado = b),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (esBarberoRol && barberoSeleccionado != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.divider)),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: AppColors.gold),
                              const SizedBox(width: 8),
                              Text('Barbero: ${barberoSeleccionado?.nombreCompleto ?? 'Yo'}', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      if (esBarberoRol) const SizedBox(height: 16),
                      DaySelectorWidget(
                        isGlobal: esGlobal,
                        onConfirm: (dates, motivo, {horaInicio, horaFin}) {
                           if (barberoSeleccionado != null && dates.isNotEmpty) {
                             Navigator.pop(dialogCtx, {
                               'barbero': barberoSeleccionado, 
                               'fechas': dates, 
                               'motivo': motivo, 
                               'horaInicio': horaInicio, 
                               'horaFin': horaFin
                             });
                           } else {
                             AppToast.showError(dialogCtx, 'Rellena todos los datos necesarios');
                           }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      }
    );

    if (result == null || !mounted) return;
    final Barbero b = result['barbero'];
    final List<DateTime> dates = result['fechas'];
    final String motivo = result['motivo'] ?? '';
    final String? horaInicio = result['horaInicio'];
    final String? horaFin = result['horaFin'];
    
    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.gold)));
    
    try {
      final srv = AgendamientoService();
      final allApps = await srv.obtenerAgendamientos(page: 1, pageSize: 5000);
      
      final fechasObjetivo = dates.map((d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}').toSet();
      final bool modoHora = horaInicio != null && horaFin != null;
      
      int _parseMinutes(String? time) {
        if (time == null || time.isEmpty) return 0;
        final parts = time.split(':');
        if (parts.length < 2) return 0;
        return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
      }
      
      final int startMin = modoHora ? _parseMinutes(horaInicio) : 0;
      final int endMin = modoHora ? _parseMinutes(horaFin) : 0;

      int canceladas = 0;
      final now = DateTime.now();
      
      for (final cita in allApps.items) {
        final fechaCita = cita.fechaCita ?? '';
        if (!fechasObjetivo.contains(fechaCita)) continue;
        if (b.id != -1 && cita.barberoId != b.id) continue;
        final est = (cita.estadoCita ?? '').toLowerCase().trim();
        if (est == 'cancelada' || est == 'cancelado' || est == 'completada' || est == 'finalizado') continue;
        if (cita.id == null) continue;
        
        if (modoHora) {
          final citaMin = _parseMinutes(cita.horaInicio);
          if (citaMin < startMin || citaMin >= endMin) continue;
        }

        await srv.actualizarEstadoAgendamiento(cita.id!, 'Cancelada');
        canceladas++;
      }

      if (mounted) Navigator.pop(context); // close loading
      if (mounted) {
        final String msg = modoHora
            ? 'Se cancelaron $canceladas cita(s) en ese rango horario.'
            : 'Se cancelaron $canceladas cita(s) para las fechas seleccionadas.';
        AppToast.showSuccess(context, msg);
        context.read<HorariosBloc>().add(LoadHorariosRequested());
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // close loading
      if (mounted) AppToast.showError(context, 'Error al cancelar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber],
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchBar(),
              BlocConsumer<HorariosBloc, HorariosState>(
                listener: (context, state) {
                  if (state is HorarioActionSuccess) {
                    AppToast.showSuccess(context, state.message);
                  } else if (state is HorariosError) {
                    AppToast.showError(context, state.message);
                  }
                },
                builder: (context, state) {
                  if (state is HorariosLoading || state is HorariosInitial) {
                    return const Expanded(child: Center(child: CircularProgressIndicator(color: kGold)));
                  }

                  if (state is HorariosLoaded) {
                    final groups = _getGroupedData(state.horarios);

                    return Expanded(
                      child: Column(
                        children: [
                          _buildBotonCancelarDias(),
                          _buildBotonSolicitudes(),
                          Expanded(
                            child: RefreshIndicator(
                              color: kGold,
                              backgroundColor: kSurface,
                              onRefresh: () async => context.read<HorariosBloc>().add(LoadHorariosRequested()),
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                itemCount: groups.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 10),
                                itemBuilder: (_, i) => _BarberCard(
                                  group: groups[i],
                                  obtenerDiaSemana: _obtenerDiaSemana,
                                  onEdit: (h) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (ctx) => BlocProvider.value(
                                          value: context.read<HorariosBloc>(),
                                          child: HorarioFormScreen(horarioSemanal: h, role: _currentRole),
                                        ),
                                      ),
                                    );
                                  },
                                  onDelete: (h) => _eliminarHorario(h, groups[i].barbero.nombre),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const Expanded(child: Center(child: Text('No se pudieron cargar los horarios.', style: TextStyle(color: kTextMuted))));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _obtenerMesAnio(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: kTextDim,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Horarios',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.whiteSecondary,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Barra de búsqueda ───────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder2, width: 0.5),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13, color: kTextPrim),
          decoration: InputDecoration(
            hintText: 'Buscar día o barbero…',
            hintStyle: const TextStyle(fontSize: 13, color: kTextDim),
            prefixIcon: const Icon(Icons.search, color: kTextMuted, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: kTextDim, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
      ),
    );
  }

  // ── Botón Cancelar Días ───────────────────────────────────────────────────
  Widget _buildBotonCancelarDias() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GestureDetector(
        onTap: _cancelarDias,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gold.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event_busy, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                _currentRole == AppRole.barber ? 'CANCELAR MIS DÍAS' : 'CANCELAR DÍAS',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBotonSolicitudes() {
    final esBarbero = _currentRole == AppRole.barber;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SolicitudesCambioHorarioScreen(role: _currentRole),
          ),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF3A5A8A).withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF3A5A8A).withOpacity(0.35), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.swap_horiz, color: Color(0xFF7EB5F4), size: 20),
              const SizedBox(width: 8),
              Text(
                esBarbero ? 'MIS SOLICITUDES DE HORARIO' : 'SOLICITUDES DE CAMBIO DE HORARIO',
                style: const TextStyle(
                  color: Color(0xFF7EB5F4),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── TARJETA DE BARBERO (ACORDEÓN) ──────────────────────────────────────────
class _BarberCard extends StatefulWidget {
  final _BarberGroup group;
  final String Function(int) obtenerDiaSemana;
  final void Function(HorarioSemanal) onEdit;
  final void Function(HorarioSemanal) onDelete;

  const _BarberCard({
    required this.group,
    required this.obtenerDiaSemana,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_BarberCard> createState() => _BarberCardState();
}

class _BarberCardState extends State<_BarberCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _expandAnim;
  late Animation<double> _rotateAnim;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _expandAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _rotateAnim = Tween(begin: 0.0, end: 0.5).animate(_expandAnim);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _isOpen = !_isOpen);
    _isOpen ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.group;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isOpen ? g.color.withOpacity(0.35) : kBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          // ── Header del barbero ──────────────────────────────────────────────
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: g.color.withOpacity(0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: (g.barbero.fotoPerfil != null && g.barbero.fotoPerfil!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Image.network(
                              g.barbero.fotoPerfil!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Text(
                                g.iniciales,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: g.color,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            g.iniciales,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: g.color,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),

                  // Nombre y meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.barbero.nombre,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: kTextPrim,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${g.turnosActivos}/${g.semanales.length} semanas activas',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: kTextMuted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Chevron animado
                  RotationTransition(
                    turns: _rotateAnim,
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMuted, size: 20),
                  ),
                ],
              ),
            ),
          ),

          // ── Lista de semanas (acordeón) ──────────────────────────────────────
          SizeTransition(
            sizeFactor: _expandAnim,
            child: Column(
              children: [
                const Divider(color: kBorder, height: 0.5, thickness: 0.5),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 2, bottom: 8, left: 14, right: 14),
                  itemCount: g.semanales.length,
                  itemBuilder: (ctx, i) {
                    final s = g.semanales[i];
                    return _SemanaRow(
                      semana: s,
                      onEdit: () => widget.onEdit(s),
                      onDelete: () => widget.onDelete(s),
                      onToggleStatus: () {
                        context.read<HorariosBloc>().add(
                          ToggleHorarioSemanalStatusRequested(s.id!, s.estado != 'Activo'),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── FILA DE SEMANA ───────────────────────────────────────────────────────────
class _SemanaRow extends StatelessWidget {
  final HorarioSemanal semana;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleStatus;

  const _SemanaRow({
    required this.semana,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isActivo = semana.estado == 'Activo';
    final isPendiente = semana.estado == 'Pendiente';
    final badgeColor = isActivo ? kGold : isPendiente ? Colors.orange : kTextDim;
    final badgeBg = isActivo ? kGold.withOpacity(0.12) : isPendiente ? Colors.orange.withOpacity(0.12) : kBorder2;

    // Generar resumen de días
    final diasStr = semana.detalles.map((d) {
      const nombres = ['Dom', 'Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];
      final idx = (d.diaSemana < 0 || d.diaSemana > 7) ? 0 : d.diaSemana;
      return nombres[idx];
    }).join(', ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActivo ? kGold.withOpacity(0.22) : kBorder,
            width: 0.5,
          ),
        ),
        padding: const EdgeInsets.only(left: 12, right: 4, top: 10, bottom: 10),
        child: Row(
          children: [
            // Fechas + estado
            SizedBox(
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${semana.fechaInicioSemana} / ${semana.fechaFinSemana}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActivo ? kTextPrim : kTextDim,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      semana.estado.toLowerCase(),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Resumen de días
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    diasStr.isEmpty ? 'Sin días configurados' : diasStr,
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (semana.detalles.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${_formatHora12(semana.detalles.first.horaInicio)} → ${_formatHora12(semana.detalles.first.horaFin)}',
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: kTextDim),
                    ),
                  ],
                ],
              ),
            ),

            // Opciones
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: kTextMuted, size: 18),
              color: kSurface2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: kTextPrim))),
                PopupMenuItem(value: 'toggle', child: Text(isActivo ? 'Finalizar' : 'Activar', style: TextStyle(color: kGold))),
                const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
              onSelected: (val) {
                if (val == 'edit') onEdit();
                else if (val == 'toggle') onToggleStatus();
                else if (val == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── TARJETA DE ESTADÍSTICA ──────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: kGold,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: kTextDim),
            ),
          ],
        ),
      ),
    );
  }
}
