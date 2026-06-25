import 'package:equatable/equatable.dart';
import 'cliente.dart';
import 'barbero.dart';
import 'usuario.dart';

class Venta extends Equatable {
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
  final double? saldoAFavorUsado;
  final String? responsableNombre;
  final String? barberoNombreStr;
  /// Barbero que prestó el crédito (puede ser distinto al que atendió).
  final int? barberoPrestadorId;
  final String? barberoPrestadorNombre;
  /// Plazo en días del crédito de barbero usado en esta venta.
  final int? plazoDias;
  /// Monto de crédito del barbero utilizado en esta venta.
  final double? creditoBarberoUsado;
  /// Tipo de venta: "Venta Cliente", "Venta Invitado", "Venta Barbero".
  final String? tipoVenta;
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
    this.saldoAFavorUsado,
    this.responsableNombre,
    this.barberoNombreStr,
    this.barberoPrestadorId,
    this.barberoPrestadorNombre,
    this.plazoDias,
    this.creditoBarberoUsado,
    this.tipoVenta,
    this.cliente,
    this.barbero,
    this.usuario,
    this.detalles,
  });

  factory Venta.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? detallesList = 
        json['detalles'] ?? json['detalleVenta'] ?? json['DetalleVenta'];

    // Priorizar la información de usuario almacenada directamente en la venta
    String? uNombre = json['usuarioNombre'] ?? json['UsuarioNombre'];
    String? uApellido = json['usuarioApellido'] ?? json['UsuarioApellido'];
    String? rNombreStr;
    if (uNombre != null || uApellido != null) {
      rNombreStr = '${uNombre ?? ''} ${uApellido ?? ''}'.trim();
    }
    if (rNombreStr == null || rNombreStr.isEmpty) {
      rNombreStr = json['usuarioNombreCompleto'] ?? json['UsuarioNombreCompleto'] ?? json['responsableNombre'] ?? json['ResponsableNombre'] ?? json['usuarioNombre'] ?? json['UsuarioNombre'];
    }
    
    String? bNombreStr = json['barberoNombreCompleto'] ?? json['BarberoNombreCompleto'] ?? json['barberoNombre'] ?? json['BarberoNombre'] ?? json['nombreBarbero'] ?? json['NombreBarbero'];
    if (bNombreStr == null && json['barbero'] is String) bNombreStr = json['barbero'];
    if (rNombreStr == null && json['usuario'] is String) rNombreStr = json['usuario'];

    return Venta(
      id: json['id'] ?? json['ID'],
      numero: json['numero'] ?? json['Numero'] ?? json['numeroRecibo'] ?? json['NumeroRecibo'] ?? '',
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
      saldoAFavorUsado: (json['saldoAFavorUsado'] ?? json['SaldoAFavorUsado'])?.toDouble(),
      responsableNombre: rNombreStr,
      barberoNombreStr: bNombreStr,
      barberoPrestadorId: json['barberoPrestadorId'] ?? json['BarberoPrestadorId'],
      barberoPrestadorNombre: json['barberoPrestadorNombreCompleto'] ?? json['BarberoPrestadorNombreCompleto'],
      plazoDias: json['plazoDias'] ?? json['PlazoDias'],
      creditoBarberoUsado: (json['creditoBarberoUsado'] ?? json['CreditoBarberoUsado'])?.toDouble(),
      tipoVenta: json['tipoVenta'] ?? json['TipoVenta'],
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
      if (numero.isNotEmpty) 'NumeroRecibo': numero,
      'UsuarioId': usuarioId,
      // Omitir ClienteId cuando es 0 (venta invitado o venta barbero) para evitar FK inválida
      if (clienteId > 0) 'ClienteId': clienteId,
      if (barberoId != null) 'BarberoId': barberoId,
      if (barberoPrestadorId != null) 'BarberoPrestadorId': barberoPrestadorId,
      'MetodoPago': metodoPago,
      'Descuento': porcentajeDescuento,
      if (tipoVenta != null) 'TipoVenta': tipoVenta,
      if (clienteNombre != null) 'ClienteNombre': clienteNombre,
      if (plazoDias != null) 'PlazoDias': plazoDias,
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
    double? saldoAFavorUsado,
    String? responsableNombre,
    String? barberoNombreStr,
    int? barberoPrestadorId,
    String? barberoPrestadorNombre,
    int? plazoDias,
    double? creditoBarberoUsado,
    String? tipoVenta,
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
      saldoAFavorUsado: saldoAFavorUsado ?? this.saldoAFavorUsado,
      responsableNombre: responsableNombre ?? this.responsableNombre,
      barberoNombreStr: barberoNombreStr ?? this.barberoNombreStr,
      barberoPrestadorId: barberoPrestadorId ?? this.barberoPrestadorId,
      barberoPrestadorNombre: barberoPrestadorNombre ?? this.barberoPrestadorNombre,
      plazoDias: plazoDias ?? this.plazoDias,
      creditoBarberoUsado: creditoBarberoUsado ?? this.creditoBarberoUsado,
      tipoVenta: tipoVenta ?? this.tipoVenta,
      cliente: cliente ?? this.cliente,
      barbero: barbero ?? this.barbero,
      usuario: usuario ?? this.usuario,
      detalles: detalles ?? this.detalles,
    );
  }

  @override
  List<Object?> get props => [
        id, numero, fechaRegistro, clienteId, barberoId, usuarioId,
        metodoPago, subtotal, porcentajeDescuento, total, estado,
        clienteNombre, tipoVenta,
      ];
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
    final rawSubTotal = json['subTotal'] ?? json['SubTotal'];
    return DetalleVenta(
      id: json['id'] ?? json['Id'] ?? json['ID'],
      ventaId: json['ventaId'] ?? json['VentaId'] ?? json['VentaID'] ?? 0,
      productoId: json['productoId'] ?? json['ProductoId'] ?? json['ProductoID'],
      servicioId: json['servicioId'] ?? json['ServicioId'] ?? json['ServicioID'],
      paqueteId: json['paqueteId'] ?? json['PaqueteId'] ?? json['PaqueteID'],
      cantidad: json['cantidad'] ?? json['Cantidad'] ?? 0,
      precioUnitario: (json['precioUnitario'] ?? json['PrecioUnitario'] ?? 0).toDouble(),
      subTotal: rawSubTotal != null ? (rawSubTotal as num).toDouble() : null,
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