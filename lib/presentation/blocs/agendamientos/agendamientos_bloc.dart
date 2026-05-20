import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:intl/intl.dart';
import 'package:parte_movil/data/datasources/agendamiento_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/user_context_service.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/paginacion.dart';

import 'agendamientos_event.dart';
import 'agendamientos_state.dart';

class AgendamientosBloc extends Bloc<AgendamientosEvent, AgendamientosState> {
  final AgendamientoService _agendamientoService;
  final EmailJsService _emailJsService;
  final AuthService _authService;
  final UserContextService _userContextService;
  final ClienteService _clienteService = ClienteService();

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
      emit(AgendamientosError(limpiarError(e)));
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
        const int pageSize = 2000;

        final paginacion = await _agendamientoService.obtenerAgendamientosPorCliente(
          cliente.id!,
          page: event.page,
          pageSize: pageSize,
          estaSemana: event.estaSemana,
        );
        
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
        
        // Traer TODAS las citas sin filtro de semana para el historial completo
        print('🔍 [AgendamientosBloc] Cargando TODAS las citas para barbero: ${barberoLocal.id} (nombre: ${barberoLocal.nombre}, email: ${barberoLocal.email})');
        final totalAgendas = await _agendamientoService.obtenerAgendamientos(
          page: 1, 
          pageSize: 5000,
        );
        
        print('📦 [AgendamientosBloc] API devolvió ${totalAgendas.items.length} citas totales');
        
        // Mostrar los primeros 5 para debug
        for (var a in totalAgendas.items.take(5)) {
          print('  📋 ID:${a.id} BarberoID:${a.barberoId} BarberoNombre:${a.barberoNombre} BarberoEmail:${a.barbero?.email} Estado:${a.estadoCita}');
        }
        
        final propios = totalAgendas.items.where((a) {
           final bool matchId = a.barberoId == barberoLocal.id;
           final bool matchEmail = barberoLocal.email != null && 
                                   barberoLocal.email!.isNotEmpty &&
                                   a.barbero?.email != null &&
                                   a.barbero!.email!.toLowerCase() == barberoLocal.email!.toLowerCase();
           final bool matchNombre = a.barberoNombre != null && 
                                    barberoLocal.nombre.isNotEmpty &&
                                    a.barberoNombre!.toLowerCase() == barberoLocal.nombre.toLowerCase();
           
           return matchId || matchEmail || matchNombre;
        }).toList();
        
        print('✅ [AgendamientosBloc] ${propios.length} citas coinciden con barbero ID:${barberoLocal.id}');

        // Emitir TODAS las citas del barbero (sin paginación local)
        final paginacionSimulada = Paginacion<Agendamiento>(
          items: propios,
          totalCount: propios.length,
          pageSize: propios.length > 0 ? propios.length : 10,
          currentPage: 1,
          totalPages: 1,
          hasPreviousPage: false,
          hasNextPage: false,
        );

