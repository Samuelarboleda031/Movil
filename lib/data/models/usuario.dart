import 'package:parte_movil/domain/entities/usuario_entity.dart';

class Usuario extends UsuarioEntity {
  final String? contrasena;
  final String? documento;
  final String? tipoDocumento;
  final String? telefono;

  const Usuario({
    super.id,
    super.nombre,
    super.apellido,
    required super.correo,
    this.contrasena,
    this.documento,
    this.tipoDocumento,
    this.telefono,
    super.fotoPerfil,
    super.rolId,
    super.estado,
  });


  factory Usuario.fromJson(Map<String, dynamic> json) {
    final rawCorreo = json['correo'] ?? json['Correo'] ?? json['usuario'] ?? json['Usuario'] ?? '';

    return Usuario(
      id: _parseInt(json['id'] ?? json['Id'] ?? json['ID']),
      correo: rawCorreo.toString(),
      nombre: json['nombre'] ?? json['Nombre'],
      apellido: json['apellido'] ?? json['Apellido'],
      fotoPerfil: json['fotoPerfil'] ?? json['FotoPerfil'],
      contrasena: json['contrasena'] ?? json['Contrasena'],
      documento: json['documento'] ?? json['Documento'],
      tipoDocumento: json['tipoDocumento'] ?? json['TipoDocumento'],
      telefono: json['telefono'] ?? json['Telefono'],
      rolId: _parseInt(json['rolId'] ?? json['RolId'] ?? json['RolID']),
      estado: _parseBool(json['estado'] ?? json['Estado']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'Nombre': nombre ?? '',
      'Apellido': apellido ?? '',
      'Correo': correo,
      'Contrasena': contrasena ?? '',
      'RolId': rolId,
      'Documento': documento ?? '',
      'TipoDocumento': tipoDocumento ?? 'CC',
      'Telefono': telefono ?? '',
      'FotoPerfil': fotoPerfil,
      'Estado': estado ?? true,
    };

    if (id != null && id != 0) {
      data['Id'] = id;
    }

    return data;
  }
}

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool? _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

class LoginRequest {
  final String correo;
  final String contrasena;

  LoginRequest({
    required this.correo,
    required this.contrasena,
  });

  Map<String, dynamic> toJson() {
    return {
      'correo': correo,
      'contrasena': contrasena,
    };
  }
}

class LoginResponse {
  final bool success;
  final String? token;
  final Usuario? usuario;
  final String? message;

  LoginResponse({
    required this.success,
    this.token,
    this.usuario,
    this.message,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      success: json['success'] ?? false,
      token: json['token'],
      usuario: json['usuario'] != null ? Usuario.fromJson(json['usuario']) : null,
      message: json['message'],
    );
  }
}

