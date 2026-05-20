import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_bloc.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_event.dart';
import 'package:parte_movil/presentation/blocs/agendamientos/agendamientos_state.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/presentation/widgets/session_guard.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'agendamiento_detalle_screen.dart';
import 'package:parte_movil/presentation/widgets/cita_notification_bell.dart';

class AgendamientosScreen extends StatefulWidget {
  final AppRole role;

  const AgendamientosScreen({super.key, this.role = AppRole.admin}); // Default a admin por compatibilidad

  @override
  State<AgendamientosScreen> createState() => _AgendamientosScreenState();
}

class _AgendamientosScreenState extends State<AgendamientosScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filtroEstadoAdmin = 'Todos';

  // ── Calendar View ─────────────────────────────────────────────────────
  /// 0 = Vista Semanal (WeekView), 1 = Vista 3 Días (MultiDayView)
  int _calendarViewMode = 0;
  final EventController<Agendamiento> _eventController = EventController<Agendamiento>();
  List<Agendamiento> _lastSyncedAgendamientos = [];

  List<Agendamiento> _agendamientosFiltrados(List<Agendamiento> agendamientos) {
    var resultado = agendamientos;

    // Filtro estado Admin
    if (_filtroEstadoAdmin == 'Todos') {
      // Por defecto: excluir canceladas
      resultado = resultado.where((a) {
        final estado = (a.estadoCita ?? '').toLowerCase().trim();
        return estado != 'cancelada' && estado != 'cancelado';
      }).toList();
    } else {
      resultado = resultado.where((a) {
        final estado = (a.estadoCita ?? '').toLowerCase().trim();
        final filtro = _filtroEstadoAdmin.toLowerCase();
        
        if (filtro == 'completada') {
          return estado == 'completada' || estado == 'completado' || estado == 'finalizado' || estado == 'finalizada';
        }
        
        return estado == filtro;
      }).toList();
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

    return resultado;
  }

  Color _getStatusColor(String? estadoRaw) {
    final estado = (estadoRaw ?? '').toLowerCase().trim();
    if (estado == 'pendiente') {
      return AppColors.gold;
    } else if (estado == 'completada' || estado == 'completado' || estado == 'finalizado' || estado == 'finalizada') {
      return AppColors.green;
    } else if (estado == 'cancelada' || estado == 'cancelado') {
      return AppColors.red.withValues(alpha: 0.8);
    }
    return AppColors.grey;
  }



  Future<void> _verDetalles(Agendamiento ag) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgendamientoDetalleScreen(
          agendamiento: ag,
          role: widget.role,
        ),
      ),
    );
    
    if (!mounted) return;
    
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
  }

  @override
  void initState() {
    super.initState();
    _searchController.clear();
    _searchQuery = '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _eventController.dispose();
    super.dispose();
  }

  // ── Conversión Agendamiento → CalendarEventData ───────────────────────
  void _syncEventsToController(List<Agendamiento> agendamientos) {
    // Evitar re-sincronizar si la lista no cambió
    if (identical(agendamientos, _lastSyncedAgendamientos)) return;
    _lastSyncedAgendamientos = agendamientos;

    // Limpiar eventos previos
    final allEvents = _eventController.allEvents.toList();
    for (final event in allEvents) {
      _eventController.remove(event);
    }

    for (final ag in agendamientos) {
      final eventData = _agendamientoToEvent(ag);
      if (eventData != null) {
        _eventController.add(eventData);
      }
    }
  }

  CalendarEventData<Agendamiento>? _agendamientoToEvent(Agendamiento ag) {
    if (ag.fechaCita == null || ag.fechaCita!.isEmpty) return null;

    try {
      final fecha = DateTime.parse(ag.fechaCita!);

      // Parsear hora de inicio
      DateTime startTime = DateTime(fecha.year, fecha.month, fecha.day, 9, 0);
      if (ag.horaInicio != null && ag.horaInicio!.isNotEmpty) {
        final parts = ag.horaInicio!.split(':');
        if (parts.length >= 2) {
          startTime = DateTime(
            fecha.year, fecha.month, fecha.day,
            int.tryParse(parts[0]) ?? 9,
            int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      // Parsear hora fin (default +1h)
      DateTime endTime = startTime.add(const Duration(hours: 1));
      if (ag.horaFin != null && ag.horaFin!.isNotEmpty) {
        final parts = ag.horaFin!.split(':');
        if (parts.length >= 2) {
          endTime = DateTime(
            fecha.year, fecha.month, fecha.day,
            int.tryParse(parts[0]) ?? startTime.hour + 1,
            int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      // Nombre del cliente
      final nombreCliente = ag.clienteNombre ??
          ag.cliente?.nombreCompleto ??
          'Cliente';

      // Servicio
      String servicio = '';
      if (ag.serviciosNombres.isNotEmpty) {
        servicio = ag.serviciosNombres.join(' + ');
      } else if (ag.servicio?.nombre != null) {
        servicio = ag.servicio!.nombre;
      }

      final color = _getStatusColor(ag.estadoCita);

      return CalendarEventData<Agendamiento>(
        date: fecha,
        startTime: startTime,
        endTime: endTime,
        title: nombreCliente,
        description: servicio,
        color: color,
        event: ag,
      );
    } catch (e) {
      return null;
    }
  }

  // ── Custom Event Tile Builder ─────────────────────────────────────────
  Widget _eventTileBuilder(
    DateTime date,
    List<CalendarEventData<Agendamiento>> events,
    Rect boundary,
    DateTime startDuration,
    DateTime endDuration,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();
    final event = events.first;
    final ag = event.event;
    final statusColor = event.color;

    // Nombre del barbero
    String barberoLabel = '';
    if (ag != null) {
      barberoLabel = ag.barbero?.nombreCompleto ?? ag.barberoNombre ?? '';
    }

    return GestureDetector(
      onTap: () {
        if (ag != null) _verDetalles(ag);
      },
      child: Container(
        width: boundary.width,
        height: boundary.height,
        margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 0.5),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: statusColor, width: 3),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.title,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (boundary.height > 25 && event.description != null && event.description!.isNotEmpty)
              Text(
                event.description!,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.7),
                  fontSize: 9,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (boundary.height > 40 && barberoLabel.isNotEmpty)
              Text(
                barberoLabel,
                style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.8),
                  fontSize: 8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }

  // ── Calendar Toggle (Semana / 3 Días) ─────────────────────────────────
  Widget _buildCalendarToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _buildToggleBtn('Semana', 0, Icons.view_week_outlined),
          const SizedBox(width: 8),
          _buildToggleBtn('3 Días', 1, Icons.view_day_outlined),
          const Spacer(),
          // Filtro de estado rápido
          PopupMenuButton<String>(
            icon: Icon(
              Icons.filter_list,
              color: _filtroEstadoAdmin != 'Todos' ? AppColors.gold : AppColors.grey,
              size: 22,
            ),
            color: AppColors.card,
            onSelected: (val) {
              setState(() {
                _filtroEstadoAdmin = val;
              });
            },
            itemBuilder: (_) => ['Todos', 'Pendiente', 'Completada', 'Cancelada']
                .map((e) => PopupMenuItem<String>(
                      value: e,
                      child: Row(
                        children: [
                          if (_filtroEstadoAdmin == e)
                            const Icon(Icons.check, size: 16, color: AppColors.gold)
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(e, style: const TextStyle(color: AppColors.white, fontSize: 13)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, int mode, IconData icon) {
    final sel = _calendarViewMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _calendarViewMode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? AppColors.gold.withValues(alpha: 0.15) : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? AppColors.gold : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: sel ? AppColors.gold : AppColors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: sel ? AppColors.gold : AppColors.grey,
                fontSize: 12,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Construir la vista de calendario ───────────────────────────────────
  Widget _buildCalendarView(List<Agendamiento> agendamientos) {
    // Filtrar y sincronizar eventos
    final filtrados = _agendamientosFiltrados(agendamientos);
    _syncEventsToController(filtrados);

    return CalendarControllerProvider<Agendamiento>(
      controller: _eventController,
      child: _calendarViewMode == 0
          ? _buildWeekView()
          : _buildMultiDayView(),
    );
  }

  Widget _buildWeekView() {
    return WeekView<Agendamiento>(
      showWeekends: true,
      showLiveTimeLineInAllDays: false,
      eventArranger: SideEventArranger<Agendamiento>(maxWidth: 30),
      timeLineWidth: 56,
      heightPerMinute: 1.2,
      showHalfHours: true,
      minuteSlotSize: MinuteSlotSize.minutes30,
      hourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      halfHourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      startHour: 9,
      endHour: 23,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundColor: AppColors.bg,
      weekNumberBuilder: (date) => Container(color: AppColors.surface),
      weekTitleHeight: 50,
      weekPageHeaderBuilder: (startDate, endDate) {
        return _buildCalendarHeader(startDate, endDate);
      },
      weekDayBuilder: (date) => _buildWeekDayLabel(date),
      timeLineBuilder: (date) => _buildTimeLine(date),
      eventTileBuilder: _eventTileBuilder,
      liveTimeIndicatorSettings: LiveTimeIndicatorSettings(
        color: AppColors.gold,
        showTime: false,
        onlyShowToday: true,
      ),
      onEventTap: (events, date) {
        if (events.isNotEmpty && events.first.event != null) {
          _verDetalles(events.first.event!);
        }
      },
    );
  }

  Widget _buildMultiDayView() {
    return MultiDayView<Agendamiento>(
      daysInView: 3,
      showLiveTimeLineInAllDays: false,
      eventArranger: SideEventArranger<Agendamiento>(maxWidth: 30),
      timeLineWidth: 56,
      heightPerMinute: 1.2,
      showHalfHours: true,
      minuteSlotSize: MinuteSlotSize.minutes30,
      hourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      halfHourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      startHour: 9,
      endHour: 23,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundColor: AppColors.bg,
      weekNumberBuilder: (date) => Container(color: AppColors.surface),
      weekPageHeaderBuilder: (startDate, endDate) {
        return _buildCalendarHeader(startDate, endDate);
      },
      weekDayBuilder: (date) => _buildWeekDayLabel(date),
      timeLineBuilder: (date) => _buildTimeLine(date),
      eventTileBuilder: _eventTileBuilder,
      liveTimeIndicatorSettings: LiveTimeIndicatorSettings(
        color: AppColors.gold,
        showTime: false,
        onlyShowToday: true,
      ),
      onEventTap: (events, date) {
        if (events.isNotEmpty && events.first.event != null) {
          _verDetalles(events.first.event!);
        }
      },
    );
  }

  // ── Calendar Header ───────────────────────────────────────────────────
  Widget _buildCalendarHeader(DateTime startDate, DateTime endDate) {
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final label = startDate.month == endDate.month
        ? '${startDate.day} - ${endDate.day} ${meses[startDate.month - 1]} ${startDate.year}'
        : '${startDate.day} ${meses[startDate.month - 1]} - ${endDate.day} ${meses[endDate.month - 1]} ${startDate.year}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.bg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.gold),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Week Day Label ────────────────────────────────────────────────────
  Widget _buildWeekDayLabel(DateTime date) {
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    return Container(
      color: AppColors.surface,
      child: Container(
        decoration: BoxDecoration(
          color: isToday ? AppColors.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dias[date.weekday - 1],
                style: TextStyle(
                  color: isToday ? AppColors.gold : AppColors.greyLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.gold : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: isToday ? AppColors.bg : AppColors.greyLightest,
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLine(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;
    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    
    final String timeText;
    if (minute == 0) {
      timeText = '$displayHour$period';
    } else {
      final displayMinute = minute.toString().padLeft(2, '0');
      timeText = '$displayHour:$displayMinute$period';
    }
    final isHalfHour = minute != 0;

    return Container(
      height: 36,
      width: 56,
      padding: const EdgeInsets.only(right: 8),
      alignment: Alignment.centerRight,
      child: Transform.translate(
        offset: Offset(0, isHalfHour ? 42 : 18),
        child: Text(
          timeText,
          style: const TextStyle(
            color: AppColors.grey,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SessionGuard(
      allowedRoles: const [AppRole.admin, AppRole.manager, AppRole.barber, AppRole.client],
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Agenda'),
          actions: [CitaNotificationBell(role: widget.role)],
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

            if (state is AgendamientosLoaded) {
              agendamientos = state.agendamientos;
            }

            return Column(
              children: [
                _buildCalendarToggle(),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
                      : _buildCalendarView(agendamientos),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── TARJETA DE CITA PARA ADMIN ─────────────────────────────────────────
}
