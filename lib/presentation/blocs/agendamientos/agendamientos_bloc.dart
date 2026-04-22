import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/paginacion.dart';

import 'agendamientos_event.dart';
import 'agendamientos_state.dart';

class AgendamientosBloc extends Bloc<AgendamientosEvent, AgendamientosState> {
  final AgendamientoService _agendamientoService;
  final EmailJsService _emailJsService;
  final AuthService _authService;
  final UserContextService _userContextService;

  AgendamientosBloc({
    required AgendamientoService agendamientoService,
    required EmailJsService emailJsService,
    required AuthService authService,
    required UserContextService userContextService,
  })  : _agendamientoService = agendamientoService,
        _emailJsService = emailJsService,
        _authService = authService,
        _userContextService = userContextService,
        super(AgendamientosInitial()) {
    on<LoadAgendamientosRequested>(_onLoadAgendamientos);
    on<CancelAgendamientoRequested>(_onCancelAgendamiento);
    on<CancelDiasRequested>(_onCancelDias);
    on<ChangeAgendamientoStatusRequested>(_onChangeStatus);
  }

  Future<void> _onChangeStatus(
    ChangeAgendamientoStatusRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    final currentState = state;
    int page = 1;
    bool currentMode = false;
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
      currentMode = currentState.isWeeklyMode;
    }

