import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'horarios_event.dart';
import 'horarios_state.dart';

class HorariosBloc extends Bloc<HorariosEvent, HorariosState> {
  final HorarioBarberoService horarioService;
  final BarberoService barberoService;
  final AuthService authService;
  final UserContextService userContextService;
  final AppRole role;

  HorariosBloc({
    required this.horarioService,
    required this.barberoService,
    required this.authService,
    required this.userContextService,
    required this.role,
  }) : super(HorariosInitial()) {
    on<LoadHorariosRequested>(_onLoadHorarios);
    on<CreateHorarioRequested>(_onCreateHorario);
    on<CreateMultipleHorariosRequested>(_onCreateMultipleHorarios);
    on<UpdateHorarioRequested>(_onUpdateHorario);
    on<DeleteHorarioRequested>(_onDeleteHorario);
    on<ToggleHorarioStatusRequested>(_onToggleHorarioStatus);
  }

  Future<void> _onLoadHorarios(LoadHorariosRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      final user = await authService.getCurrentUser();
      final currentRole = user?.rolId != null ? roleForRolId(user!.rolId) : role;

      final horarios = await horarioService.obtenerHorarios();
      
      // Filter schedules based on role
      if (currentRole == AppRole.barber) {
        final barbero = await userContextService.obtenerBarberoActual();
        if (barbero != null && barbero.id != null) {
          final horariosFiltrados = horarios.where((h) => h.barberoId == barbero.id).toList();
          emit(HorariosLoaded(horarios: horariosFiltrados));
        } else {
          emit(HorariosLoaded(horarios: []));
        }
      } else {
        // Admin and Superadmin see all
        emit(HorariosLoaded(horarios: horarios));
      }
    } catch (e) {
      emit(HorariosError(message: 'Error al cargar horarios: $e'));
    }
  }

  Future<void> _onCreateHorario(CreateHorarioRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.crearHorario(event.horario);
      emit(const HorarioActionSuccess(message: 'Horario creado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al crear horario: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onCreateMultipleHorarios(CreateMultipleHorariosRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      for (var horario in event.horarios) {
        await horarioService.crearHorario(horario);
      }
      emit(const HorarioActionSuccess(message: 'Horarios creados exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al crear horarios: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onUpdateHorario(UpdateHorarioRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.actualizarHorario(event.horario);
      emit(const HorarioActionSuccess(message: 'Horario actualizado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al actualizar horario: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onDeleteHorario(DeleteHorarioRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.eliminarHorario(event.id);
      emit(const HorarioActionSuccess(message: 'Horario eliminado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al eliminar horario: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onToggleHorarioStatus(ToggleHorarioStatusRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.cambiarEstado(event.id);
      emit(const HorarioActionSuccess(message: 'Estado cambiado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      // If error occurs, might just be because it returns 204 or no body but actually changed
      if (e.toString().contains('El endpoint de estado devolvió 204') || e.toString().contains('FormatException')) {
          emit(const HorarioActionSuccess(message: 'Estado cambiado exitosamente'));
      } else {
          emit(HorariosError(message: 'Error al cambiar estado: $e'));
      }
      add(LoadHorariosRequested());
    }
  }
}