        emit(AgendamientosLoaded(
          agendamientos: propios,
          paginacion: paginacionSimulada,
          currentPage: 1,
          isWeeklyMode: isWeekly,
        ));
      } else {
        // MODO ADMIN / MANAGER
        final bool isWeekly = event.estaSemana ?? false;
        const int pageSize = 2000;
        print('🔍 [AgendamientosBloc] Cargando citas ADMIN/MANAGER. isWeekly: $isWeekly');
        final paginacion = await _agendamientoService.obtenerAgendamientos(
          page: event.page,
          pageSize: pageSize,
          estaSemana: event.estaSemana,
        );
        print('✅ [AgendamientosBloc] Se obtuvieron ${paginacion.items.length} citas de un total de ${paginacion.totalCount}');

        emit(AgendamientosLoaded(
          agendamientos: paginacion.items,
          paginacion: paginacion,
          currentPage: event.page,
          isWeeklyMode: isWeekly,
        ));
      }
    } catch (e) {
      emit(AgendamientosError(limpiarError(e)));
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
      if (_isPastAppointment(event.agendamiento)) {
        emit(const AgendamientosActionSuccess(
          'No se puede cancelar una cita pasada.',
        ));
        add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
        return;
      }

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
      emit(AgendamientosError(limpiarError(e)));
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
      if (event.fechas.isEmpty) {
        throw Exception('No se recibieron fechas para procesar la cancelación.');
      }

      final allApps = await _agendamientoService.obtenerAgendamientos(page: 1, pageSize: 5000);
      final fechasObjetivo = event.fechas.map((d) => DateFormat('yyyy-MM-dd').format(d)).toSet();
      final bool modoHora = event.horaInicio != null && event.horaFin != null;
      final int startMin = modoHora ? _parseMinutes(event.horaInicio!) : 0;
      final int endMin = modoHora ? _parseMinutes(event.horaFin!) : 0;

      int canceladas = 0;
      int omitidasPasadas = 0;
      final String motivo = event.motivo.isNotEmpty
          ? event.motivo
          : 'Cancelación de horario especial';

      for (final cita in allApps.items) {
        final fechaCita = cita.fechaCita ?? '';
        if (!fechasObjetivo.contains(fechaCita)) continue;
        if (event.barberoId != -1 && cita.barberoId != event.barberoId) continue;
        if (!_isCancelableStatus(cita.estadoCita)) continue;
        if (cita.id == null) continue;
        if (_isPastAppointment(cita)) {
          omitidasPasadas++;
          continue;
        }

        if (modoHora) {
          final citaMin = _parseMinutes(_getHoraCita(cita));
          if (citaMin < startMin || citaMin >= endMin) continue;
        }

        await _agendamientoService.actualizarEstadoAgendamiento(cita.id!, 'Cancelada');
        canceladas++;
        await _sendCancellationEmail(cita, motivo);
      }

      final String msg = modoHora
          ? 'Se cancelaron $canceladas cita(s) en ese rango horario. '
              'Se omitieron $omitidasPasadas cita(s) pasadas.'
          : 'Se cancelaron $canceladas cita(s) para las fechas seleccionadas. '
              'Se omitieron $omitidasPasadas cita(s) pasadas.';
      emit(AgendamientosActionSuccess(msg));
      
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    } catch (e) {
      emit(AgendamientosError(limpiarError(e)));
      add(LoadAgendamientosRequested(page: page, estaSemana: currentMode));
    }
  }

  bool _isCancelableStatus(String? statusRaw) {
    final status = (statusRaw ?? '').toLowerCase().trim();
    return status != 'cancelada' &&
        status != 'cancelado' &&
        status != 'completada' &&
        status != 'finalizado';
  }

  int _parseMinutes(String? time) {
    if (time == null || time.isEmpty) return 0;
    final parts = time.split(':');
    if (parts.length < 2) return 0;
    final hh = int.tryParse(parts[0]) ?? 0;
    final mm = int.tryParse(parts[1]) ?? 0;
    return hh * 60 + mm;
  }

  String _getHoraCita(Agendamiento cita) {
    final horaInicio = cita.horaInicio?.toString() ?? '';
    if (horaInicio.isNotEmpty) return horaInicio;
    final fechaHora = cita.fechaHora?.toString() ?? '';
    if (fechaHora.contains('T') && fechaHora.length >= 16) {
      return fechaHora.substring(11, 16);
    }
    return '00:00';
  }

  bool _isPastAppointment(Agendamiento cita) {
    final now = DateTime.now();
    final dateTime = _resolveAppointmentDateTime(cita);
    if (dateTime == null) return false;
    return dateTime.isBefore(now);
  }

  DateTime? _resolveAppointmentDateTime(Agendamiento cita) {
    final fechaHoraRaw = cita.fechaHora?.toString();
    if (fechaHoraRaw != null && fechaHoraRaw.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(fechaHoraRaw);
      if (parsed != null) return parsed;
    }

    final fechaRaw = cita.fechaCita?.toString() ?? '';
    final horaRaw = _getHoraCita(cita);
    if (fechaRaw.isEmpty || horaRaw.isEmpty) return null;
    return DateTime.tryParse('${fechaRaw}T$horaRaw:00');
  }

  Future<void> _sendCancellationEmail(Agendamiento cita, String motivo) async {
    try {
      String? clienteEmail = cita.cliente?.email;
      String clienteNombre = cita.cliente?.nombreCompleto ??
          cita.clienteNombre?.toString() ??
          'Cliente';

      if ((clienteEmail == null || clienteEmail.trim().isEmpty) && cita.clienteId > 0) {
        final cliente = await _clienteService.obtenerClientePorId(cita.clienteId);
        if (cliente != null) {
          clienteEmail = cliente.email;
          if (clienteNombre == 'Cliente') {
            clienteNombre = cliente.nombreCompleto.trim().isNotEmpty
                ? cliente.nombreCompleto
                : clienteNombre;
          }
        }
      }

      if (clienteEmail == null || clienteEmail.trim().isEmpty) return;

      final barberoNombre = cita.barbero?.nombreCompleto ??
          cita.barberoNombre?.toString() ??
          'Tu barbero';
      final hora = _getHoraCita(cita);
      final fecha = cita.fechaCita?.toString() ?? '';
      final fechaOriginal = (fecha.isNotEmpty && hora.isNotEmpty)
          ? '${fecha}T$hora:00'
          : (cita.fechaHora?.toString() ?? fecha);

      await _emailJsService.notificarCancelacion(
        clienteEmail: clienteEmail,
        clienteNombre: clienteNombre,
        barberoNombre: barberoNombre,
        fechaOriginal: fechaOriginal,
        motivo: motivo,
      );
    } catch (_) {
      // No bloquear la cancelación por fallas al enviar correo.
    }
  }
}
