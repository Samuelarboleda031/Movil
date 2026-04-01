import 'package:equatable/equatable.dart';

class UsuarioEntity extends Equatable {
  final int? id;
  final String? nombre;
  final String? apellido;
  final String correo;
  final String? fotoPerfil;
  final int? rolId;
  final bool? estado;

  const UsuarioEntity({
    this.id,
    this.nombre,
    this.apellido,
    required this.correo,
    this.fotoPerfil,
    this.rolId,
    this.estado,
  });

  String get nombreCompleto => '${nombre ?? ''} ${apellido ?? ''}'.trim().isNotEmpty 
      ? '${nombre ?? ''} ${apellido ?? ''}'.trim() 
      : correo;

  @override
  List<Object?> get props => [id, nombre, apellido, correo, fotoPerfil, rolId, estado];
}
