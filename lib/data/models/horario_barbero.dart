/// Detalle de un día dentro de un HorarioSemanal.
class DetalleHorarioDia {
  final int? id;
  final int horarioSemanalId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;

  DetalleHorarioDia({
    this.id,
    this.horarioSemanalId = 0,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
  });

  factory DetalleHorarioDia.fromJson(Map<String, dynamic> j) {
    int dia = 0;
    final rawDia = j['diaSemana'] ?? j['DiaSemana'] ?? j['dia'] ?? j['Dia'];
    if (rawDia is int) {
      dia = rawDia;
    } else if (rawDia is String) {
      const nombres = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
      dia = nombres.indexOf(rawDia) + 1;
      if (dia < 1) dia = 7;
    }

    String parseHora(dynamic val) {
      if (val == null) return '09:00';
      final s = val.toString();
      return s.length >= 5 ? s.substring(0, 5) : s;
    }

    return DetalleHorarioDia(
      id: j['id'] ?? j['Id'],
      horarioSemanalId: j['horarioSemanalId'] ?? j['HorarioSemanalId'] ?? 0,
      diaSemana: dia,
      horaInicio: parseHora(j['horaInicio'] ?? j['HoraInicio']),
      horaFin: parseHora(j['horaFin'] ?? j['HoraFin']),
    );
  }

  Map<String, dynamic> toJson() => {
    'DiaSemana': diaSemana,
    'HoraInicio': _toTimeSpan(horaInicio),
    'HoraFin': _toTimeSpan(horaFin),
  };

  static String _toTimeSpan(String t) {
    if (t.length == 5) return '$t:00';
    return t;
  }
}

/// Horario semanal de un barbero (Tabla padre).
class HorarioSemanal {
  final int? id;
  final int barberoId;
  final String fechaInicioSemana;
  final String fechaFinSemana;
  final String estado; // "Activo", "Pendiente", "Finalizado"
  final List<DetalleHorarioDia> detalles;

  // Datos del barbero (pueden venir incluidos en el JSON)
  final String? barberoNombre;

  HorarioSemanal({
    this.id,
    required this.barberoId,
    required this.fechaInicioSemana,
    required this.fechaFinSemana,
    this.estado = 'Activo',
    this.detalles = const [],
    this.barberoNombre,
  });

  factory HorarioSemanal.fromJson(Map<String, dynamic> j) {
    // Parsear detalles
    List<DetalleHorarioDia> detalles = [];
    final rawDetalles = j['detalles'] ?? j['Detalles'];
    if (rawDetalles is List) {
      detalles = rawDetalles
          .map((d) => DetalleHorarioDia.fromJson(d as Map<String, dynamic>))
          .toList();
    }

    // Intentar obtener nombre del barbero desde la relación
    String? barberoNombre;
    final barberoObj = j['barbero'] ?? j['Barbero'];
    if (barberoObj is Map) {
      final usuario = barberoObj['usuario'] ?? barberoObj['Usuario'];
      if (usuario is Map) {
        final nombre = usuario['nombre'] ?? usuario['Nombre'] ?? '';
        final apellido = usuario['apellido'] ?? usuario['Apellido'] ?? '';
        barberoNombre = '$nombre $apellido'.trim();
      }
    }

    return HorarioSemanal(
      id: j['id'] ?? j['Id'],
      barberoId: j['barberoId'] ?? j['BarberoId'] ?? 0,
      fechaInicioSemana: (j['fechaInicioSemana'] ?? j['FechaInicioSemana'] ?? '').toString().split('T').first,
      fechaFinSemana: (j['fechaFinSemana'] ?? j['FechaFinSemana'] ?? '').toString().split('T').first,
      estado: j['estado'] ?? j['Estado'] ?? 'Activo',
      detalles: detalles,
      barberoNombre: barberoNombre,
    );
  }

  Map<String, dynamic> toJson() => {
    'BarberoId': barberoId,
    'FechaInicioSemana': fechaInicioSemana,
    'FechaFinSemana': fechaFinSemana,
    'Detalles': detalles.map((d) => d.toJson()).toList(),
  };
}
