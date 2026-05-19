import 'package:intl/intl.dart';
import 'cliente.dart';
import 'barbero.dart';
import 'servicio.dart';
import 'paquete.dart';

class Agendamiento {
  final int? id;
  final int clienteId;
  final int barberoId;
  final int? servicioId; // Kept for backward compatibility if needed, but new logic uses servicioIds
  final int? paqueteId; // Kept for backward compatibility if needed, but new logic uses paqueteIds
  final List<int> servicioIds;
  final List<int> productoIds;
  final List<String> serviciosNombres;
  final List<String> productosNombres;
  final String? fechaCita;
  final String? horaInicio;
  final String? horaFin;
  final String? estadoCita;
  final double? monto;
  final String? observaciones;
  final String? estado;
  final String? fechaHora;
  final String? duracion;
  final double precio;
  final Cliente? cliente;
  final Barbero? barbero;
  final Servicio? servicio;
  final Paquete? paquete;
  final String? clienteNombre;
  final String? barberoNombre;

  Agendamiento({
    this.id,
    required this.clienteId,
    required this.barberoId,
    this.servicioId,
    this.paqueteId,
    this.servicioIds = const [],
    this.productoIds = const [],
    this.serviciosNombres = const [],
    this.productosNombres = const [],
    this.fechaCita = '',
    this.horaInicio = '',
    this.horaFin = '',
    this.estadoCita = 'Pendiente',
    this.monto,
    this.observaciones,
    this.estado,
    this.fechaHora,
    this.duracion,
    this.precio = 0.0,
    this.cliente,
    this.barbero,
    this.servicio,
    this.paquete,
    this.clienteNombre,
    this.barberoNombre,
  });

