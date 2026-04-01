import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

import 'agendamientos_event.dart';
import 'agendamientos_state.dart';

class AgendamientosBloc extends Bloc<AgendamientosEvent, AgendamientosState> {
  final AgendamientoService _agendamientoService;
  final EmailJsService _emailJsService;
  final AuthService _authService;

  AgendamientosBloc({
    required AgendamientoService agendamientoService,
    required EmailJsService emailJsService,
    required AuthService authService,
  })  : _agendamientoService = agendamientoService,
        _emailJsService = emailJsService,
        _authService = authService,
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
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
    }

    emit(AgendamientosActionLoading());
    try {
      final updated = event.agendamiento.copyWith(estadoCita: event.nuevoEstado);
      await _agendamientoService.actualizarAgendamiento(updated);
      
      emit(const AgendamientosActionSuccess('Estado actualizado'));
      add(LoadAgendamientosRequested(page: page));
    } catch (e) {
      emit(AgendamientosError('Error al cambiar estado: $e'));
      add(LoadAgendamientosRequested(page: page));
    }
  }

  Future<void> _onLoadAgendamientos(
    LoadAgendamientosRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    emit(AgendamientosLoading());
    try {
      final paginacion = await _agendamientoService.obtenerAgendamientos(
        page: event.page,
        pageSize: 15,
      );
      emit(AgendamientosLoaded(
        agendamientos: paginacion.items,
        paginacion: paginacion,
        currentPage: event.page,
      ));
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
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
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
      emit(const AgendamientosActionSuccess('Cita cancelada'));
      add(LoadAgendamientosRequested(page: page));
    } catch (e) {
      emit(AgendamientosError('Error al cancelar cita: $e'));
      add(LoadAgendamientosRequested(page: page));
    }
  }

  Future<void> _onCancelDias(
    CancelDiasRequested event,
    Emitter<AgendamientosState> emit,
  ) async {
    final currentState = state;
    int page = 1;
    if (currentState is AgendamientosLoaded) {
      page = currentState.currentPage;
    }

    emit(AgendamientosActionLoading());
    try {
      final user = await _authService.getCurrentUser();
      if (user == null || user.id == null) {
        throw Exception('No se pudo identificar al usuario para realizar la acción.');
      }

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
      
      emit(const AgendamientosActionSuccess('Citas canceladas exitosamente'));
      add(LoadAgendamientosRequested(page: page));
    } catch (e) {
      emit(AgendamientosError('Error al cancelar días: $e'));
      add(LoadAgendamientosRequested(page: page));
    }
  }
}
