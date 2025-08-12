class VentaInsertarViewModel {
  String factNumero;
  String factTipoDeDocumento;
  int regCId;
  int clieId;
  int vendId;
  String factTipoVenta;
  DateTime factFechaEmision;
  DateTime factFechaLimiteEmision;
  String factRangoInicialAutorizado;
  String factRangoFinalAutorizado;
  double factLatitud;
  double factLongitud;
  String factReferencia;
  String factAutorizadoPor;
  int usuaCreacion;
  List<DetalleFacturaInput> detallesFacturaInput;

  VentaInsertarViewModel({
    required this.factNumero,
    required this.factTipoDeDocumento,
    required this.regCId,
    required this.clieId,
    required this.vendId,
    required this.factTipoVenta,
    required this.factFechaEmision,
    required this.factFechaLimiteEmision,
    required this.factRangoInicialAutorizado,
    required this.factRangoFinalAutorizado,
    required this.factLatitud,
    required this.factLongitud,
    required this.factReferencia,
    required this.factAutorizadoPor,
    required this.usuaCreacion,
    required this.detallesFacturaInput,
  });

  // Constructor con valores por defecto
  VentaInsertarViewModel.empty()
      : factNumero = '',
        factTipoDeDocumento = '',
        regCId = 0,
        clieId = 0,
        vendId = 0,
        factTipoVenta = '',
        factFechaEmision = DateTime.now(),
        factFechaLimiteEmision = DateTime.now(),
        factRangoInicialAutorizado = '',
        factRangoFinalAutorizado = '',
        factLatitud = 0.0,
        factLongitud = 0.0,
        factReferencia = '',
        factAutorizadoPor = '',
        usuaCreacion = 0,
        detallesFacturaInput = [];

  // Convertir a JSON para enviar al backend
  Map<String, dynamic> toJson() {
    final ventaData = {
      'fact_Numero': factNumero,
      'fact_TipoDeDocumento': factTipoDeDocumento,
      'regC_Id': regCId,
      'clie_Id': clieId,
      'vend_Id': vendId,
      'fact_TipoVenta': factTipoVenta,
      'fact_FechaEmision': factFechaEmision.toIso8601String(),
      'fact_FechaLimiteEmision': factFechaLimiteEmision.toIso8601String(),
      'fact_RangoInicialAutorizado': factRangoInicialAutorizado,
      'fact_RangoFinalAutorizado': factRangoFinalAutorizado,
      'fact_Latitud': factLatitud,
      'fact_Longitud': factLongitud,
      'fact_Referencia': factReferencia,
      'fact_AutorizadoPor': factAutorizadoPor,
      'usua_Creacion': usuaCreacion,
      'detallesFacturaInput': detallesFacturaInput.map((detalle) => detalle.toJson()).toList(),
    };
    
    // Imprimir el JSON completo para depuración
    print('VentaInsertarViewModel.toJson():');
    final jsonString = '''
    {
      "fact_Numero": "${ventaData['fact_Numero']}",
      "fact_TipoDeDocumento": "${ventaData['fact_TipoDeDocumento']}",
      "regC_Id": ${ventaData['regC_Id']},
      "clie_Id": ${ventaData['clie_Id']},
      "vend_Id": ${ventaData['vend_Id']},
      "fact_TipoVenta": "${ventaData['fact_TipoVenta']}",
      "fact_FechaEmision": "${ventaData['fact_FechaEmision']}",
      "fact_FechaLimiteEmision": "${ventaData['fact_FechaLimiteEmision']}",
      "fact_RangoInicialAutorizado": "${ventaData['fact_RangoInicialAutorizado']}",
      "fact_RangoFinalAutorizado": "${ventaData['fact_RangoFinalAutorizado']}",
      "fact_Latitud": ${ventaData['fact_Latitud']},
      "fact_Longitud": ${ventaData['fact_Longitud']},
      "fact_Referencia": "${ventaData['fact_Referencia']}",
      "fact_AutorizadoPor": "${ventaData['fact_AutorizadoPor']}",
      "usua_Creacion": ${ventaData['usua_Creacion']},
      "detallesFacturaInput": ${_formatDetalles(ventaData['detallesFacturaInput'] as List)}
    }
    ''';
    print(jsonString);
    
    return ventaData;
  }
  
  // Método auxiliar para formatear los detalles de la factura
  String _formatDetalles(List<dynamic> detalles) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < detalles.length; i++) {
      if (i > 0) buffer.write(',');
      final detalle = detalles[i] as Map<String, dynamic>;
      buffer.write('''
        {
          "prod_Id": ${detalle['prod_Id']},
          "faDe_Cantidad": ${detalle['faDe_Cantidad']}
        }'''
      );
    }
    buffer.write(']');
    return buffer.toString();
  }

  // Crear desde JSON (si necesitas deserializar)
  factory VentaInsertarViewModel.fromJson(Map<String, dynamic> json) {
    return VentaInsertarViewModel(
      factNumero: json['fact_Numero'] ?? '',
      factTipoDeDocumento: json['fact_TipoDeDocumento'] ?? '',
      regCId: json['regC_Id'] ?? 0,
      clieId: json['clie_Id'] ?? 0,
      vendId: json['vend_Id'] ?? 0,
      factTipoVenta: json['fact_TipoVenta'] ?? '',
      factFechaEmision: DateTime.parse(json['fact_FechaEmision'] ?? DateTime.now().toIso8601String()),
      factFechaLimiteEmision: DateTime.parse(json['fact_FechaLimiteEmision'] ?? DateTime.now().toIso8601String()),
      factRangoInicialAutorizado: json['fact_RangoInicialAutorizado'] ?? '',
      factRangoFinalAutorizado: json['fact_RangoFinalAutorizado'] ?? '',
      factLatitud: (json['fact_Latitud'] ?? 0).toDouble(),
      factLongitud: (json['fact_Longitud'] ?? 0).toDouble(),
      factReferencia: json['fact_Referencia'] ?? '',
      factAutorizadoPor: json['fact_AutorizadoPor'] ?? '',
      usuaCreacion: json['usua_Creacion'] ?? 0,
      detallesFacturaInput: (json['detallesFacturaInput'] as List<dynamic>? ?? [])
          .map((detalle) => DetalleFacturaInput.fromJson(detalle))
          .toList(),
    );
  }

  // Método para agregar un producto al detalle
  void agregarProducto(int prodId, double cantidad) {
    detallesFacturaInput.add(DetalleFacturaInput(
      prodId: prodId,
      faDeCantidad: cantidad,
    ));
  }

  // Método para remover un producto del detalle
  void removerProducto(int prodId) {
    detallesFacturaInput.removeWhere((detalle) => detalle.prodId == prodId);
  }

  // Método para actualizar la cantidad de un producto
  void actualizarCantidadProducto(int prodId, double nuevaCantidad) {
    final index = detallesFacturaInput.indexWhere((detalle) => detalle.prodId == prodId);
    if (index != -1) {
      detallesFacturaInput[index].faDeCantidad = nuevaCantidad;
    }
  }

  // Obtener el total de productos
  int get totalProductos => detallesFacturaInput.length;

  // Obtener la cantidad total de items
  double get cantidadTotalItems {
    return detallesFacturaInput.fold(0.0, (sum, detalle) => sum + detalle.faDeCantidad);
  }
}

