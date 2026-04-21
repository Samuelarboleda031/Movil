import 'cliente.dart';
import 'barbero.dart';
import 'usuario.dart';

class Venta {
  final int? id;
  final String numero;
  final String? fechaRegistro;
  final int clienteId;
  final int? barberoId;
  final int? usuarioId;
  final String metodoPago;
  final double subtotal;
  final double porcentajeDescuento;
  final double total;
  final String? estado;
  final String? clienteNombre; // Para clientes invitados (no registrados)
  final String? responsableNombre;
  final String? barberoNombreStr;
  final Cliente? cliente;
  final Barbero? barbero;
  final Usuario? usuario;
  final List<DetalleVenta>? detalles;

  Venta({
    this.id,
    required this.numero,
    this.fechaRegistro,
    required this.clienteId,
    this.barberoId,
    this.usuarioId,
    required this.metodoPago,
    required this.subtotal,
    required this.porcentajeDescuento,
    required this.total,
    this.estado,
    this.clienteNombre,
    this.responsableNombre,
    this.barberoNombreStr,
    this.cliente,
    this.barbero,
    this.usuario,
    this.detalles,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? detallesList = 
        json['detalles'] ?? json['detalleVenta'] ?? json['DetalleVenta'];

    String? rNombreStr = json['usuarioNombreCompleto'] ?? json['UsuarioNombreCompleto'] ?? json['responsableNombre'] ?? json['ResponsableNombre'] ?? json['usuarioNombre'] ?? json['UsuarioNombre'];
    String? bNombreStr = json['barberoNombreCompleto'] ?? json['BarberoNombreCompleto'] ?? json['barberoNombre'] ?? json['BarberoNombre'] ?? json['nombreBarbero'] ?? json['NombreBarbero'];
    if (bNombreStr == null && json['barbero'] is String) bNombreStr = json['barbero'];
    if (rNombreStr == null && json['usuario'] is String) rNombreStr = json['usuario'];

    return Venta(
      id: json['id'] ?? json['ID'],
      numero: json['numero'] ?? json['Numero'] ?? '',
      fechaRegistro: json['fechaRegistro'] ?? json['FechaRegistro'] ?? json['fecha'] ?? json['Fecha'],
      clienteId: json['clienteId'] ?? json['ClienteId'] ?? json['ClienteID'] ?? 0,
      barberoId: json['barberoId'] ?? json['BarberoId'] ?? json['BarberoID'],
      usuarioId: json['usuarioId'] ?? json['UsuarioId'] ?? json['UsuarioID'],
      metodoPago: json['metodoPago'] ?? json['MetodoPago'] ?? '',
      subtotal: (json['subtotal'] ?? json['Subtotal'] ?? 0).toDouble(),
      porcentajeDescuento: (json['porcentajeDescuento'] ?? json['PorcentajeDescuento'] ?? json['descuento'] ?? json['Descuento'] ?? 0).toDouble(),
      total: (json['total'] ?? json['Total'] ?? 0).toDouble(),
      estado: json['estado']?.toString() ?? json['Estado']?.toString(),
      clienteNombre: json['clienteNombre'] ?? json['ClienteNombre'],
      responsableNombre: rNombreStr,
      barberoNombreStr: bNombreStr,
      cliente: json['cliente'] is Map<String, dynamic> ? Cliente.fromJson(json['cliente']) : null,
      barbero: json['barbero'] is Map<String, dynamic> ? Barbero.fromJson(json['barbero']) : null,
      usuario: json['usuario'] is Map<String, dynamic> ? Usuario.fromJson(json['usuario']) : null,
      detalles: detallesList != null 
          ? detallesList.map((d) => DetalleVenta.fromJson(d)).toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'NumeroVenta': int.tryParse(numero.replaceAll(RegExp(r'[^0-9]'), '')) ?? DateTime.now().millisecondsSinceEpoch % 1000000,
      'Fecha': fechaRegistro,
      'ClienteId': clienteId,
      if (barberoId != null) 'BarberoId': barberoId,
      'UsuarioId': usuarioId,
      'MetodoPago': metodoPago,
      'Subtotal': subtotal,
      'Descuento': porcentajeDescuento,
      'Total': total,
      'Estado': estado ?? 'Completada',
      if (clienteNombre != null) 'ClienteNombre': clienteNombre,
      'Detalles': detalles?.map((d) => d.toJson()).toList() ?? [],
    };
    
    if (id != null && id != 0) {
      data['Id'] = id;
    }
    
    return data;
  }

  Venta copyWith({
    int? id,
    String? numero,
    String? fechaRegistro,
    int? clienteId,
    int? barberoId,
    int? usuarioId,
    String? metodoPago,
    double? subtotal,
    double? porcentajeDescuento,
    double? total,
    String? estado,
    String? clienteNombre,
    String? responsableNombre,
    String? barberoNombreStr,
    Cliente? cliente,
    Barbero? barbero,
    Usuario? usuario,
    List<DetalleVenta>? detalles,
  }) {
    return Venta(
      id: id ?? this.id,
      numero: numero ?? this.numero,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      clienteId: clienteId ?? this.clienteId,
      barberoId: barberoId ?? this.barberoId,
      usuarioId: usuarioId ?? this.usuarioId,
      metodoPago: metodoPago ?? this.metodoPago,
      subtotal: subtotal ?? this.subtotal,
      porcentajeDescuento: porcentajeDescuento ?? this.porcentajeDescuento,
      total: total ?? this.total,
      estado: estado ?? this.estado,
      clienteNombre: clienteNombre ?? this.clienteNombre,
      responsableNombre: responsableNombre ?? this.responsableNombre,
      barberoNombreStr: barberoNombreStr ?? this.barberoNombreStr,
      cliente: cliente ?? this.cliente,
      barbero: barbero ?? this.barbero,
      usuario: usuario ?? this.usuario,
      detalles: detalles ?? this.detalles,
    );
  }
}

class DetalleVenta {
  final int? id;
  final int ventaId;
  final int? productoId;
  final int? servicioId;
  final int? paqueteId;
  final int cantidad;
  final double precioUnitario;
  final double? subTotal;

  DetalleVenta({
    this.id,
    required this.ventaId,
    this.productoId,
    this.servicioId,
    this.paqueteId,
    required this.cantidad,
    required this.precioUnitario,
    this.subTotal,
  });

  factory DetalleVenta.fromJson(Map<String, dynamic> json) {
    return DetalleVenta(
      id: json['id'] ?? json['ID'],
      ventaId: json['ventaId'] ?? json['VentaID'] ?? 0,
      productoId: json['productoId'] ?? json['ProductoID'],
      servicioId: json['servicioId'] ?? json['ServicioID'],
      paqueteId: json['paqueteId'] ?? json['PaqueteID'],
      cantidad: json['cantidad'] ?? json['Cantidad'] ?? 0,
      precioUnitario: (json['precioUnitario'] ?? json['PrecioUnitario'] ?? 0).toDouble(),
      subTotal: json['subTotal'] != null ? (json['subTotal'] ?? json['SubTotal']).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      if (productoId != null) 'ProductoId': productoId,
      if (servicioId != null) 'ServicioId': servicioId,
      if (paqueteId != null) 'PaqueteId': paqueteId,
      'Cantidad': cantidad,
      'PrecioUnitario': precioUnitario,
    };

    if (id != null && id != 0) {
      data['Id'] = id;
    }

    return data;
  }
}