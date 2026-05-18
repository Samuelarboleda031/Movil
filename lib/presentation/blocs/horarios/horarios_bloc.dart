import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
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
    on<CreateHorarioSemanalRequested>(_onCreateHorarioSemanal);
    on<UpdateHorarioSemanalRequested>(_onUpdateHorarioSemanal);
    on<DeleteHorarioSemanalRequested>(_onDeleteHorarioSemanal);
    on<ToggleHorarioSemanalStatusRequested>(_onToggleStatus);
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

  Future<void> _onCreateHorarioSemanal(CreateHorarioSemanalRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.crearHorarioSemanal(event.horario);
      emit(const HorarioActionSuccess(message: 'Horario semanal creado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al crear horario semanal: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onUpdateHorarioSemanal(UpdateHorarioSemanalRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.actualizarHorarioSemanal(event.id, event.horario);
      emit(const HorarioActionSuccess(message: 'Horario semanal actualizado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al actualizar horario semanal: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onDeleteHorarioSemanal(DeleteHorarioSemanalRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.eliminarHorarioSemanal(event.id);
      emit(const HorarioActionSuccess(message: 'Horario semanal eliminado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al eliminar horario semanal: $e'));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onToggleStatus(ToggleHorarioSemanalStatusRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      final user = await authService.getCurrentUser();
      final userId = user?.id ?? 0;
      final result = await horarioService.cambiarEstado(event.id, event.nuevoEstado, usuarioSolicitanteId: userId);

      // Si se desactiva el horario (pasa a Finalizado) y la API devuelve citas canceladas
      if (!event.nuevoEstado && result != null) {
        final List<dynamic>? detalle = result['detalle'] ?? result['Detalle'];
        if (detalle != null && detalle.isNotEmpty) {
          final emailService = EmailJsService();
          
          // Despachar el envío de correos en segundo plano para no colgar la interfaz gráfica (UI)
          Future.microtask(() async {
            for (final item in detalle) {
              final String? clienteEmail = item['clienteCorreo'] ?? item['ClienteCorreo'];
              if (clienteEmail != null && clienteEmail.isNotEmpty) {
                String fechaStr = item['fechaHoraOriginal'] ?? item['FechaHoraOriginal'] ?? 'Fecha no especificada';
                try {
                  final date = DateTime.parse(fechaStr);
                  fechaStr = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                } catch (_) {}

                try {
                  await emailService.notificarCancelacion(
                    clienteNombre: item['clienteNombre'] ?? item['ClienteNombre'] ?? 'Cliente',
                    clienteEmail: clienteEmail,
                    barberoNombre: item['barberoNombre'] ?? item['BarberoNombre'] ?? 'Barbero',
                    fechaOriginal: fechaStr,
                    motivo: 'El horario semanal ha sido finalizado/desactivado por la administración.',
                  );
                } catch (e) {
                  print('Error al enviar correo en background: $e');
                }
              }
            }
          });
        }
      }

      emit(const HorarioActionSuccess(message: 'Estado cambiado exitosamente'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: 'Error al cambiar estado: $e'));
      add(LoadHorariosRequested());
    }
  }
}
