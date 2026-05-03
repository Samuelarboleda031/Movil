import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';

abstract class HorariosEvent extends Equatable {
  const HorariosEvent();

  @override
  List<Object?> get props => [];
}

class LoadHorariosRequested extends HorariosEvent {}

class CreateHorarioRequested extends HorariosEvent {
  final HorarioBarbero horario;

  const CreateHorarioRequested(this.horario);

  @override
  List<Object?> get props => [horario];
}

class CreateMultipleHorariosRequested extends HorariosEvent {
  final List<HorarioBarbero> horarios;

  const CreateMultipleHorariosRequested(this.horarios);

  @override
  List<Object?> get props => [horarios];
}

class UpdateHorarioRequested extends HorariosEvent {
  final HorarioBarbero horario;

  const UpdateHorarioRequested(this.horario);

  @override
  List<Object?> get props => [horario];
}

class DeleteHorarioRequested extends HorariosEvent {
  final int id;

  const DeleteHorarioRequested(this.id);

  @override
  List<Object?> get props => [id];
}

class ToggleHorarioStatusRequested extends HorariosEvent {
  final int id;

  const ToggleHorarioStatusRequested(this.id);

  @override
  List<Object?> get props => [id];
}
