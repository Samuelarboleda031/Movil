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
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';

class AgendamientosScreen extends StatefulWidget {
  final AppRole role;

  const AgendamientosScreen({super.key, this.role = AppRole.admin}); // Default a admin por compatibilidad

  @override
  State<AgendamientosScreen> createState() => _AgendamientosScreenState();
}

class _AgendamientosScreenState extends State<AgendamientosScreen> {

  final AuxiliarService _auxiliarService = AuxiliarService();
  String _searchQuery = '';

  List<Agendamiento> _agendamientosFiltrados(List<Agendamiento> agendamientos) {
    final query = _searchQuery.toLowerCase();
    if (query.isEmpty) return agendamientos;
    return agendamientos.where((a) {
      final cliente = a.cliente?.nombreCompleto.toLowerCase() ?? '';
      final barbero = a.barbero?.nombreCompleto.toLowerCase() ?? '';
      final servicio = a.servicio?.nombre.toLowerCase() ?? '';
      return cliente.contains(query) || barbero.contains(query) || servicio.contains(query);
    }).toList();
  }

  Future<void> _verDetalles(Agendamiento ag) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));
    try {
      final detail = await AgendamientoService().obtenerAgendamientoPorId(ag.id!);
      if (mounted) Navigator.pop(context);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Detalles de la Cita'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _detailRow('Cliente:', detail.cliente?.nombreCompleto ?? 'N/A'),
                  _detailRow('Barbero:', detail.barbero?.nombreCompleto ?? 'N/A'),
                  _detailRow('Servicio:', detail.servicio?.nombre ?? detail.paquete?.nombre ?? 'N/A'),
                  _detailRow('Fecha:', detail.fechaCita ?? 'N/A'),
                  _detailRow('Hora:', '${detail.horaInicio} - ${detail.horaFin}'),
                  _detailRow('Monto:', AppFormat.cop(detail.monto ?? 0)),
                  _detailRow('Estado:', detail.estadoCita ?? 'Pendiente'),
                  const Divider(),
                  const Text('Observaciones:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(detail.observaciones ?? 'Sin observaciones'),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      AppToast.showError(context, 'Error: $e');
    }
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
    Barbero? barberoSeleccionado;
    final barberosRaw = await _auxiliarService.obtenerBarberos();
    
    final List<Barbero> opcionesBarberos = [
      Barbero(id: -1, nombre: 'Todos los barberos', apellido: '', documento: '', telefono: '', email: '', direccion: '', estado: true),
      ...barberosRaw
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final esGlobal = barberoSeleccionado?.id == -1;
            return AlertDialog(
              backgroundColor: const Color(0xFF161616),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFFD8B081), width: 0.5)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(esGlobal ? 'CANCELACIÓN GLOBAL' : 'CANCELAR POR BARBERO', 
                    style: TextStyle(color: esGlobal ? Colors.orange : const Color(0xFFD8B081), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Selecciona barbero y días:', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchableSelector<Barbero>(
                      label: 'Barbero',
                      hint: 'Seleccionar...',
                      items: opcionesBarberos,
                      selectedItem: barberoSeleccionado,
                      displayText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                      searchText: (b) => b.id == -1 ? b.nombre : b.nombreCompleto,
                      onSelected: (b) => setStateDialog(() => barberoSeleccionado = b),
                    ),
                    const SizedBox(height: 16),
                    _DaySelectorWidget(
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
  Widget build(BuildContext context) {
    return SessionGuard(
      requiredRole: widget.role,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Citas'),
          actions: [
            if (widget.role != AppRole.client) ...[
               IconButton(
                 icon: const Icon(Icons.event_busy, color: Colors.orange), 
                 onPressed: _cancelarAgendas, 
                 tooltip: 'Cancelar Citas / Días'
               ),
            ]
          ],
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

            if (state is AgendamientosLoaded) {
              agendamientos = state.agendamientos;
              paginacion = state.paginacion;
              currentPage = state.currentPage;
            }

            final filtrados = _agendamientosFiltrados(agendamientos);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar en esta página...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : filtrados.isEmpty
                          ? const Center(child: Text('No hay agendamientos en esta página'))
                          : RefreshIndicator(
                              onRefresh: () async {
                                context.read<AgendamientosBloc>().add(const LoadAgendamientosRequested(page: 1));
                              },
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                                itemCount: filtrados.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == filtrados.length) {
                                    if (paginacion != null && paginacion.totalPages > 1) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 20, bottom: 40),
                                        child: _buildPaginationControls(paginacion.totalPages, currentPage),
                                      );
                                    }
                                    return const SizedBox(height: 80);
                                  }
                                  final ag = filtrados[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: ListTile(
                                      title: Text(ag.cliente?.nombreCompleto ?? 'Cita #${ag.id}'),
                                      subtitle: Text('${ag.fechaCita} | ${ag.horaInicio}\nBarbero: ${ag.barbero?.nombreCompleto ?? "N/A"} | ${AppFormat.cop(ag.monto ?? 0)}'),
                                      trailing: PopupMenuButton(
                                        onSelected: (val) {
                                          if (val == 'details') _verDetalles(ag);
                                          if (val == 'status') _cambiarEstado(ag);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'details', child: Text('Detalles')),
                                          const PopupMenuItem(value: 'status', child: Text('Cambiar Estado')),
                                        ],

                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            );
          },
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
    if (totalPages <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageButton(
            icon: Icons.chevron_left, 
            onTap: currentPage > 1 ? () => context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(page: currentPage - 1)) : null
          ),
          const SizedBox(width: 8),
          ..._buildPageNumbers(totalPages, currentPage),
          const SizedBox(width: 8),
          _buildPageButton(
            icon: Icons.chevron_right, 
            onTap: currentPage < totalPages ? () => context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(page: currentPage + 1)) : null
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages, int currentPage) {
    List<Widget> widgets = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 || i == totalPages || (i >= currentPage - 1 && i <= currentPage + 1)) {
        widgets.add(_buildPageNumberButton(i, currentPage));
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        widgets.add(const Text('...', style: TextStyle(color: Colors.grey)));
      }
    }
    return widgets;
  }

  Widget _buildPageNumberButton(int page, int currentPage) {
    bool isSelected = page == currentPage;
    return GestureDetector(
      onTap: isSelected ? null : () => context.read<AgendamientosBloc>().add(LoadAgendamientosRequested(page: page)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFD8B081) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Text(page.toString(), style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildPageButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.withOpacity(0.3))),
        child: Icon(icon, color: onTap == null ? Colors.grey : Colors.white, size: 20),
      ),
    );
  }
}

class _DaySelectorWidget extends StatefulWidget {
  final Function(List<DateTime>, String, {String? horaInicio, String? horaFin}) onConfirm;
  final bool isGlobal;

  const _DaySelectorWidget({required this.onConfirm, required this.isGlobal});

  @override
  State<_DaySelectorWidget> createState() => __DaySelectorWidgetState();
}

class __DaySelectorWidgetState extends State<_DaySelectorWidget> {
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
              _buildTab(3, '📆 Semana'),
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
        ] else if (_currentTab == 3) ...[
          // SEMANAL
          Text('Cancela todos los días de una semana.', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 12),
          _buildWeekDropdown(),
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
            } else if (_currentTab == 3) { // Semanal
              final datesToProcess = weekDays.where((d) => _selectedWeek == 'Siguiente semana' || d.isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList();
              if (datesToProcess.isEmpty) return;
              widget.onConfirm(datesToProcess, _motivoController.text.trim());
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
