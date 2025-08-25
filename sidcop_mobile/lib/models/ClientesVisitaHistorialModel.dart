// Modelo para ClientesVisitaHistorial adaptado al JSON proporcionado
class ClientesVisitaHistorialModel {
  final int? clVi_Id;
  final int? veRu_Id;
  final int? vend_Id;
  final String? vendedor;
  final String? cliente;
  final String? clie_NombreNegocio;
  final String? esVi_Descripcion;
  final String? clVi_Observaciones;
  final DateTime? clVi_Fecha;
  final int? usua_Creacion;
  final String? usuarioCreacion;
  final DateTime? clVi_FechaCreacion;
  final int? diCl_Id;
  final int? esVi_Id;
  final double? clVi_Latitud;
  final double? clVi_Longitud;
  // Relaciones / objetos anidados (se mantienen dinámicos)
  final dynamic diCl;
  final dynamic esVi;
  final dynamic usua_CreacionNavigation;
  final dynamic veRu;
  final List<dynamic>? tbImagenesVisita;

  ClientesVisitaHistorialModel({
    this.clVi_Id,
    this.veRu_Id,
    this.vend_Id,
    this.vendedor,
    this.cliente,
    this.clie_NombreNegocio,
    this.esVi_Descripcion,
    this.clVi_Observaciones,
    this.clVi_Fecha,
    this.usua_Creacion,
    this.usuarioCreacion,
    this.clVi_FechaCreacion,
    this.diCl_Id,
    this.esVi_Id,
    this.clVi_Latitud,
    this.clVi_Longitud,
    this.diCl,
    this.esVi,
    this.usua_CreacionNavigation,
    this.veRu,
    this.tbImagenesVisita,
  });

  factory ClientesVisitaHistorialModel.fromJson(Map<String, dynamic> json) {
    // helper que acepta camelCase o PascalCase (ej: clVi_Id o ClVi_Id)
    T? _get<T>(String a, String b) {
      if (json.containsKey(a)) return json[a] as T?;
      if (json.containsKey(b)) return json[b] as T?;
      return null;
    }

    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.tryParse(v.toString());
      } catch (_) {
        return null;
      }
    }

    double? _toDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final tbImgs = json['tbImagenesVisita'] ?? json['TbImagenesVisita'];

    return ClientesVisitaHistorialModel(
      clVi_Id: _get<int>('clVi_Id', 'ClVi_Id'),
      veRu_Id: _get<int>('veRu_Id', 'VeRu_Id'),
      vend_Id: _get<int>('vend_Id', 'Vend_Id'),
      vendedor: _get<String>('vendedor', 'Vendedor'),
      cliente: _get<String>('cliente', 'Cliente'),
      clie_NombreNegocio: _get<String>('clie_NombreNegocio', 'Clie_NombreNegocio'),
      esVi_Descripcion: _get<String>('esVi_Descripcion', 'EsVi_Descripcion'),
      clVi_Observaciones: _get<String>('clVi_Observaciones', 'ClVi_Observaciones'),
      clVi_Fecha: _parseDate(_get<dynamic>('clVi_Fecha', 'ClVi_Fecha')),
      usua_Creacion: _get<int>('usua_Creacion', 'Usua_Creacion'),
      usuarioCreacion: _get<String>('usuarioCreacion', 'UsuarioCreacion'),
      clVi_FechaCreacion: _parseDate(_get<dynamic>('clVi_FechaCreacion', 'ClVi_FechaCreacion')),
      diCl_Id: _get<int>('diCl_Id', 'DiCl_Id'),
      esVi_Id: _get<int>('esVi_Id', 'EsVi_Id'),
      clVi_Latitud: _toDouble(_get<dynamic>('clVi_Latitud', 'ClVi_Latitud')),
      clVi_Longitud: _toDouble(_get<dynamic>('clVi_Longitud', 'ClVi_Longitud')),
      diCl: json['diCl'] ?? json['DiCl'] ?? null,
      esVi: json['esVi'] ?? json['EsVi'] ?? null,
      usua_CreacionNavigation: json['usua_CreacionNavigation'] ?? json['Usua_CreacionNavigation'] ?? null,
      veRu: json['veRu'] ?? json['VeRu'] ?? null,
      tbImagenesVisita: tbImgs is List ? List<dynamic>.from(tbImgs as List) : null,
    );
  }

  Map<String, dynamic> toJson() {
    // Include both camelCase and PascalCase keys for compatibility with backend
    return {
      'clVi_Id': clVi_Id,
      'ClVi_Id': clVi_Id,
      'veRu_Id': veRu_Id,
      'VeRu_Id': veRu_Id,
      'vend_Id': vend_Id,
      'Vend_Id': vend_Id,
      'vendedor': vendedor,
      'Vendedor': vendedor,
      'cliente': cliente,
      'Cliente': cliente,
      'clie_NombreNegocio': clie_NombreNegocio,
      'Clie_NombreNegocio': clie_NombreNegocio,
      'esVi_Descripcion': esVi_Descripcion,
      'EsVi_Descripcion': esVi_Descripcion,
      'clVi_Observaciones': clVi_Observaciones,
      'ClVi_Observaciones': clVi_Observaciones,
      'clVi_Fecha': clVi_Fecha?.toIso8601String(),
      'ClVi_Fecha': clVi_Fecha?.toIso8601String(),
      'usua_Creacion': usua_Creacion,
      'Usua_Creacion': usua_Creacion,
      'usuarioCreacion': usuarioCreacion,
      'UsuarioCreacion': usuarioCreacion,
      'clVi_FechaCreacion': clVi_FechaCreacion?.toIso8601String(),
      'ClVi_FechaCreacion': clVi_FechaCreacion?.toIso8601String(),
      'diCl_Id': diCl_Id,
      'DiCl_Id': diCl_Id,
      'esVi_Id': esVi_Id,
      'EsVi_Id': esVi_Id,
      'clVi_Latitud': clVi_Latitud,
      'ClVi_Latitud': clVi_Latitud,
      'clVi_Longitud': clVi_Longitud,
      'ClVi_Longitud': clVi_Longitud,
      'diCl': diCl,
      'DiCl': diCl,
      'esVi': esVi,
      'EsVi': esVi,
      'usua_CreacionNavigation': usua_CreacionNavigation,
      'Usua_CreacionNavigation': usua_CreacionNavigation,
      'veRu': veRu,
      'VeRu': veRu,
      'tbImagenesVisita': tbImagenesVisita,
      'TbImagenesVisita': tbImagenesVisita,
    };
  }
}
