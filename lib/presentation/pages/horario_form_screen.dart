import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class HorarioFormScreen extends StatefulWidget {
  final HorarioBarbero? horario;
  final AppRole role;
  
  const HorarioFormScreen({super.key, this.horario, required this.role});

  @override
  State<HorarioFormScreen> createState() => _HorarioFormScreenState();
}

class _HorarioFormScreenState extends State<HorarioFormScreen> {
  Barbero? _barberoSeleccionado;
  final List<int> _diasSeleccionados = [];
  TimeOfDay _horaInicio = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaFin = const TimeOfDay(hour: 18, minute: 0);
  bool _estado = true;

  List<Barbero> _barberos = [];
  bool _isLoadingBarberos = true;

  final List<String> _dias = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  void initState() {
    super.initState();
    _loadBarberos();
    
    if (widget.horario != null) {
      _diasSeleccionados.add(widget.horario!.diaSemana);
      _horaInicio = _parseTimeOfDay(widget.horario!.horaInicio);
      _horaFin = _parseTimeOfDay(widget.horario!.horaFin);
      _estado = widget.horario!.estado;
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
            if (widget.horario != null) {
              try {
                _barberoSeleccionado = _barberos.firstWhere((b) => b.id == widget.horario!.barberoId);
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
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isInicio ? _horaInicio : _horaFin,
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
        if (isInicio) {
          _horaInicio = picked;
        } else {
          _horaFin = picked;
        }
      });
    }
  }

  void _save() {
    if (_barberoSeleccionado == null) {
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

    if (widget.horario == null) {
      // Create mode
      final horarios = _diasSeleccionados.map((dia) {
        return HorarioBarbero(
          barberoId: _barberoSeleccionado!.id!,
          diaSemana: dia,
          horaInicio: _formatTimeOfDay(_horaInicio),
          horaFin: _formatTimeOfDay(_horaFin),
          estado: _estado,
        );
      }).toList();
      context.read<HorariosBloc>().add(CreateMultipleHorariosRequested(horarios));
    } else {
      // Edit mode
      final newHorario = HorarioBarbero(
        id: widget.horario!.id,
        barberoId: _barberoSeleccionado!.id!,
        diaSemana: _diasSeleccionados.first,
        horaInicio: _formatTimeOfDay(_horaInicio),
        horaFin: _formatTimeOfDay(_horaFin),
        estado: _estado,
      );
      context.read<HorariosBloc>().add(UpdateHorarioRequested(newHorario));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditMode = widget.horario != null;
    final bool canChangeBarber = !isEditMode && widget.role != AppRole.barber;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(isEditMode ? 'Editar Horario' : 'Nuevo Horario', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.white)),
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
                    if (canChangeBarber)
                      SearchableSelector<Barbero>(
                        label: 'Seleccionar barbero',
                        hint: 'Buscar por nombre...',
                        items: _barberos,
                        selectedItem: _barberoSeleccionado,
                        displayText: (b) => b.nombreCompleto,
                        searchText: (b) => b.nombreCompleto,
                        onSelected: (b) => setState(() => _barberoSeleccionado = b),
                      )
                    else
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

                    // ── SECCIÓN DÍAS ──
                    Text(isEditMode ? '2. DÍA' : '2. DÍAS DE LA SEMANA', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
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
                              if (isEditMode) {
                                _diasSeleccionados.clear();
                                if (val) _diasSeleccionados.add(i);
                              } else {
                                if (val) {
                                  _diasSeleccionados.add(i);
                                } else {
                                  _diasSeleccionados.remove(i);
                                }
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
                    const Text('3. RANGO DE HORAS', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(context, true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.access_time_filled, color: AppColors.gold, size: 28),
                                  const SizedBox(height: 10),
                                  const Text('Hora Inicio', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text(_formatTimeOfDay(_horaInicio), style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _selectTime(context, false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.orangeAccent, size: 28),
                                  const SizedBox(height: 10),
                                  const Text('Hora Fin', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                                  const SizedBox(height: 6),
                                  Text(_formatTimeOfDay(_horaFin), style: const TextStyle(color: AppColors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

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
                        subtitle: Text(_estado ? 'Horario activo para agendar' : 'Horario inactivo', style: const TextStyle(color: AppColors.grey, fontSize: 13)),
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
                            isEditMode ? 'GUARDAR CAMBIOS' : 'CREAR HORARIO',
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