  factory Agendamiento.fromJson(Map<String, dynamic> json) {
    // Parseo de fecha y hora desde 'fechaHora' o individual
    String fHora = json['fechaHora'] ?? json['FechaHora'] ?? '';
    String fCita = json['fechaCita'] ?? json['FechaCita'] ?? '';
    String hInic = json['horaInicio'] ?? json['HoraInicio'] ?? '';
    
    if (fHora.isNotEmpty && fHora.contains('T')) {
      var parts = fHora.split('T');
      fCita = parts[0];
      if (parts[1].length >= 5) {
        hInic = parts[1].substring(0, 5);
      }
    }

    // Mapeo robusto de IDs siguiendo el estilo de Front4
    final idVal = json['id'] ?? json['Id'] ?? json['ID'];
    final clienteIdVal = json['clienteId'] ?? json['ClienteId'] ?? json['ClienteID'] ?? 0;
    final barberoIdVal = json['barberoId'] ?? json['BarberoId'] ?? json['BarberoID'] ?? 0;
    final servicioIdVal = json['servicioId'] ?? json['ServicioId'] ?? json['ServicioID'];
    final paqueteIdVal = json['paqueteId'] ?? json['PaqueteId'] ?? json['PaqueteID'];

    return Agendamiento(
      id: idVal is int ? idVal : int.tryParse(idVal.toString()),
      clienteId: clienteIdVal is int ? clienteIdVal : (int.tryParse(clienteIdVal.toString()) ?? 0),
      barberoId: barberoIdVal is int ? barberoIdVal : (int.tryParse(barberoIdVal.toString()) ?? 0),
      servicioId: servicioIdVal is int ? servicioIdVal : int.tryParse(servicioIdVal.toString()),
      paqueteId: paqueteIdVal is int ? paqueteIdVal : int.tryParse(paqueteIdVal.toString()),
      servicioIds: ((json['servicioIds'] ?? json['ServicioIds'] ?? (idVal != null && servicioIdVal != null ? [servicioIdVal] : [])) as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList()
          .cast<int>(),
      productoIds: ((json['productoIds'] ?? json['ProductoIds'] ?? []) as List)
          .map((e) => int.tryParse(e.toString()) ?? 0)
          .where((e) => e > 0)
          .toList()
          .cast<int>(),
      serviciosNombres: (json['serviciosNombres'] ?? json['ServiciosNombres'] ?? []).whereType<String>().toList(),
      productosNombres: (json['productosNombres'] ?? json['ProductosNombres'] ?? []).whereType<String>().toList(),
      fechaCita: fCita,
      horaInicio: hInic,
      horaFin: json['horaFin'] ?? json['HoraFin'] ?? '',
      estadoCita: json['estadoCita'] ?? json['EstadoCita'] ?? json['estado'] ?? json['Estado'] ?? 'Pendiente',
      monto: (json['monto'] ?? json['Monto'] ?? json['precio'] ?? json['Precio'] ?? 0.0).toDouble(),
      observaciones: json['observaciones'] ?? json['Observaciones'] ?? json['notas'] ?? json['Notas'],
      estado: json['estado']?.toString() ?? json['Estado']?.toString(),
      fechaHora: fHora,
      duracion: json['duracion'] ?? json['Duracion'],
      precio: (json['precio'] ?? json['Precio'] ?? 0.0).toDouble(),
      cliente: json['cliente'] != null 
          ? Cliente.fromJson(json['cliente']) 
          : ((json['clienteNombre'] ?? json['ClienteNombre']) != null 
              ? Cliente(
                  id: clienteIdVal is int ? clienteIdVal : 0,
                  documento: '',
                  nombre: (json['clienteNombre'] ?? json['ClienteNombre']).toString(),
                  apellido: '',
                  email: (json['clienteEmail'] ?? json['ClienteEmail'])?.toString(),
                )
              : null),
      barbero: json['barbero'] != null 
          ? Barbero.fromJson(json['barbero']) 
          : ((json['barberoNombre'] ?? json['BarberoNombre']) != null 
              ? Barbero(
                  id: barberoIdVal is int ? barberoIdVal : 0, 
                  nombre: (json['barberoNombre'] ?? json['BarberoNombre']).toString(),
                  apellido: '',
                  documento: '',
                  telefono: '',
                  email: '',
                  direccion: '',
                  estado: true
                ) 
              : null),
      servicio: json['servicio'] != null ? Servicio.fromJson(json['servicio']) : null,
      paquete: json['paquete'] != null ? Paquete.fromJson(json['paquete']) : null,
      clienteNombre: (json['clienteNombre'] ?? json['ClienteNombre'])?.toString(),
      barberoNombre: (json['barberoNombre'] ?? json['BarberoNombre'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    // Construir FechaHora correctamente en formato ISO 8601
    // La hora ya viene como "HH:mm", añadir solo los segundos ":00"
    String fechaHoraFinal;
    if (fechaHora != null && fechaHora!.isNotEmpty && fechaHora!.contains('T')) {
      // Ya viene como ISO completo desde el servidor
      fechaHoraFinal = fechaHora!;
    } else {
      // Construir desde los campos separados: "yyyy-MM-ddTHH:mm:00"
      final fecha = fechaCita ?? DateTime.now().toIso8601String().split('T')[0];
      final hora = horaInicio ?? '09:00';
      // Importante: hora ya tiene formato "HH:mm", agregar solo ":00"
      fechaHoraFinal = '${fecha}T${hora}:00';
    }

    // Calcular duración en minutos
    int duracionMinutos = 60;
    if (horaInicio != null && horaFin != null) {
      try {
        final start = DateFormat('HH:mm').parse(horaInicio!);
        final end = DateFormat('HH:mm').parse(horaFin!);
        final diff = end.difference(start).inMinutes;
        if (diff > 0) duracionMinutos = diff;
      } catch (_) {}
    }

    // Construir el JSON exactamente como lo espera AgendamientoInput del backend
    final Map<String, dynamic> result = {
      'ClienteId': clienteId,
      'BarberoId': barberoId,
      'FechaHora': fechaHoraFinal,
      'Duracion': '$duracionMinutos minutos',
      'Precio': precio > 0 ? precio : (monto ?? 0.0),
    };

    if (servicioId != null) result['ServicioId'] = servicioId;
    if (servicioIds.isNotEmpty) result['ServicioIds'] = servicioIds;
    if (paqueteId != null) result['PaqueteId'] = paqueteId;
    if (productoIds.isNotEmpty) {
      result['Productos'] = productoIds.map((pid) => {'ProductoId': pid, 'Cantidad': 1}).toList();
    }
    if (observaciones != null && observaciones!.isNotEmpty) result['Notas'] = observaciones;
    if (id != null && id != 0) result['Id'] = id;

    return result;
  }

  Agendamiento copyWith({
    int? id,
    int? clienteId,
    int? barberoId,
    int? servicioId,
    int? paqueteId,
    String? fechaCita,
    String? horaInicio,
    String? horaFin,
    String? estadoCita,
    double? monto,
    String? observaciones,
    String? estado,
    String? fechaHora,
    String? duracion,
    double? precio,
    List<int>? servicioIds,
    List<int>? productoIds,
    List<String>? serviciosNombres,
    List<String>? productosNombres,
    Cliente? cliente,
    Barbero? barbero,
    Servicio? servicio,
    Paquete? paquete,
  }) {
    return Agendamiento(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      barberoId: barberoId ?? this.barberoId,
      servicioId: servicioId ?? this.servicioId,
      paqueteId: paqueteId ?? this.paqueteId,
      servicioIds: servicioIds ?? this.servicioIds,
      productoIds: productoIds ?? this.productoIds,
      serviciosNombres: serviciosNombres ?? this.serviciosNombres,
      productosNombres: productosNombres ?? this.productosNombres,
      fechaCita: fechaCita ?? this.fechaCita,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
      estadoCita: estadoCita ?? this.estadoCita,
      monto: monto ?? this.monto,
      observaciones: observaciones ?? this.observaciones,
      estado: estado ?? this.estado,
      fechaHora: fechaHora ?? this.fechaHora,
      duracion: duracion ?? this.duracion,
      precio: precio ?? this.precio,
      cliente: cliente ?? this.cliente,
      barbero: barbero ?? this.barbero,
      servicio: servicio ?? this.servicio,
      paquete: paquete ?? this.paquete,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      barberoNombre: barberoNombre ?? this.barberoNombre,
    );
  }
}