class DetalleFacturaInput {
  int prodId;
  double faDeCantidad;

  DetalleFacturaInput({
    required this.prodId,
    required this.faDeCantidad,
  });

  // Constructor vacío
  DetalleFacturaInput.empty()
      : prodId = 0,
        faDeCantidad = 0;

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    final json = {
      'prod_Id': prodId,
      'faDe_Cantidad': faDeCantidad.toInt(), // Convertir a entero
    };
    print('DetalleFacturaInput.toJson(): $json');
    return json;
  }

  // Crear desde JSON
  factory DetalleFacturaInput.fromJson(Map<String, dynamic> json) {
    // Try both possible field names for backward compatibility
    final cantidad = (json['faDeCantidad'] ?? json['faDe_Cantidad'] ?? 0).toDouble();
    print('DetalleFacturaInput.fromJson(): $json, cantidad: $cantidad');
    return DetalleFacturaInput(
      prodId: json['prod_Id'] ?? 0,
      faDeCantidad: cantidad,
    );
  }

  @override
  String toString() {
    return 'DetalleFacturaInput{prodId: $prodId, faDeCantidad: $faDeCantidad}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DetalleFacturaInput &&
        other.prodId == prodId &&
        other.faDeCantidad == faDeCantidad;
  }

  @override
  int get hashCode => prodId.hashCode ^ faDeCantidad.hashCode;
}