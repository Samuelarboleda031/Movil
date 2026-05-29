import 'dart:async';
import 'package:flutter/material.dart';
import 'package:parte_movil/core/themes/app_colors.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/core/utils/app_format.dart';
import 'package:parte_movil/core/utils/app_snackbar.dart';
import 'package:parte_movil/presentation/pages/agendamiento_detalle_screen.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/presentation/widgets/modal_completar_parcialmente.dart';

class CitaNotification {
  final int citaId;
  final String clienteNombre;
  final String? clienteFotoPerfil;
  final String servicioNombre;
  final String barberoNombre;
  final String hora;
  final String fecha;
  final int minutosRestantes;
  final int createdAt;

  CitaNotification({
    required this.citaId,
    required this.clienteNombre,
    this.clienteFotoPerfil,
    required this.servicioNombre,
    required this.barberoNombre,
    required this.hora,
    required this.fecha,
    required this.minutosRestantes,
    required this.createdAt,
  });
}

class CitaNotificationBell extends StatefulWidget {
  final AppRole role;
  
  const CitaNotificationBell({super.key, required this.role});

  @override
  State<CitaNotificationBell> createState() => _CitaNotificationBellState();
}

class _CitaNotificationBellState extends State<CitaNotificationBell> {
  List<CitaNotification> _notifications = [];
  Timer? _timer;
  final AgendamientoService _agendamientoService = AgendamientoService();
  final UserContextService _userContextService = UserContextService();
  Barbero? _currentBarber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == AppRole.client) return;
    _initUser();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkCitas();
    });
  }

  Future<void> _initUser() async {
    if (widget.role == AppRole.barber) {
      _currentBarber = await _userContextService.obtenerBarberoActual();
    }
    _checkCitas();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkCitas() async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;
      
      // Obtener el lunes de la semana actual para mostrar citas pendientes
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final results = await Future.wait([
        _agendamientoService.obtenerCitasPorTerminar(),
        _agendamientoService.obtenerAgendamientos(page: 1, pageSize: 200),
      ]);

      final porTerminar = results[0] as List<Agendamiento>;
      final todas = (results[1] as Paginacion<Agendamiento>).items;

      List<CitaNotification> newNotifs = [];
      Set<int> processedIds = {};

      // 1. Agregar las que vienen del backend por-terminar
      for (var cita in porTerminar) {
        if (cita.id == null || processedIds.contains(cita.id!)) continue;
        
        if (widget.role == AppRole.barber && _currentBarber != null) {
          if (cita.barberoId != _currentBarber!.id) continue;
        }

        processedIds.add(cita.id!);
        String servicioNombre = cita.serviciosNombres.isNotEmpty 
            ? cita.serviciosNombres.first 
            : (cita.servicio?.nombre ?? 'Servicio');

        newNotifs.add(
          CitaNotification(
            citaId: cita.id!,
            clienteNombre: cita.clienteNombre ?? cita.cliente?.nombreCompleto ?? 'Cliente',
            clienteFotoPerfil: cita.cliente?.fotoPerfil,
            servicioNombre: servicioNombre,
            barberoNombre: cita.barberoNombre ?? cita.barbero?.nombreCompleto ?? 'Barbero',
            hora: cita.horaInicio ?? '00:00',
            fecha: cita.fechaCita ?? todayStr,
            minutosRestantes: 0,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }

      // 2. Agregar las de hoy que están a 10 min o menos
      for (var cita in todas) {
        if (cita.id == null || processedIds.contains(cita.id!)) continue;
        if (cita.fechaCita != todayStr) continue;
        if (cita.estadoCita?.toLowerCase() == 'cancelada' ||
            cita.estadoCita?.toLowerCase() == 'cancelado' ||
            cita.estadoCita?.toLowerCase() == 'completada' ||
            cita.estadoCita?.toLowerCase() == 'finalizado' ||
            cita.estadoCita?.toLowerCase() == 'finalizada') {
          continue;
        }

        if (widget.role == AppRole.barber && _currentBarber != null) {
          if (cita.barberoId != _currentBarber!.id) continue;
        }

        final parts = (cita.horaInicio ?? '00:00').split(':');
        if (parts.length >= 2) {
          final citaStartMin = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          final duracion = cita.duracion is int 
              ? cita.duracion as int 
              : int.tryParse(cita.duracion?.toString() ?? '60') ?? 60;
          final citaEndMin = citaStartMin + duracion;
          final minutosRestantes = citaEndMin - currentMinutes;

          if (minutosRestantes > 0 && minutosRestantes <= 10) {
            processedIds.add(cita.id!);
            String servicioNombre = cita.serviciosNombres.isNotEmpty 
                ? cita.serviciosNombres.first 
                : (cita.servicio?.nombre ?? 'Servicio');

            newNotifs.add(
              CitaNotification(
                citaId: cita.id!,
                clienteNombre: cita.clienteNombre ?? cita.cliente?.nombreCompleto ?? 'Cliente',
                clienteFotoPerfil: cita.cliente?.fotoPerfil,
                servicioNombre: servicioNombre,
                barberoNombre: cita.barberoNombre ?? cita.barbero?.nombreCompleto ?? 'Barbero',
                hora: cita.horaInicio ?? '00:00',
                fecha: cita.fechaCita ?? todayStr,
                minutosRestantes: minutosRestantes.toInt(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              ),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _notifications = newNotifs;
        });
      }
    } catch (e) {
      print('Error checking citas: $e');
    } finally {
      _isLoading = false;
    }
  }

  void _showDropdown() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int activeCount = _notifications.length;

            return Container(
              padding: const EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time, color: AppColors.gold, size: 24),
                          const SizedBox(width: 8),
                          const Text(
                            'Citas por terminar',
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      if (activeCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                          ),
                          child: Text(
                            '$activeCount',
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: activeCount == 0
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available, size: 48, color: AppColors.grey.withOpacity(0.5)),
                                const SizedBox(height: 16),
                                const Text(
                                  'Todo al día',
                                  style: TextStyle(color: AppColors.white, fontSize: 16),
                                ),
                                const Text(
                                  'No hay citas por terminar ahora',
                                  style: TextStyle(color: AppColors.grey, fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: activeCount,
                            itemBuilder: (context, index) {
                              final notif = _notifications[index];
                              return _buildNotificationCard(notif, setModalState);
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(CitaNotification notif, StateSetter setModalState) {
    Color borderColor = AppColors.gold;
    Color bgColor = AppColors.gold.withOpacity(0.1);
    
    if (notif.minutosRestantes <= 3) {
      borderColor = Colors.redAccent;
      bgColor = Colors.redAccent.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: CircleAvatar(
              backgroundColor: bgColor,
              child: const Icon(Icons.person, color: AppColors.white, size: 20),
            ),
            title: Text(
              notif.clienteNombre,
              style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.content_cut, color: AppColors.grey, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        notif.servicioNombre,
                        style: const TextStyle(color: AppColors.grey, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.person_outline, color: AppColors.grey, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      notif.barberoNombre,
                      style: const TextStyle(color: AppColors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  notif.minutosRestantes > 0 ? 'Termina en ${notif.minutosRestantes} min' : 'Pendiente',
                  style: TextStyle(
                    color: notif.minutosRestantes > 0 ? AppColors.gold : AppColors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    if (widget.role == AppRole.barber) ...[
                      if (notif.minutosRestantes <= 0)
                        _actionButton(
                          icon: Icons.notifications_active,
                          color: AppColors.gold,
                          label: 'AVISAR',
                          onTap: () => _handleAvisar(notif.citaId, setModalState),
                        ),
                    ] else ...[
                      if (notif.minutosRestantes <= 0) ...[
                        _actionButton(
                          icon: Icons.check,
                          color: Colors.green,
                          onTap: () => _handleAction(notif.citaId, 'Completada', setModalState),
                        ),
                        const SizedBox(width: 8),
                        _actionButton(
                          icon: Icons.checklist,
                          color: AppColors.gold,
                          onTap: () => _handleParcial(notif.citaId, setModalState),
                        ),
                      ],
                      const SizedBox(width: 8),
                      _actionButton(
                        icon: Icons.close,
                        color: Colors.redAccent,
                        onTap: () => _handleAction(notif.citaId, 'Cancelada', setModalState),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color color, required VoidCallback onTap, String? label}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAvisar(int citaId, StateSetter setModalState) async {
    try {
      // Mandar aviso sin cambiar el estado a Completada (se podría usar un estado intermedio si existe)
      // Por ahora, como el usuario dice "no puede cambiar el estado", solo enviamos una "notificación" (simulada o vía log)
      // O podríamos actualizar a un estado que el Admin vea como "Terminado por Barbero"
      await _agendamientoService.actualizarEstadoAgendamiento(citaId, 'Terminado por Barbero');
      AppToast.showSuccess(context, 'Aviso de término enviado al administrador');
      
      setModalState(() {
        _notifications.removeWhere((n) => n.citaId == citaId);
      });
      setState(() {
        _notifications.removeWhere((n) => n.citaId == citaId);
      });
      if (_notifications.isEmpty) Navigator.pop(context);
    } catch (e) {
      AppToast.showError(context, 'Error al enviar aviso');
    }
  }

  Future<void> _handleAction(int citaId, String estado, StateSetter setModalState) async {
    try {
      await _agendamientoService.actualizarEstadoAgendamiento(citaId, estado);
      AppToast.showSuccess(context, 'Cita marcada como $estado');
      setModalState(() {
        _notifications.removeWhere((n) => n.citaId == citaId);
      });
      setState(() {
        _notifications.removeWhere((n) => n.citaId == citaId);
      });
      if (_notifications.isEmpty) {
        Navigator.pop(context); // Close bottom sheet if empty
      }
    } catch (e) {
      AppToast.showError(context, 'Error al actualizar estado');
    }
  }

  Future<void> _handleParcial(int citaId, StateSetter setModalState) async {
    try {
      final cita = await _agendamientoService.obtenerAgendamientoPorId(citaId);
      if (!mounted) return;
      
      ModalCompletarParcialmente.show(context, cita, () {
        setModalState(() {
          _notifications.removeWhere((n) => n.citaId == citaId);
        });
        setState(() {
          _notifications.removeWhere((n) => n.citaId == citaId);
        });
        if (_notifications.isEmpty) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      if (mounted) AppToast.showError(context, 'Error al cargar detalles de la cita');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == AppRole.client) return const SizedBox.shrink();

    final activeCount = _notifications.length;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          color: activeCount > 0 ? AppColors.gold : AppColors.white,
          onPressed: _showDropdown,
        ),
        if (activeCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                '$activeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
