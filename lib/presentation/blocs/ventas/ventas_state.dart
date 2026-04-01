import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/paginacion.dart';

abstract class VentasState extends Equatable {
  const VentasState();

  @override
  List<Object?> get props => [];
}

class VentasInitial extends VentasState {}

class VentasLoading extends VentasState {}

class VentasLoaded extends VentasState {
  final List<Venta> ventas;
  final Map<int, Cliente> catalogoClientes;
  final Paginacion<Venta>? paginacion;
  final int currentPage;

  const VentasLoaded({
    required this.ventas,
    required this.catalogoClientes,
    this.paginacion,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [ventas, catalogoClientes, paginacion, currentPage];
}

class VentasError extends VentasState {
  final String message;

  const VentasError(this.message);

  @override
  List<Object?> get props => [message];
}

class VentasActionSuccess extends VentasState {
  final String message;
  const VentasActionSuccess(this.message);
}
