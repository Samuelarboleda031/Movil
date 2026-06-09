import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_bloc.dart';
import 'package:parte_movil/presentation/blocs/horarios/horarios_event.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/presentation/widgets/searchable_selector.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/core/utils/app_format.dart';

class HorarioFormScreen extends StatefulWidget {
  final HorarioSemanal? horarioSemanal;
  final AppRole role;
  /// Barberos activos que no tienen horario esta semana.
  /// Si se proporciona, aparece la opción "asignar a todos".
  final List<Barbero> barberosLibres;

  const HorarioFormScreen({
    super.key,
    this.horarioSemanal,
    required this.role,
    this.barberosLibres = const [],
  });

  @override
  State<HorarioFormScreen> createState() => _HorarioFormScreenState();
}

class _HorarioFormScreenState extends State<HorarioFormScreen> {
  Barbero? _barberoSeleccionado;
  final List<int> _diasSeleccionados = [];
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 18, minute: 0);
  bool _estado = true; // true = Activo, false = Finalizado
  bool _asignarATodos = false;
  DateTime _fechaInicioSemana = DateTime.now();

  List<Barbero> _barberos = [];
  bool _isLoadingBarberos = true;

  final List<String> _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  void initState() {
    super.initState();
    _loadBarberos();
    
    if (widget.horarioSemanal != null) {
      final h = widget.horarioSemanal!;
      for (var d in h.detalles) {
        final mappedDay = d.diaSemana == 7 ? 0 : d.diaSemana;
        if (!_diasSeleccionados.contains(mappedDay)) {
          _diasSeleccionados.add(mappedDay);
        }
      }
      if (h.detalles.isNotEmpty) {
        _horaInicio = _parseTimeOfDay(h.detalles.first.horaInicio);
        _horaFin = _parseTimeOfDay(h.detalles.first.horaFin);
      }
      _estado = h.estado == 'Activo';
      _fechaInicioSemana = DateTime.tryParse(h.fechaInicioSemana) ?? DateTime.now();
    } else {
      // Por defecto seleccionar de Lunes a Viernes (1 a 5)
      _diasSeleccionados.addAll([1, 2, 3, 4, 5]);
      // Usar el lunes de la semana actual (no el próximo)
      final now = DateTime.now();
      _fechaInicioSemana = now.subtract(Duration(days: now.weekday - 1));
    }
  }

  Future<void> _loadBarberos() async {
    try {
      final barberos = await BarberoService().obtenerBarberos();
      Barbero? currentBarber;
      
      if (widget.role == AppRole.barber) {
        currentBarber = await UserContextService().obtenerBarberoActual();
      }

      if (mounted) {
        setState(() {
          if (widget.role == AppRole.barber && currentBarber != null) {
            _barberos = barberos.where((b) => b.id == currentBarber!.id).toList();
            _barberoSeleccionado = currentBarber;
          } else {
            _barberos = barberos;
            if (widget.horarioSemanal != null) {
              try {
                _barberoSeleccionado = _barberos.firstWhere((b) => b.id == widget.horarioSemanal!.barberoId);
              } catch (_) {}
            }
          }
          _isLoadingBarberos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingBarberos = false);
      }
    }
  }

  TimeOfDay _parseTimeOfDay(String s) {
    try {
      final parts = s.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectTime(BuildContext context, bool isInicio) async {
    final initial = isInicio ? _horaInicio : _horaFin;
    DateTime temp = DateTime(2000, 1, 1, initial.hour, initial.minute);
    await showModalBottomSheet(
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
            color: Color(0xFF1C1C1E),
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
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              StatefulBuilder(builder: (ctx, setSheet) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isInicio ? 'Hora de Inicio' : 'Hora de Fin',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 220,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: temp,
                        use24hFormat: false,
                        minuteInterval: 1,
                        backgroundColor: Colors.transparent,
                        onDateTimeChanged: (dt) {
                          temp = dt;
                          setSheet(() {});
                        },
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancelar', style: TextStyle(color: AppColors.gold, fontSize: 17)),
                            ),
                          ),
                          Container(width: 1, height: 48, color: AppColors.divider.withValues(alpha: 0.5)),
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  if (isInicio) {
                                    _horaInicio = TimeOfDay(hour: temp.hour, minute: temp.minute);
                                  } else {
                                    _horaFin = TimeOfDay(hour: temp.hour, minute: temp.minute);
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                              child: const Text('Aceptar', style: TextStyle(color: AppColors.gold, fontSize: 17, fontWeight: FontWeight.w600)),
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

  Widget _buildTimeCard(BuildContext context, {required bool isInicio}) {
    final accentColor = isInicio ? AppColors.gold : Colors.orangeAccent;
    final timeStr = AppFormat.to12h(_formatTimeOfDay(isInicio ? _horaInicio : _horaFin));
    final label = isInicio ? 'Inicio' : 'Fin';
    return GestureDetector(
      onTap: () => _selectTime(context, isInicio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.access_time_rounded, color: accentColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.edit_outlined, color: accentColor.withValues(alpha: 0.6), size: 18),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaInicioSemana,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: Colors.black,
            surface: AppColors.card,
            onSurface: AppColors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _fechaInicioSemana = picked;
      });
    }
  }

  void _save() {
    if (!_asignarATodos && _barberoSeleccionado == null) {
      AppToast.showError(context, 'Seleccione un barbero');
      return;
    }
    if (_diasSeleccionados.isEmpty) {
      AppToast.showError(context, 'Seleccione al menos un día');
      return;
    }

    final startMin = _horaInicio.hour * 60 + _horaInicio.minute;
    final endMin = _horaFin.hour * 60 + _horaFin.minute;
    if (startMin >= endMin) {
      AppToast.showError(context, 'La hora de inicio debe ser anterior a la hora de fin');
      return;
    }

    final fechaInicioStr = DateFormat('yyyy-MM-dd').format(_fechaInicioSemana);
    final fechaFinStr = DateFormat('yyyy-MM-dd').format(_fechaInicioSemana.add(const Duration(days: 6)));
    final detalles = _diasSeleccionados.map((dia) {
      final mappedDay = dia == 0 ? 7 : dia;
      return DetalleHorarioDia(
        diaSemana: mappedDay,
        horaInicio: _formatTimeOfDay(_horaInicio),
        horaFin: _formatTimeOfDay(_horaFin),
      );
    }).toList();

    if (_asignarATodos) {
      final count = widget.barberosLibres.length;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Confirmar asignación', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
          content: Text(
            '¿Asignar este horario a $count barbero${count != 1 ? "s" : ""} sin horario esta semana?',
            style: const TextStyle(color: AppColors.greyLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.read<HorariosBloc>().add(CreateHorarioParaTodosRequested(
                  barberoIds: widget.barberosLibres.map((b) => b.id!).toList(),
                  templateHorario: HorarioSemanal(
                    barberoId: 0,
                    fechaInicioSemana: fechaInicioStr,
                    fechaFinSemana: fechaFinStr,
                    estado: _estado ? 'Activo' : 'Finalizado',
                    detalles: detalles,
                  ),
                ));
                Navigator.pop(context);
              },
              child: const Text('Confirmar', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return;
    }

    if (widget.horarioSemanal == null) {
      context.read<HorariosBloc>().add(CreateHorarioSemanalRequested(HorarioSemanal(
        barberoId: _barberoSeleccionado!.id!,
        fechaInicioSemana: fechaInicioStr,
        fechaFinSemana: fechaFinStr,
        estado: _estado ? 'Activo' : 'Finalizado',
        detalles: detalles,
      )));
    } else {
      final updated = HorarioSemanal(
        id: widget.horarioSemanal!.id,
        barberoId: _barberoSeleccionado!.id!,
        fechaInicioSemana: fechaInicioStr,
        fechaFinSemana: fechaFinStr,
        estado: _estado ? 'Activo' : 'Finalizado',
        detalles: detalles,
      );
      context.read<HorariosBloc>().add(UpdateHorarioSemanalRequested(updated.id!, updated));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.horarioSemanal != null;
    final bool canChangeBarber = !isEditMode && widget.role != AppRole.barber;
    final fechaFinSemana = _fechaInicioSemana.add(const Duration(days: 6));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar Horario Semanal' : 'Nuevo Horario Semanal', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.white)),
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.gold),
      ),
      body: _isLoadingBarberos
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── SECCIÓN BARBERO ──
                    const Text('1. BARBERO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),

                    // Toggle "asignar a todos" (solo en modo creación para admin/manager con barberos libres)
                    if (canChangeBarber && widget.barberosLibres.isNotEmpty) ...[
                      GestureDetector(
                        onTap: () => setState(() {
                          _asignarATodos = !_asignarATodos;
                          if (_asignarATodos) _barberoSeleccionado = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _asignarATodos ? AppColors.gold.withOpacity(0.1) : AppColors.card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _asignarATodos ? AppColors.gold : AppColors.divider,
                              width: _asignarATodos ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.group_rounded, color: AppColors.gold, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Asignar a todos los barberos libres',
                                      style: TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${widget.barberosLibres.length} barbero${widget.barberosLibres.length != 1 ? "s" : ""} sin horario esta semana',
                                      style: const TextStyle(color: AppColors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _asignarATodos ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                                color: _asignarATodos ? AppColors.gold : AppColors.grey,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.divider)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'O BARBERO ESPECÍFICO',
                              style: TextStyle(color: AppColors.grey.withOpacity(0.7), fontSize: 10, letterSpacing: 0.8),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppColors.divider)),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    if (canChangeBarber && !_asignarATodos)
                      SearchableSelector<Barbero>(
                        label: 'Seleccionar barbero',
                        hint: 'Buscar por nombre...',
                        items: _barberos,
                        selectedItem: _barberoSeleccionado,
                        displayText: (b) => b.nombreCompleto,
                        searchText: (b) => b.nombreCompleto,
                        onSelected: (b) => setState(() => _barberoSeleccionado = b),
                      )
                    else if (!canChangeBarber)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.15), shape: BoxShape.circle),
                              child: const Icon(Icons.person, color: AppColors.gold, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Barbero Asignado', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  Text(_barberoSeleccionado?.nombreCompleto ?? 'Desconocido', style: const TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            if (isEditMode) const Icon(Icons.lock, color: AppColors.grey, size: 16),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 32),

                    // ── SECCIÓN FECHAS DE LA SEMANA ──
                    const Text('2. FECHAS DE LA SEMANA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColors.gold, size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Semana de Trabajo', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('dd MMM yyyy').format(_fechaInicioSemana)} al ${DateFormat('dd MMM yyyy').format(fechaFinSemana)}',
                                    style: const TextStyle(color: AppColors.white, fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_calendar, color: AppColors.grey, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── SECCIÓN DÍAS ──
                    const Text('3. DÍAS DE LA SEMANA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(_dias.length, (i) {
                        final isSelected = _diasSeleccionados.contains(i);
                        return FilterChip(
                          label: Text(_dias[i], style: TextStyle(color: isSelected ? AppColors.bg : AppColors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                          selected: isSelected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _diasSeleccionados.add(i);
                              } else {
                                _diasSeleccionados.remove(i);
                              }
                            });
                          },
                          selectedColor: AppColors.gold,
                          backgroundColor: AppColors.card,
                          checkmarkColor: AppColors.bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSelected ? AppColors.gold : AppColors.divider),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        );
                      }),
                    ),

                    const SizedBox(height: 32),

                    // ── SECCIÓN HORAS ──
                    const Text('4. RANGO DE HORAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    _buildTimeCard(context, isInicio: true),
                    const SizedBox(height: 12),
                    _buildTimeCard(context, isInicio: false),

                    const SizedBox(height: 32),

                    // ── SECCIÓN ESTADO ──
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: const Text('Estado Operativo', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                        subtitle: Text(_estado ? 'Horario semanal activo' : 'Horario finalizado', style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                        value: _estado,
                        activeColor: AppColors.gold,
                        activeTrackColor: AppColors.gold.withOpacity(0.3),
                        inactiveThumbColor: AppColors.grey,
                        inactiveTrackColor: AppColors.bg,
                        onChanged: (val) => setState(() => _estado = val),
                      ),
                    ),

                    const SizedBox(height: 48),

                    // ── BOTÓN GUARDAR ──
                    ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.bg,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: AppColors.gold.withOpacity(0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isEditMode ? Icons.save : Icons.add_circle_outline, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            isEditMode ? 'GUARDAR CAMBIOS' : 'CREAR HORARIO SEMANAL',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
