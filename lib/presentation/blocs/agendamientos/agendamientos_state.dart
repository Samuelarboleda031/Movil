import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';

abstract class AgendamientosState extends Equatable {
  const AgendamientosState();

  @override
  List<Object?> get props => [];
}

class AgendamientosInitial extends AgendamientosState {}

class AgendamientosLoading extends AgendamientosState {}

class AgendamientosLoaded extends AgendamientosState {
  final List<Agendamiento> agendamientos;
  final Paginacion<Agendamiento>? paginacion;
  final int currentPage;

  const AgendamientosLoaded({
    required this.agendamientos,
    this.paginacion,
    this.currentPage = 1,
  });

  @override
  List<Object?> get props => [agendamientos, paginacion, currentPage];
}

class AgendamientosActionLoading extends AgendamientosState {}

class AgendamientosError extends AgendamientosState {
  final String message;

  const AgendamientosError(this.message);

  @override
  List<Object?> get props => [message];
}

class AgendamientosActionSuccess extends AgendamientosState {
  final String message;
  const AgendamientosActionSuccess(this.message);
}