    emit(AgendamientosActionLoading());
    try {
      final updated = event.agendamiento.copyWith(estadoCita: event.nuevoEstado);
      await _agendamientoService.actualizarAgendamiento(updated);
      
      emit(const AgendamientosActionSuccess('Estado actualizado'));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    } catch (e) {
      emit(AgendamientosError('Error al cambiar estado: $e'));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    }
  }

  Future<void> _onLoadAgendamientos(
    LoadAgendamientosRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    emit(AgendamientosLoading());
    try {
      final user = await _authService.getCurrentUser();
      if (user == null || user.rolId == null) {
        throw Exception('Usuario no autenticado o sin rol asignado.');
      }
      
      final role = roleForRolId(user.rolId);

      if (role == AppRole.client) {
        final cliente = await _userContextService.obtenerClienteActual();
        if (cliente == null || cliente.id == null) {
          throw Exception('No tienes un perfil de cliente configurado. Completa tu perfil.');
        }
        
        final bool isWeekly = event.estaSemana ?? false;
        const int pageSize = 10;

        final paginacion = await _agendamientoService.obtenerAgendamientosPorCliente(
          cliente.id!,
          page: event.page,
          pageSize: pageSize,
          estaSemana: event.estaSemana,
        );
        
        if (isWeekly && paginacion.items.isEmpty) {
          add(const LoadAgendamientosRequested(page: 1, estaSemana: false));
          return;
        }

        emit(AgendamientosLoaded(
          agendamientos: paginacion.items,
          paginacion: paginacion,
          currentPage: event.page,
          isWeeklyMode: isWeekly,
        ));
      } else if (role == AppRole.barber) {
        final barberoLocal = await _userContextService.obtenerBarberoActual();
        if (barberoLocal == null) throw Exception('No se encontró el perfil de barbero.');

        final bool isWeekly = event.estaSemana ?? false;
        final paginacion = await _agendamientoService.obtenerAgendamientos(
          page: 1, 
          pageSize: 2000,
          estaSemana: event.estaSemana,
        );
        final propios = paginacion.items.where((a) => 
           a.barberoId == barberoLocal.id || 
           (a.barbero?.email?.toLowerCase() == barberoLocal.email?.toLowerCase())
        ).toList();
        
        if (isWeekly && propios.isEmpty) {
          add(const LoadAgendamientosRequested(page: 1, estaSemana: false));
          return;
        }

        emit(AgendamientosLoaded(
          agendamientos: propios,
          paginacion: null,
          currentPage: 1,
          isWeeklyMode: isWeekly,
        ));
      } else {
        // MODO ADMIN / MANAGER
        final bool isWeekly = event.estaSemana ?? false;
        const int pageSize = 10;
        print('🔍 [AgendamientosBloc] Cargando citas ADMIN/MANAGER. isWeekly: $isWeekly');
        final paginacion = await _agendamientoService.obtenerAgendamientos(
          page: event.page,
          pageSize: pageSize,
          estaSemana: event.estaSemana,
        );
        print('✅ [AgendamientosBloc] Se obtuvieron ${paginacion.items.length} citas de un total de ${paginacion.totalCount}');

        if (isWeekly && paginacion.items.isEmpty) {
          add(const LoadAgendamientosRequested(page: 1, estaSemana: false));
          return;
        }

        emit(AgendamientosLoaded(
          agendamientos: paginacion.items,
          paginacion: paginacion,
          currentPage: event.page,
          isWeeklyMode: isWeekly,
        ));
      }
    } catch (e) {
      emit(AgendamientosError('Error al cargar agendamientos: $e'));
    }
  }

  Future<void> _onCancelAgendamiento(
    CancelAgendamientoRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    final currentState = state;
    int page = 1;
    bool currentMode = false;
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
      currentMode = currentState.isWeeklyMode;
    }

    emit(AgendamientosActionLoading());
    try {
      await _agendamientoService.cancelarAgendamiento(event.agendamiento.id!);
      
      if (event.agendamiento.cliente?.email != null) {
        await _emailJsService.notificarCancelacion(
          clienteEmail: event.agendamiento.cliente!.email!,
          clienteNombre: event.agendamiento.cliente!.nombreCompleto,
          barberoNombre: event.agendamiento.barbero?.nombreCompleto ?? 'Tu barbero',
          fechaOriginal: event.agendamiento.fechaCita ?? '',
        );
      }

      emit(const AgendamientosActionSuccess('Agendamiento cancelado'));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    } catch (e) {
      emit(AgendamientosError('Error al cancelar: $e'));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    }
  }

  Future<void> _onCancelDias(
    CancelDiasRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    final currentState = state;
    int page = 1;
    bool currentMode = false;
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
      currentMode = currentState.isWeeklyMode;
    }

    emit(AgendamientosActionLoading());
    try {
      final user = await _authService.getCurrentUser();
      if (user == null || user.id == null) {
        throw Exception('No se pudo identificar al usuario para realizar la acción.');
      }

      if (event.horaInicio != null && event.horaFin != null && event.fechas.isNotEmpty) {
        // MODO POR HORA
        final allApps = await _agendamientoService.obtenerAgendamientos(page: 1, pageSize: 5000);
        final targetDateStr = DateFormat('yyyy-MM-dd').format(event.fechas.first);
        
        int parseMinutes(String t) {
          final parts = t.split(':');
          if (parts.length < 2) return 0;
          return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
        }
        
        final startMin = parseMinutes(event.horaInicio!);
        final endMin = parseMinutes(event.horaFin!);
        
        int canceladas = 0;
        for (var cita in allApps.items) {
           if (cita.fechaCita != targetDateStr) continue;
           if (event.barberoId != -1 && cita.barberoId != event.barberoId) continue;
           final status = (cita.estadoCita ?? '').toLowerCase();
           if (status == 'cancelada' || status == 'cancelado' || status == 'completada' || status == 'finalizado') continue;
           
           final citaMin = parseMinutes(cita.horaInicio ?? '00:00');
           if (citaMin >= startMin && citaMin < endMin) {
               await _agendamientoService.cancelarAgendamiento(cita.id!);
               canceladas++;
               if (cita.cliente?.email != null) {
                 await _emailJsService.notificarCancelacion(
                   clienteEmail: cita.cliente!.email!,
                   clienteNombre: cita.cliente!.nombreCompleto,
                   barberoNombre: cita.barbero?.nombreCompleto ?? 'Tu barbero',
                   fechaOriginal: '${cita.fechaCita} a las ${cita.horaInicio}',
                   motivo: event.motivo.isNotEmpty ? event.motivo : 'Cancelación de horario especial',
                 );
               }
           }
        }
        emit(AgendamientosActionSuccess('Se cancelaron $canceladas cita(s) en ese rango horario.'));
      } else {
        // MODO DÍAS
        for (var d in event.fechas) {
          final fechaStr = DateFormat('yyyy-MM-dd').format(d);
          if (event.barberoId == -1) { // Global
            await _agendamientoService.cancelarDiaCompleto(
              fechaStr,
              motivo: event.motivo.isNotEmpty ? event.motivo : 'El local cerrará este día por motivos administrativos.'
            );
          } else {
            await _agendamientoService.cancelarDiaBarbero(
              barberoId: event.barberoId,
              fecha: fechaStr,
              usuarioSolicitanteId: user.id!,
              motivo: event.motivo.isNotEmpty ? event.motivo : 'Cancelado por Administrador desde App Móvil',
            );
          }
        }
        emit(const AgendamientosActionSuccess('Días cancelados exitosamente'));
      }
      
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    } catch (e) {
      emit(AgendamientosError('Error al cancelar días: $e'));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    }
  }
}
