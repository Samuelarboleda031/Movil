class SugerenciaHorario {
  final int? id;
  final DateTime diaSugerido;
  final String horaInicio;
  final String horaFin;
  final String origen;

  SugerenciaHorario({
    this.id,
    required this.diaSugerido,
    required this.horaInicio,
    required this.horaFin,
    required this.origen,
  });

  factory SugerenciaHorario.fromJson(Map<String, dynamic> j) {
    return SugerenciaHorario(
      id: j['id'] ?? j['Id'],
      diaSugerido: DateTime.tryParse((j['diaSugerido'] ?? j['DiaSugerido'] ?? '').toString()) ?? DateTime.now(),
      horaInicio: (j['horaInicio'] ?? j['HoraInicio'] ?? '09:00').toString(),
      horaFin: (j['horaFin'] ?? j['HoraFin'] ?? '17:00').toString(),
      origen: (j['origen'] ?? j['Origen'] ?? 'Barbero').toString(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    final hi = horaInicio.length == 5 ? '$horaInicio:00' : horaInicio;
    final hf = horaFin.length == 5 ? '$horaFin:00' : horaFin;
    return {
      'diaSugerido': diaSugerido.toIso8601String(),
      'horaInicio': hi,
      'horaFin': hf,
    };
  }
}

class SolicitudCambioHorario {
  final int? id;
  final int barberoId;
  final String? barberoNombre;
  final String motivoCategoria;
  final String? motivoDetalle;
  final DateTime fechaReferencia;
  final String estado;
  final String? observacionAdmin;
  final DateTime? fechaCreacion;
  final List<SugerenciaHorario> sugerencias;

  SolicitudCambioHorario({
    this.id,
    required this.barberoId,
    this.barberoNombre,
    required this.motivoCategoria,
    this.motivoDetalle,
    required this.fechaReferencia,
    required this.estado,
    this.observacionAdmin,
    this.fechaCreacion,
    this.sugerencias = const [],
  });

  factory SolicitudCambioHorario.fromJson(Map<String, dynamic> j) {
    final rawSugs = j['sugerencias'] ?? j['Sugerencias'] ?? [];
    final sugs = (rawSugs as List).map((s) => SugerenciaHorario.fromJson(s)).toList();
    return SolicitudCambioHorario(
      id: j['id'] ?? j['Id'],
      barberoId: j['barberoId'] ?? j['BarberoId'] ?? 0,
      barberoNombre: j['barberoNombre'] ?? j['BarberoNombre'],
      motivoCategoria: (j['motivoCategoria'] ?? j['MotivoCategoria'] ?? '').toString(),
      motivoDetalle: j['motivoDetalle'] ?? j['MotivoDetalle'],
      fechaReferencia: DateTime.tryParse((j['fechaReferencia'] ?? j['FechaReferencia'] ?? '').toString()) ?? DateTime.now(),
      estado: (j['estado'] ?? j['Estado'] ?? 'Pendiente').toString(),
      observacionAdmin: j['observacionAdmin'] ?? j['ObservacionAdmin'],
      fechaCreacion: j['fechaCreacion'] != null ? DateTime.tryParse(j['fechaCreacion'].toString()) : null,
      sugerencias: sugs,
    );
  }
}
