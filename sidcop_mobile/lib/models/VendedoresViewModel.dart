class VendedoresViewModel {
  final int vend_Id;
  final String? vend_Codigo;
  final String? vend_DNI;
  final String? vend_Nombres;
  final String? vend_Apellidos;
  final String? vend_Telefono;
  final String? vend_Correo;
  final String? vend_Sexo;
  final String? vend_DireccionExacta;
  final int sucu_Id;
  final int colo_Id;
  final int? vend_Supervisor;
  final int? vend_Ayudante;
  final String? vend_Tipo;
  final bool? vend_EsExterno;
  final bool vend_Estado;
  final int usua_Creacion;
  final DateTime vend_FechaCreacion;
  final int? usua_Modificacion;
  final DateTime? vend_FechaModificacion;
  final String? sucu_Descripcion;
  final String? sucu_DireccionExacta;
  final String? colo_Descripcion;
  final String? muni_Codigo;
  final String? muni_Descripcion;
  final String? depa_Codigo;
  final String? depa_Descripcion;
  final String? nombreSupervisor;
  final String? apellidoSupervisor;
  final String? nombreAyudante;
  final String? apellidoAyudante;
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final String? rutas; // cadena cruda si el API la envía
  final List<VendedoreRutasViewModel> rutas_Json; // listado estructurado

  VendedoresViewModel({
    required this.vend_Id,
    required this.vend_Codigo,
    required this.vend_DNI,
    required this.vend_Nombres,
    required this.vend_Apellidos,
    required this.vend_Telefono,
    required this.vend_Correo,
    required this.vend_Sexo,
    required this.vend_DireccionExacta,
    required this.sucu_Id,
    required this.colo_Id,
    required this.vend_Supervisor,
    required this.vend_Ayudante,
    required this.vend_Tipo,
    required this.vend_EsExterno,
    required this.vend_Estado,
    required this.usua_Creacion,
    required this.vend_FechaCreacion,
    required this.usua_Modificacion,
    required this.vend_FechaModificacion,
    required this.sucu_Descripcion,
    required this.sucu_DireccionExacta,
    required this.colo_Descripcion,
    required this.muni_Codigo,
    required this.muni_Descripcion,
    required this.depa_Codigo,
    required this.depa_Descripcion,
    required this.nombreSupervisor,
    required this.apellidoSupervisor,
    required this.nombreAyudante,
    required this.apellidoAyudante,
    required this.usuarioCreacion,
    required this.usuarioModificacion,
    required this.rutas,
    required this.rutas_Json,
  });

  factory VendedoresViewModel.fromJson(Map<String, dynamic> json) {
    int _reqInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    int? _optInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    DateTime _reqDate(dynamic v) {
      if (v is DateTime) return v;
      if (v is String)
        return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
      throw ArgumentError('Fecha inválida: $v');
    }

    DateTime? _optDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    List<VendedoreRutasViewModel> rutasJson = [];
    final rawRutas = json['rutas_Json'];
    if (rawRutas is List) {
      rutasJson = rawRutas
          .whereType<Map<String, dynamic>>()
          .map((e) => VendedoreRutasViewModel.fromJson(e))
          .toList();
    }

    return VendedoresViewModel(
      vend_Id: _reqInt(json['vend_Id']),
      vend_Codigo: json['vend_Codigo']?.toString(),
      vend_DNI: json['vend_DNI']?.toString(),
      vend_Nombres: json['vend_Nombres']?.toString(),
      vend_Apellidos: json['vend_Apellidos']?.toString(),
      vend_Telefono: json['vend_Telefono']?.toString(),
      vend_Correo: json['vend_Correo']?.toString(),
      vend_Sexo: json['vend_Sexo']?.toString(),
      vend_DireccionExacta: json['vend_DireccionExacta']?.toString(),
      sucu_Id: _reqInt(json['sucu_Id']),
      colo_Id: _reqInt(json['colo_Id']),
      vend_Supervisor: _optInt(json['vend_Supervisor']),
      vend_Ayudante: _optInt(json['vend_Ayudante']),
      vend_Tipo: json['vend_Tipo']?.toString(),
      vend_EsExterno: json['vend_EsExterno'] is bool
          ? json['vend_EsExterno'] as bool?
          : (json['vend_EsExterno']?.toString().toLowerCase() == 'true'
                ? true
                : json['vend_EsExterno']?.toString().toLowerCase() == 'false'
                ? false
                : null),
      vend_Estado: (json['vend_Estado'] is bool)
          ? json['vend_Estado'] as bool
          : json['vend_Estado'].toString().toLowerCase() == 'true',
      usua_Creacion: _reqInt(json['usua_Creacion']),
      vend_FechaCreacion: _reqDate(json['vend_FechaCreacion']),
      usua_Modificacion: _optInt(json['usua_Modificacion']),
      vend_FechaModificacion: _optDate(json['vend_FechaModificacion']),
      sucu_Descripcion: json['sucu_Descripcion']?.toString(),
      sucu_DireccionExacta: json['sucu_DireccionExacta']?.toString(),
      colo_Descripcion: json['colo_Descripcion']?.toString(),
      muni_Codigo: json['muni_Codigo']?.toString(),
      muni_Descripcion: json['muni_Descripcion']?.toString(),
      depa_Codigo: json['depa_Codigo']?.toString(),
      depa_Descripcion: json['depa_Descripcion']?.toString(),
      nombreSupervisor: json['nombreSupervisor']?.toString(),
      apellidoSupervisor: json['apellidoSupervisor']?.toString(),
      nombreAyudante: json['nombreAyudante']?.toString(),
      apellidoAyudante: json['apellidoAyudante']?.toString(),
      usuarioCreacion: json['usuarioCreacion']?.toString(),
      usuarioModificacion: json['usuarioModificacion']?.toString(),
      rutas: json['rutas']?.toString(),
      rutas_Json: rutasJson,
    );
  }

  Map<String, dynamic> toJson() => {
    'vend_Id': vend_Id,
    'vend_Codigo': vend_Codigo,
    'vend_DNI': vend_DNI,
    'vend_Nombres': vend_Nombres,
    'vend_Apellidos': vend_Apellidos,
    'vend_Telefono': vend_Telefono,
    'vend_Correo': vend_Correo,
    'vend_Sexo': vend_Sexo,
    'vend_DireccionExacta': vend_DireccionExacta,
    'sucu_Id': sucu_Id,
    'colo_Id': colo_Id,
    'vend_Supervisor': vend_Supervisor,
    'vend_Ayudante': vend_Ayudante,
    'vend_Tipo': vend_Tipo,
    'vend_EsExterno': vend_EsExterno,
    'vend_Estado': vend_Estado,
    'usua_Creacion': usua_Creacion,
    'vend_FechaCreacion': vend_FechaCreacion.toIso8601String(),
    'usua_Modificacion': usua_Modificacion,
    'vend_FechaModificacion': vend_FechaModificacion?.toIso8601String(),
    'sucu_Descripcion': sucu_Descripcion,
    'sucu_DireccionExacta': sucu_DireccionExacta,
    'colo_Descripcion': colo_Descripcion,
    'muni_Codigo': muni_Codigo,
    'muni_Descripcion': muni_Descripcion,
    'depa_Codigo': depa_Codigo,
    'depa_Descripcion': depa_Descripcion,
    'nombreSupervisor': nombreSupervisor,
    'apellidoSupervisor': apellidoSupervisor,
    'nombreAyudante': nombreAyudante,
    'apellidoAyudante': apellidoAyudante,
    'usuarioCreacion': usuarioCreacion,
    'usuarioModificacion': usuarioModificacion,
    'rutas': rutas,
    'rutas_Json': rutas_Json.map((e) => e.toJson()).toList(),
  };

  VendedoresViewModel copyWith({
    int? vend_Id,
    String? vend_Codigo,
    String? vend_DNI,
    String? vend_Nombres,
    String? vend_Apellidos,
    String? vend_Telefono,
    String? vend_Correo,
    String? vend_Sexo,
    String? vend_DireccionExacta,
    int? sucu_Id,
    int? colo_Id,
    int? vend_Supervisor,
    int? vend_Ayudante,
    String? vend_Tipo,
    bool? vend_EsExterno,
    bool? vend_Estado,
    int? usua_Creacion,
    DateTime? vend_FechaCreacion,
    int? usua_Modificacion,
    DateTime? vend_FechaModificacion,
    String? sucu_Descripcion,
    String? sucu_DireccionExacta,
    String? colo_Descripcion,
    String? muni_Codigo,
    String? muni_Descripcion,
    String? depa_Codigo,
    String? depa_Descripcion,
    String? nombreSupervisor,
    String? apellidoSupervisor,
    String? nombreAyudante,
    String? apellidoAyudante,
    String? usuarioCreacion,
    String? usuarioModificacion,
    String? rutas,
    List<VendedoreRutasViewModel>? rutas_Json,
  }) {
    return VendedoresViewModel(
      vend_Id: vend_Id ?? this.vend_Id,
      vend_Codigo: vend_Codigo ?? this.vend_Codigo,
      vend_DNI: vend_DNI ?? this.vend_DNI,
      vend_Nombres: vend_Nombres ?? this.vend_Nombres,
      vend_Apellidos: vend_Apellidos ?? this.vend_Apellidos,
      vend_Telefono: vend_Telefono ?? this.vend_Telefono,
      vend_Correo: vend_Correo ?? this.vend_Correo,
      vend_Sexo: vend_Sexo ?? this.vend_Sexo,
      vend_DireccionExacta: vend_DireccionExacta ?? this.vend_DireccionExacta,
      sucu_Id: sucu_Id ?? this.sucu_Id,
      colo_Id: colo_Id ?? this.colo_Id,
      vend_Supervisor: vend_Supervisor ?? this.vend_Supervisor,
      vend_Ayudante: vend_Ayudante ?? this.vend_Ayudante,
      vend_Tipo: vend_Tipo ?? this.vend_Tipo,
      vend_EsExterno: vend_EsExterno ?? this.vend_EsExterno,
      vend_Estado: vend_Estado ?? this.vend_Estado,
      usua_Creacion: usua_Creacion ?? this.usua_Creacion,
      vend_FechaCreacion: vend_FechaCreacion ?? this.vend_FechaCreacion,
      usua_Modificacion: usua_Modificacion ?? this.usua_Modificacion,
      vend_FechaModificacion:
          vend_FechaModificacion ?? this.vend_FechaModificacion,
      sucu_Descripcion: sucu_Descripcion ?? this.sucu_Descripcion,
      sucu_DireccionExacta: sucu_DireccionExacta ?? this.sucu_DireccionExacta,
      colo_Descripcion: colo_Descripcion ?? this.colo_Descripcion,
      muni_Codigo: muni_Codigo ?? this.muni_Codigo,
      muni_Descripcion: muni_Descripcion ?? this.muni_Descripcion,
      depa_Codigo: depa_Codigo ?? this.depa_Codigo,
      depa_Descripcion: depa_Descripcion ?? this.depa_Descripcion,
      nombreSupervisor: nombreSupervisor ?? this.nombreSupervisor,
      apellidoSupervisor: apellidoSupervisor ?? this.apellidoSupervisor,
      nombreAyudante: nombreAyudante ?? this.nombreAyudante,
      apellidoAyudante: apellidoAyudante ?? this.apellidoAyudante,
      usuarioCreacion: usuarioCreacion ?? this.usuarioCreacion,
      usuarioModificacion: usuarioModificacion ?? this.usuarioModificacion,
      rutas: rutas ?? this.rutas,
      rutas_Json: rutas_Json ?? this.rutas_Json,
    );
  }
}

class VendedoreRutasViewModel {
  final int ruta_Id;
  final String? veRu_Dias;

  VendedoreRutasViewModel({required this.ruta_Id, required this.veRu_Dias});

  factory VendedoreRutasViewModel.fromJson(Map<String, dynamic> json) {
    int _reqInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return VendedoreRutasViewModel(
      ruta_Id: _reqInt(json['ruta_Id']),
      veRu_Dias: json['veRu_Dias']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {'ruta_Id': ruta_Id, 'veRu_Dias': veRu_Dias};

  VendedoreRutasViewModel copyWith({int? ruta_Id, String? veRu_Dias}) =>
      VendedoreRutasViewModel(
        ruta_Id: ruta_Id ?? this.ruta_Id,
        veRu_Dias: veRu_Dias ?? this.veRu_Dias,
      );
}
