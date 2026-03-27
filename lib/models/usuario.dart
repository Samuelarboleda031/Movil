class Usuario {
  final int? id;
  final String? nombre;
  final String? apellido;
  final String correo;
  final String? contrasena;
  final String? fotoPerfil;
  final int? rolId;
  final bool? estado;

  Usuario({
    this.id,
    this.nombre,
    this.apellido,
    required this.correo,
    this.contrasena,
    this.fotoPerfil,
    this.rolId,
    this.estado,
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
      rolId: _parseInt(json['rolId'] ?? json['RolID']),
      estado: _parseBool(json['estado'] ?? json['Estado']),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'usuario': correo,
      'Nombre': nombre ?? '',
      'Apellido': apellido ?? '',
      'Correo': correo,
      'Contrasena': contrasena ?? '',
      'RolId': rolId,
      'RolID': rolId, // doble compatibilidad
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

