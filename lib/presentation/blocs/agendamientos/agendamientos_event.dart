import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/agendamiento.dart';

abstract class AgendamientosEvent extends Equatable {
  const AgendamientosEvent();

  @override
  List<Object?> get props => [];
}

class LoadAgendamientosRequested extends AgendamientosEvent {
  final int page;
  
  const LoadAgendamientosRequested({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class CancelAgendamientoRequested extends AgendamientosEvent {
  final Agendamiento agendamiento;
  
  const CancelAgendamientoRequested(this.agendamiento);

  @override
  List<Object?> get props => [agendamiento];
}

class CancelDiasRequested extends AgendamientosEvent {
  final int barberoId; // -1 for global
  final List<DateTime> fechas;
  final String motivo;

  const CancelDiasRequested({
    required this.barberoId,
    required this.fechas,
    required this.motivo,
  });

  @override
  List<Object?> get props => [barberoId, fechas, motivo];
}
class ChangeAgendamientoStatusRequested extends AgendamientosEvent {
  final Agendamiento agendamiento;
  final String nuevoEstado;

  const ChangeAgendamientoStatusRequested({
    required this.agendamiento,
    required this.nuevoEstado,
  });

  @override
  List<Object?> get props => [agendamiento, nuevoEstado];
}
