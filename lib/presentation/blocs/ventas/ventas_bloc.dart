import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:parte_movil/data/datasources/venta_service.dart';
import 'package:parte_movil/data/datasources/auxiliar_service.dart';
import 'package:parte_movil/data/models/cliente.dart';

import 'ventas_event.dart';
import 'ventas_state.dart';

class VentasBloc extends Bloc<VentasEvent, VentasState> {
  final VentaService _ventaService;
  final AuxiliarService _auxiliarService;

  Map<int, Cliente> _catalogoClientes = {};

  VentasBloc({
    required VentaService ventaService,
    required AuxiliarService auxiliarService,
  })  : _ventaService = ventaService,
        _auxiliarService = auxiliarService,
        super(VentasInitial()) {
    on<LoadVentasRequested>(_onLoadVentas);
    on<DeleteVentaRequested>(_onDeleteVenta);
  }

  Future<void> _loadCatalogo() async {
    if (_catalogoClientes.isNotEmpty) return;
    try {
      final clientes = await _auxiliarService.obtenerClientes();
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
      final paginacion = await _ventaService.obtenerVentas(
        page: event.page,
        pageSize: 15,
      );
      emit(VentasLoaded(
        ventas: paginacion.items,
        catalogoClientes: _catalogoClientes,
        paginacion: paginacion,
        currentPage: event.page,
      ));
    } catch (e) {
      emit(VentasError('Error al cargar ventas: $e'));
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
      await _ventaService.eliminarVenta(event.id);
      emit(const VentasActionSuccess('Venta anulada correctamente'));
      
      add(LoadVentasRequested(page: page));
    } catch (e) {
      emit(VentasError('Error al anular venta: $e'));
      add(LoadVentasRequested(page: page));
    }
  }
}
