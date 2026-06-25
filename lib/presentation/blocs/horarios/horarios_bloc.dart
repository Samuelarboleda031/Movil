import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/data/datasources/horario_barbero_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'horarios_event.dart';
import 'horarios_state.dart';
import 'package:parte_movil/core/utils/logger.dart';

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
    on<CreateHorarioParaTodosRequested>(_onCreateParaTodos);
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

      // Calcular lunes de la semana actual para ocultar semanas pasadas
      final now = DateTime.now();
      final lunes = now.subtract(Duration(days: now.weekday - 1));
      final lunesStr =
          '${lunes.year.toString().padLeft(4, '0')}-'
          '${lunes.month.toString().padLeft(2, '0')}-'
          '${lunes.day.toString().padLeft(2, '0')}';

      // Filtrar: excluir Finalizados, semanas anteriores y barberos eliminados/inválidos
      // Un barbero eliminado llega con BarberoNombre null, vacío, o con nombre genérico
      // como "Usuario" porque su registro de usuario fue eliminado
      final barberoActivos = await barberoService.obtenerBarberos();
      final barberoActivosIds = barberoActivos
          .where((b) => b.estado == true)
          .map((b) => b.id)
          .toSet();

      final horariosSemanaActual = horarios
          .where((h) =>
              h.estado != 'Finalizado' &&
              h.fechaInicioSemana.compareTo(lunesStr) >= 0 &&
              barberoActivosIds.contains(h.barberoId))
          .toList();

      // Filter schedules based on role
      if (currentRole == AppRole.barber) {
        final barbero = await userContextService.obtenerBarberoActual();
        if (barbero != null && barbero.id != null) {
          final horariosFiltrados = horariosSemanaActual.where((h) => h.barberoId == barbero.id).toList();
          emit(HorariosLoaded(horarios: horariosFiltrados));
        } else {
          emit(HorariosLoaded(horarios: []));
        }
      } else {
        // Admin and Superadmin see current week and future only
        emit(HorariosLoaded(horarios: horariosSemanaActual));
      }
    } catch (e) {
      emit(HorariosError(message: limpiarError(e)));
    }
  }

  Future<void> _onCreateHorarioSemanal(CreateHorarioSemanalRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.crearHorarioSemanal(event.horario);
      emit(const HorarioActionSuccess(message: 'Se han registrado los horarios correctamente.'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: limpiarError(e)));
      add(LoadHorariosRequested());
    }
  }

  Future<void> _onCreateParaTodos(CreateHorarioParaTodosRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    int exitosos = 0;
    int fallidos = 0;
    for (final barberoId in event.barberoIds) {
      try {
        await horarioService.crearHorarioSemanal(HorarioSemanal(
          barberoId: barberoId,
          fechaInicioSemana: event.templateHorario.fechaInicioSemana,
          fechaFinSemana: event.templateHorario.fechaFinSemana,
          estado: event.templateHorario.estado,
          detalles: event.templateHorario.detalles,
        ));
        exitosos++;
      } catch (_) {
        fallidos++;
      }
    }
    final msg = fallidos == 0
        ? 'Horario asignado a $exitosos barbero${exitosos != 1 ? "s" : ""} correctamente'
        : '$exitosos creado${exitosos != 1 ? "s" : ""}, $fallidos con error${fallidos != 1 ? "es" : ""}';
    emit(HorarioActionSuccess(message: msg));
    add(LoadHorariosRequested());
  }

  Future<void> _onUpdateHorarioSemanal(UpdateHorarioSemanalRequested event, Emitter<HorariosState> emit) async {
    emit(HorariosLoading());
    try {
      await horarioService.actualizarHorarioSemanal(event.id, event.horario);
      emit(const HorarioActionSuccess(message: 'Los cambios han sido guardados exitosamente.'));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: limpiarError(e)));
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
      emit(HorariosError(message: limpiarError(e)));
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
          
          Future.microtask(() async {
            int sent = 0;
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
                  sent++;
                  if (sent % 5 == 0) await Future.delayed(const Duration(seconds: 1));
                } catch (e) {
                  logD('Error al enviar correo en background: $e');
                }
              }
            }
          });
        }
      }

      emit(HorarioActionSuccess(
        message: event.nuevoEstado
            ? 'El horario ahora está activo.'
            : 'Horario finalizado correctamente.',
      ));
      add(LoadHorariosRequested());
    } catch (e) {
      emit(HorariosError(message: limpiarError(e)));
      add(LoadHorariosRequested());
    }
  }
}
