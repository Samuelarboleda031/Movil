import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/core/utils/error_utils.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/cliente_service.dart';
import 'package:parte_movil/data/datasources/barbero_service.dart';
import 'package:parte_movil/data/models/cliente.dart';

import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/app_role.dart';
import 'package:parte_movil/data/models/barbero.dart';

import 'ventas_event.dart';
import 'ventas_state.dart';

class VentasBloc extends Bloc<VentasEvent, VentasState> {
  final VentaService _ventaService;
  final ClienteService _clienteService;
  final BarberoService _barberoService;
  final AuthService _authService;

  Map<int, Cliente> _catalogoClientes = {};

  VentasBloc({
    required VentaService ventaService,
    required ClienteService clienteService,
    required BarberoService barberoService,
    required AuthService authService,
  })  : _ventaService = ventaService,
        _clienteService = clienteService,
        _barberoService = barberoService,
        _authService = authService,
        super(VentasInitial()) {
    on<LoadVentasRequested>(_onLoadVentas);
    on<DeleteVentaRequested>(_onDeleteVenta);
  }

  Future<void> _loadCatalogo() async {
    if (_catalogoClientes.isNotEmpty) return;
    try {
      final clientes = await _clienteService.obtenerClientes();
      final Map<int, Cliente> mapa = {};
      for (var c in clientes) {
        if (c.id != null) mapa[c.id!] = c;
      }
      _catalogoClientes = mapa;
    } catch (_) {}
  }

  Future<void> _onLoadVentas(
    LoadVentasRequested event,
    Emitter<VentasState> emit,
  ) async {
    emit(VentasLoading());
    try {
      await _loadCatalogo();

      final user = await _authService.getCurrentUser();
      final fbUser = _authService.currentUser;
      
      final role = roleForRolId(user?.rolId);

      if (role == AppRole.barber) {
        final barberos = await _barberoService.obtenerBarberos();
        final emailBuscado = user?.correo ?? fbUser?.email ?? '';
        final barberoLocal = barberos.firstWhere(
          (b) => (b.email ?? '').toLowerCase() == emailBuscado.toLowerCase(),
          orElse: () => throw Exception('Perfil de barbero no encontrado para este usuario'),
        );

        final paginacion = await _ventaService.obtenerVentas(
          page: 1,
          pageSize: 1000,
        );

        emit(VentasLoaded(
          ventas: paginacion.items,
          catalogoClientes: _catalogoClientes,
          paginacion: paginacion,
          currentPage: 1,
        ));
      } else {
        // MODO ADMIN / MANAGER
        final paginacion = await _ventaService.obtenerVentas(
          page: 1,
          pageSize: 1000,
        );
        emit(VentasLoaded(
          ventas: paginacion.items,
          catalogoClientes: _catalogoClientes,
          paginacion: paginacion,
          currentPage: 1,
        ));
      }

    } catch (e) {
      emit(VentasError(limpiarError(e)));
    }
  }

  Future<void> _onDeleteVenta(
    DeleteVentaRequested event,
    Emitter<VentasState> emit,
  ) async {
    final currentState = state;
    int page = 1;
    if (currentState is VentasLoaded) {
      page = currentState.currentPage;
    }

    emit(VentasLoading());
    try {
      await _ventaService.anularVenta(event.id);
      emit(const VentasActionSuccess('La venta ha sido anulada exitosamente. El estado se ha actualizado en el sistema.'));
      
      add(LoadVentasRequested(page: page));
    } catch (e) {
      emit(VentasError(limpiarError(e)));
      add(LoadVentasRequested(page: page));
    }
  }
}
