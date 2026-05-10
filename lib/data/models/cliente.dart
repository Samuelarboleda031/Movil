class Cliente {
  final int? id;
  final String documento;
  final String nombre;
  final String apellido;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? fotoPerfil;
  final int? usuarioId;
  final bool? estado;

  Cliente({
    this.id,
    required this.documento,
    required this.nombre,
    required this.apellido,
    this.telefono,
    this.email,
    this.direccion,
    this.fotoPerfil,
    this.usuarioId,
    this.estado,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      id: json['id'] ?? json['Id'] ?? json['ID'],
      documento: json['documento'] ?? json['Documento'] ?? '',
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      apellido: json['apellido'] ?? json['Apellido'] ?? '',
      telefono: json['telefono'] ?? json['Telefono'],
      email: json['email'] ?? json['Email'] ?? json['correo'] ?? json['Correo'],
      direccion: json['direccion'] ?? json['Direccion'],
      fotoPerfil: json['fotoPerfil'] ?? json['FotoPerfil'],
      usuarioId: json['usuarioId'] ?? json['UsuarioID'] ?? json['UsuarioId'],
      estado: json['estado'] ?? json['Estado'],
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'Documento': documento,
      'Nombre': nombre,
      'Apellido': apellido,
      'UsuarioId': usuarioId,
      'Correo': email ?? '',
      'Estado': estado ?? true,
    };

    if (telefono != null && telefono!.isNotEmpty) {
      data['Telefono'] = telefono;
    }
    if (direccion != null && direccion!.isNotEmpty) {
      data['Direccion'] = direccion;
    }
    if (fotoPerfil != null && fotoPerfil!.isNotEmpty) {
      data['FotoPerfil'] = fotoPerfil;
    }
    if (id != null && id != 0) {
      data['Id'] = id;
    }

    return data;
  }

  String get nombreCompleto => '$nombre $apellido';
}

