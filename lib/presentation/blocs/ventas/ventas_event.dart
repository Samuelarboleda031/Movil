import 'package:equatable/equatable.dart';

abstract class VentasEvent extends Equatable {
  const VentasEvent();

  @override
  List<Object?> get props => [];
}

class LoadVentasRequested extends VentasEvent {
  final int page;
  
  const LoadVentasRequested({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class DeleteVentaRequested extends VentasEvent {
  final int id;
  
  const DeleteVentaRequested(this.id);

  @override
  List<Object?> get props => [id];
}
