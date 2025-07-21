class Productos {
  final int prod_Id;
  final String? prod_Codigo;
  final String? prod_CodigoBarra;
  final String? prod_Descripcion;
  final String? prod_DescripcionCorta;
  final String? prod_Imagen;
  final int marc_Id;
  final int cate_Id;
  final int subc_Id;
  final int prov_Id;
  final int impu_Id;

  // productos
  final double prod_PrecioUnitario;
  final double prod_CostoTotal;
  final bool prod_PagaImpuesto;
  final int prod_PromODesc;
  final bool prod_EsPromo;

  // auditoria
  final int usua_Creacion;
  final DateTime prod_FechaCreacion;
  final int usua_Modificacion;
  final DateTime prod_FechaModificacion;
  final bool prod_Estado;

  // not mapped
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final String? marc_Descripcion;
  final String? cate_Descripcion;
  final String? prov_NombreEmpresa;
  final String? subc_Descripcion;
  final String? impu_Descripcion;

  Productos({
    required this.prod_Id,
    this.prod_Codigo,
    this.prod_CodigoBarra,
    this.prod_Descripcion,
    this.prod_DescripcionCorta,
    this.prod_Imagen,
    required this.marc_Id,
    required this.cate_Id,
    required this.subc_Id,
    required this.prov_Id,
    required this.impu_Id,
    required this.prod_PrecioUnitario,
    required this.prod_CostoTotal,
    this.prod_PagaImpuesto = true,
    required this.prod_PromODesc,
    this.prod_EsPromo = true,
    required this.usua_Creacion,
    required this.prod_FechaCreacion,
    required this.usua_Modificacion,
    required this.prod_FechaModificacion,
    this.prod_Estado = true,
    this.usuarioCreacion,
    this.usuarioModificacion,
    this.marc_Descripcion,
    this.cate_Descripcion,
    this.prov_NombreEmpresa,
    this.subc_Descripcion,
    this.impu_Descripcion,
  });

  // Función auxiliar para convertir valores a boolean
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1' || value.toLowerCase() == 'sí' || value.toLowerCase() == 'si';
    }
    if (value is int) return value == 1;
    return false; // valor por defecto
  }

  // Función auxiliar para convertir valores a int de forma segura
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  // Función auxiliar para convertir valores a double de forma segura
  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Función auxiliar para convertir valores a DateTime de forma segura
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now(); // Valor por defecto si es null
    if (value is DateTime) return value;
    if (value is String) {
      if (value.isEmpty) return DateTime.now();
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing date: $value - $e');
        return DateTime.now();
      }
    }
    return DateTime.now(); // valor por defecto
  }

  Map<String, dynamic> toJson() {
    return {
      "prod_Id": prod_Id,
      "prod_Codigo": prod_Codigo,
      "prod_CodigoBarra": prod_CodigoBarra,
      "prod_Descripcion": prod_Descripcion,
      "prod_DescripcionCorta": prod_DescripcionCorta,
      "prod_Imagen": prod_Imagen,
      "cate_Id": cate_Id,
      "subc_Id": subc_Id,
      "marc_Id": marc_Id,
      "prov_Id": prov_Id,
      "impu_Id": impu_Id,
      // productos
      "prod_PrecioUnitario": prod_PrecioUnitario,
      "prod_CostoTotal": prod_CostoTotal,
      "prod_PagaImpuesto": prod_PagaImpuesto,
      "prod_PromODesc": prod_PromODesc,
      "prod_EsPromo": prod_EsPromo,
      // auditoria
      "usua_Creacion": usua_Creacion,
      "prod_FechaCreacion": prod_FechaCreacion.toUtc().toIso8601String(),
      "usua_Modificacion": usua_Modificacion,
      "prod_FechaModificacion": prod_FechaModificacion.toUtc().toIso8601String(),
      "prod_Estado": prod_Estado,
      // not mapped
      "usuarioCreacion": usuarioCreacion,
      "usuarioModificacion": usuarioModificacion,
      "marc_Descripcion": marc_Descripcion,
      "cate_Descripcion": cate_Descripcion,
      "prov_NombreEmpresa": prov_NombreEmpresa,
      "subc_Descripcion": subc_Descripcion,
      "impu_Descripcion": impu_Descripcion,
    };
  }

  factory Productos.fromJson(Map<String, dynamic> json) {
    try {
      return Productos(
        prod_Id: _parseInt(json['prod_Id']),
        prod_Codigo: json['prod_Codigo']?.toString(),
        prod_CodigoBarra: json['prod_CodigoBarra']?.toString(),
        prod_Descripcion: json['prod_Descripcion']?.toString(),
        prod_DescripcionCorta: json['prod_DescripcionCorta']?.toString(),
        prod_Imagen: json['prod_Imagen']?.toString(),
        marc_Id: _parseInt(json['marc_Id']),
        cate_Id: _parseInt(json['cate_Id']),
        subc_Id: _parseInt(json['subc_Id']),
        prov_Id: _parseInt(json['prov_Id']),
        impu_Id: _parseInt(json['impu_Id']),
        prod_PrecioUnitario: _parseDouble(json['prod_PrecioUnitario']),
        prod_CostoTotal: _parseDouble(json['prod_CostoTotal']),
        prod_PagaImpuesto: _parseBool(json['prod_PagaImpuesto']),
        prod_PromODesc: _parseInt(json['prod_PromODesc']),
        prod_EsPromo: _parseBool(json['prod_EsPromo']),
        // auditoria
        usua_Creacion: _parseInt(json['usua_Creacion']),
        prod_FechaCreacion: _parseDateTime(json['prod_FechaCreacion']),
        usua_Modificacion: _parseInt(json['usua_Modificacion']),
        prod_FechaModificacion: _parseDateTime(json['prod_FechaModificacion']),
        prod_Estado: _parseBool(json['prod_Estado']),
        // not mapped
        usuarioCreacion: json['usuarioCreacion']?.toString(),
        usuarioModificacion: json['usuarioModificacion']?.toString(),
        marc_Descripcion: json['marc_Descripcion']?.toString(),
        cate_Descripcion: json['cate_Descripcion']?.toString(),
        prov_NombreEmpresa: json['prov_NombreEmpresa']?.toString(),
        subc_Descripcion: json['subc_Descripcion']?.toString(),
        impu_Descripcion: json['impu_Descripcion']?.toString(),
      );
    } catch (e) {
      print('Error parsing Productos from JSON: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}