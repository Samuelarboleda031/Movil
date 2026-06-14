import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:calendar_view/calendar_view.dart';
import 'package:calendar_view/src/theme/week_view_theme_data.dart';
import 'package:calendar_view/src/theme/multi_day_view_theme_data.dart';
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
import 'package:parte_movil/data/datasources/day_discount_service.dart';
import 'package:parte_movil/presentation/widgets/modal_descuento_dia.dart';

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

  // ── Descuentos por día ─────────────────────────────────────────────────
  Map<String, double> _dayDiscounts = {};

  bool get _isAdminOrManager =>
      widget.role == AppRole.admin || widget.role == AppRole.manager;

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
      return const Color(0xFF3B82F6);
    } else if (estado == 'cancelada' || estado == 'cancelado') {
      return AppColors.red.withValues(alpha: 0.8);
    }
    return AppColors.grey;
  }

  // ── Formato 12h (equivalente a formatHoraStr12 del web) ───────────────
  String _formatHora12(DateTime dt) {
    final h = dt.hour;
    final m = dt.minute;
    final ampm = h >= 12 ? 'pm' : 'am';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return m == 0 ? '$h12$ampm' : '$h12:${m.toString().padLeft(2, '0')}$ampm';
  }

  String _formatRangoHorario(DateTime start, DateTime end) {
    return '${_formatHora12(start)} – ${_formatHora12(end)}';
  }

  // ── Quick-info sheet (equivalente al tooltip del web) ─────────────────
  void _showQuickInfoSheet(Agendamiento ag, Color statusColor, DateTime? start, DateTime? end) {
    final clienteNombre = ag.clienteNombre ?? ag.cliente?.nombreCompleto ?? 'Cliente';
    final barberoNombre = ag.barbero?.nombreCompleto ?? ag.barberoNombre ?? '';
    final servicio = ag.serviciosNombres.isNotEmpty
        ? ag.serviciosNombres.join(' + ')
        : ag.servicio?.nombre ?? '';
    final rango = (start != null && end != null) ? _formatRangoHorario(start, end) : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121214),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: 24),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra + datos — igual que la tarjeta del web
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 3,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clienteNombre,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (rango.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            rango,
                            style: TextStyle(
                              color: AppColors.greyLight.withValues(alpha: 0.90),
                              fontSize: 12,
                            ),
                          ),
                        ],
                        if (barberoNombre.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            barberoNombre,
                            style: TextStyle(
                              color: AppColors.greyLight.withValues(alpha: 0.65),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (servicio.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(color: AppColors.divider.withValues(alpha: 0.6), height: 1),
                const SizedBox(height: 10),
                Text(
                  servicio,
                  style: TextStyle(
                    color: AppColors.greyLight.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _verDetalles(ag);
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    foregroundColor: statusColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Ver detalle completo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    _loadDiscounts();
  }

  Future<void> _loadDiscounts() async {
    final discounts = await DayDiscountService.getAllDiscounts();
    if (mounted) setState(() => _dayDiscounts = discounts);
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
          final h = int.tryParse(parts[0]) ?? 9;
          final m = int.tryParse(parts[1]) ?? 0;
          // Redondear al slot de 30 min hacia abajo: 0-29 → :00, 30-59 → :30
          final slotMin = m < 30 ? 0 : 30;
          startTime = DateTime(fecha.year, fecha.month, fecha.day, h, slotMin);
        }
      }

      // 29 min (no 30) para que eventos consecutivos no compartan frontera
      // y MergeEventArranger no los encadene en un tile gigante.
      // Solo se fusionan eventos con exactamente el mismo startTime.
      final DateTime endTime = startTime.add(const Duration(minutes: 29));

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
  // Altura fija por fila dentro del tile (punto + texto).
  static const double _rowH = 14.0;
  static const double _overflowH = 12.0;

  Widget _eventTileBuilder(
    DateTime date,
    List<CalendarEventData<Agendamiento>> events,
    Rect boundary,
    DateTime startDuration,
    DateTime endDuration,
  ) {
    if (events.isEmpty) return const SizedBox.shrink();

    // Color de fondo igual al de la celda: negro si es pasado, gris si es futuro
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final slotDate = DateTime(date.year, date.month, date.day);
    final isDayPast = slotDate.isBefore(today);
    final isToday = slotDate.isAtSameMomentAs(today);
    // startDuration de la librería es relativo al startHour, no es hora real del reloj.
    // Usar el startTime del evento (hora absoluta) para comparar correctamente.
    final eventStart = events.first.startTime;
    final slotMinutes = eventStart != null
        ? eventStart.hour * 60 + eventStart.minute
        : startDuration.hour * 60 + startDuration.minute;
    final nowMinutes = now.hour * 60 + now.minute;
    final isPast = isDayPast || (isToday && slotMinutes < nowMinutes);
    final tileBg = isPast ? const Color(0xFF111111) : const Color(0xFF2A2A2A);

    final availH = boundary.height - 4; // padding top+bottom
    // Cuántas filas de evento caben
    int maxRows = (availH / _rowH).floor();
    final needsOverflow = events.length > maxRows;
    if (needsOverflow) maxRows = ((availH - _overflowH) / _rowH).floor().clamp(0, events.length);
    final visibleEvents = events.take(maxRows.clamp(0, events.length)).toList();
    final remaining = events.length - visibleEvents.length;

    return GestureDetector(
      onTap: () {
        if (events.length == 1 && events.first.event != null) {
          _verDetalles(events.first.event!);
        } else {
          _showOverflowSheet(events);
        }
      },
      child: Container(
        width: boundary.width,
        height: boundary.height,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...visibleEvents.map((e) => _buildEventRow(e)),
            if (remaining > 0)
              SizedBox(
                height: _overflowH,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '+$remaining más',
                    style: TextStyle(
                      color: AppColors.greyLight.withValues(alpha: 0.80),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(CalendarEventData<Agendamiento> event) {
    final ag = event.event;
    final statusColor = event.color;
    final horaLabel = event.startTime != null ? _formatHora12(event.startTime!) : '';
    final barberoLabel = ag?.barbero?.nombreCompleto ?? ag?.barberoNombre ?? '';
    final base = horaLabel.isNotEmpty ? '$horaLabel ${event.title}' : event.title;
    final fullText = barberoLabel.isNotEmpty ? '$base - $barberoLabel' : base;

    return SizedBox(
      height: _rowH,
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(
              fullText,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Overflow popup (equivalente al overflowPopup del web)
  void _showOverflowSheet(List<CalendarEventData<Agendamiento>> events) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF121214),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.65), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  border: Border(bottom: BorderSide(color: AppColors.divider.withValues(alpha: 0.4))),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time_rounded, size: 14, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text(
                      '${events.length} citas en este horario',
                      style: const TextStyle(
                        color: AppColors.greyLightest,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Lista de todas las citas
              ...events.map((event) {
                final ag = event.event;
                final color = event.color;
                final horaLabel = event.startTime != null ? _formatHora12(event.startTime!) : '';
                final barberoLabel = ag?.barbero?.nombreCompleto ?? ag?.barberoNombre ?? '';
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    if (ag != null) _verDetalles(ag);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            barberoLabel.isNotEmpty
                                ? '$horaLabel ${event.title} - $barberoLabel'
                                : '$horaLabel ${event.title}',
                            style: const TextStyle(
                              color: AppColors.greyLightest,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
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
          // Recargar calendario
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.grey, size: 22),
            onPressed: () {
              final state = context.read<AgendamientosBloc>().state;
              final page = state is AgendamientosLoaded ? state.currentPage : 1;
              final weekly = state is AgendamientosLoaded ? state.isWeeklyMode : false;
              context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(page: page, estaSemana: weekly));
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
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
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [
          WeekViewThemeData.dark().copyWith(
            verticalLinesColor: AppColors.divider,
          ),
        ],
      ),
      child: WeekView<Agendamiento>(
      showWeekends: true,
      showLiveTimeLineInAllDays: false,
      eventArranger: const MergeEventArranger<Agendamiento>(),
      timeLineWidth: 56,
      heightPerMinute: 2.0,
      showHalfHours: true,
      minuteSlotSize: MinuteSlotSize.minutes30,
      hourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      halfHourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      startHour: 9,
      endHour: 24,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundColor: AppColors.bg,
      weekNumberBuilder: (date) => Container(color: AppColors.surface),
      weekTitleHeight: 68,
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
        if (events.isEmpty) return;
        if (events.length == 1 && events.first.event != null) {
          _verDetalles(events.first.event!);
        } else {
          _showOverflowSheet(events);
        }
      },
      ),
    );
  }

  Widget _buildMultiDayView() {
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: [
          MultiDayViewThemeData.dark().copyWith(
            verticalLinesColor: AppColors.divider,
          ),
        ],
      ),
      child: MultiDayView<Agendamiento>(
      daysInView: 3,
      showLiveTimeLineInAllDays: false,
      eventArranger: const MergeEventArranger<Agendamiento>(),
      timeLineWidth: 56,
      heightPerMinute: 2.0,
      showHalfHours: true,
      minuteSlotSize: MinuteSlotSize.minutes30,
      hourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      halfHourIndicatorSettings: HourIndicatorSettings(color: AppColors.divider),
      startHour: 9,
      endHour: 24,
      scrollPhysics: const BouncingScrollPhysics(),
      backgroundColor: AppColors.bg,
      weekNumberBuilder: (date) => Container(color: AppColors.surface),
      weekTitleHeight: 68,
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
        if (events.isEmpty) return;
        if (events.length == 1 && events.first.event != null) {
          _verDetalles(events.first.event!);
        } else {
          _showOverflowSheet(events);
        }
      },
    ),
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
    final fechaKey = DayDiscountService.fechaKey(date);
    final descuento = _dayDiscounts[fechaKey] ?? 0;
    final tieneDescuento = descuento > 0;

    Widget label = Container(
      color: AppColors.surface,
      child: Stack(
        children: [
          Container(
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
                  if (tieneDescuento)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7a5c38),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${descuento.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Color(0xFFf3e8d8),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (!_isAdminOrManager) return label;

    return GestureDetector(
      onLongPress: () async {
        await ModalDescuentoDia.show(context, date, descuento, _loadDiscounts);
      },
      child: label,
    );
  }

  Widget _buildTimeLine(DateTime date) {
    final hour = date.hour;
    final minute = date.minute;

    if (hour > 23 || (hour == 23 && minute > 0)) {
      return const SizedBox.shrink();
    }

    final period = hour >= 12 ? 'pm' : 'am';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);

    final String timeText;
    if (minute == 0) {
      timeText = '$displayHour$period';
    } else {
      final displayMinute = minute.toString().padLeft(2, '0');
      timeText = '$displayHour:$displayMinute$period';
    }

    // Con heightPerMinute:2.0 cada celda de 30min mide 60px.
    // La librería da un contenedor de hourHeight(120px) por etiqueta.
    // Para centrar en la primera celda (0-60px): top = 30px - fontSize/2 ≈ 25px.
    return Container(
      width: 56,
      padding: const EdgeInsets.only(right: 8, top: 25),
      alignment: Alignment.topRight,
      child: Text(
        timeText,
        style: const TextStyle(
          color: AppColors.grey,
          fontSize: 10,
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
