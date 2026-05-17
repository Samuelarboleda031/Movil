import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';

abstract class HorariosEvent extends Equatable {
  const HorariosEvent();

  @override
  List<Object?> get props => [];
}

class LoadHorariosRequested extends HorariosEvent {}

class CreateHorarioSemanalRequested extends HorariosEvent {
  final HorarioSemanal horario;

  const CreateHorarioSemanalRequested(this.horario);

  @override
  List<Object?> get props => [horario];
}

class UpdateHorarioSemanalRequested extends HorariosEvent {
  final int id;
  final HorarioSemanal horario;

  const UpdateHorarioSemanalRequested(this.id, this.horario);

  @override
  List<Object?> get props => [id, horario];
}

class DeleteHorarioSemanalRequested extends HorariosEvent {
  final int id;

  const DeleteHorarioSemanalRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ToggleHorarioSemanalStatusRequested extends HorariosEvent {
  final int id;
  final bool nuevoEstado;

  const ToggleHorarioSemanalStatusRequested(this.id, this.nuevoEstado);

  @override
  List<Object?> get props => [id, nuevoEstado];
}
