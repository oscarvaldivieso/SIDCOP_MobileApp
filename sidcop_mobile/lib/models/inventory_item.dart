import 'package:flutter/material.dart';

class InventoryItem {
  final int inBoId;
  final int bodeId;
  final int prodId;
  final int inBoCantidad;
  final int cantidadAsignada;
  final double precio;
  final String codigoProducto;
  final String subcDescripcion;
  final String prodImagen;
  final String nombreProducto;
  final String cantidadActual;
  final int usuaCreacion;
  final String inBoFechaCreacion;
  final int? usuaModificacion;
  final String? inBoFechaModificacion;
  final bool inBoEstado;

  InventoryItem({
    required this.inBoId,
    required this.bodeId,
    required this.prodId,
    required this.inBoCantidad,
    required this.cantidadAsignada,
    required this.precio,
    required this.codigoProducto,
    required this.subcDescripcion,
    required this.prodImagen,
    required this.nombreProducto,
    required this.cantidadActual,
    required this.usuaCreacion,
    required this.inBoFechaCreacion,
    this.usuaModificacion,
    this.inBoFechaModificacion,
    required this.inBoEstado,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      inBoId: json['inBo_Id'] ?? 0,
      bodeId: json['bode_Id'] ?? 0,
      prodId: json['prod_Id'] ?? 0,
      inBoCantidad: json['inBo_Cantidad'] ?? 0,
      cantidadAsignada: json['cantidadAsignada'] ?? 0,
      precio: (json['precio'] ?? 0).toDouble(),
      codigoProducto: json['codigoProducto'] ?? '',
      subcDescripcion: json['subc_Descripcion'] ?? '',
      prodImagen: json['prod_Imagen'] ?? '',
      nombreProducto: json['nombreProducto'] ?? '',
      cantidadActual: json['cantidadActual'] ?? '0',
      usuaCreacion: json['usua_Creacion'] ?? 0,
      inBoFechaCreacion: json['inBo_FechaCreacion'] ?? '',
      usuaModificacion: json['usua_Modificacion'],
      inBoFechaModificacion: json['inBo_FechaModificacion'],
      inBoEstado: json['inBo_Estado'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inBo_Id': inBoId,
      'bode_Id': bodeId,
      'prod_Id': prodId,
      'inBo_Cantidad': inBoCantidad,
      'cantidadAsignada': cantidadAsignada,
      'precio': precio,
      'codigoProducto': codigoProducto,
      'subc_Descripcion': subcDescripcion,
      'prod_Imagen': prodImagen,
      'nombreProducto': nombreProducto,
      'cantidadActual': cantidadActual,
      'usua_Creacion': usuaCreacion,
      'inBo_FechaCreacion': inBoFechaCreacion,
      'usua_Modificacion': usuaModificacion,
      'inBo_FechaModificacion': inBoFechaModificacion,
      'inBo_Estado': inBoEstado,
    };
  }

  // Helper methods for UI
  int get currentQuantity => int.tryParse(cantidadActual) ?? 0;
  int get soldQuantity => cantidadAsignada - currentQuantity;
  double get stockPercentage => currentQuantity / cantidadAsignada;
  
  String get statusText {
    if (currentQuantity == 0) return 'Agotado';
    if (stockPercentage <= 0.3) return 'Stock Bajo';
    return 'Disponible';
  }
  
  Color get statusColor {
    if (currentQuantity == 0) return const Color(0xFFE74C3C);
    if (stockPercentage <= 0.3) return const Color(0xFFF39C12);
    return const Color(0xFF27AE60);
  }
}
