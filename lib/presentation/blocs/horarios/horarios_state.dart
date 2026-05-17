import 'package:equatable/equatable.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';

abstract class HorariosState extends Equatable {
  const HorariosState();

  @override
  List<Object?> get props => [];
}

class HorariosInitial extends HorariosState {}

class HorariosLoading extends HorariosState {}

class HorariosLoaded extends HorariosState {
  final List<HorarioSemanal> horarios;

  const HorariosLoaded({required this.horarios});

  @override
  List<Object?> get props => [horarios];
}

class HorariosError extends HorariosState {
  final String message;

  const HorariosError({required this.message});

  @override
  List<Object?> get props => [message];
}

class HorarioActionSuccess extends HorariosState {
  final String message;

  const HorarioActionSuccess({required this.message});

  @override
  List<Object?> get props => [message];
}
