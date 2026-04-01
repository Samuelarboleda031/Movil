class Barbero {
  final int? id;
  final String documento;
  final String nombre;
  final String apellido;
  final String? telefono;
  final String? email;
  final String? direccion;
  final String? fechaIngreso;
  final String? fotoPerfil;
  final int? usuarioId;
  final bool? estado;

  Barbero({
    this.id,
    required this.documento,
    required this.nombre,
    required this.apellido,
    this.telefono,
    this.email,
    this.direccion,
    this.fechaIngreso,
    this.fotoPerfil,
    this.usuarioId,
    this.estado,
  });

  factory Barbero.fromJson(Map<String, dynamic> json) {
    return Barbero(
      id: json['id'] ?? json['Id'] ?? json['ID'],
      documento: json['documento'] ?? json['Documento'] ?? '',
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      apellido: json['apellido'] ?? json['Apellido'] ?? '',
      telefono: json['telefono'] ?? json['Telefono'],
      email: json['email'] ?? json['Email'] ?? json['correo'] ?? json['Correo'],
      direccion: json['direccion'] ?? json['Direccion'],
      fechaIngreso: json['fechaIngreso'] ?? json['FechaIngreso'] ?? json['fechaContratacion'] ?? json['FechaContratacion'],
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
      'UsuarioID': usuarioId,
    };

    // Campos opcionales - solo incluir si tienen valor
    if (telefono != null && telefono!.isNotEmpty) {
      data['Telefono'] = telefono;
    }
    if (email != null && email!.isNotEmpty) {
      data['Email'] = email;
      data['Correo'] = email;
    }
    if (direccion != null && direccion!.isNotEmpty) {
      data['Direccion'] = direccion;
    }
    if (fotoPerfil != null && fotoPerfil!.isNotEmpty) {
      data['FotoPerfil'] = fotoPerfil;
    }
    if (estado != null) {
      data['Estado'] = estado;
    }
    
    // Solo incluir fechaIngreso si tiene un valor (no null)
    // Si es null, la base de datos usará su valor por defecto now()
    if (fechaIngreso != null) {
      data['FechaIngreso'] = fechaIngreso;
      data['FechaContratacion'] = fechaIngreso;
    }
    
    // Solo incluir ID si existe (para actualizaciones)
    if (id != null && id != 0) {
      data['ID'] = id;
    }

    return data;
  }

  String get nombreCompleto => '$nombre $apellido';
}

