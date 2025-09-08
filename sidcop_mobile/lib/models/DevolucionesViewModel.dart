class DevolucionesViewModel {
  final int devoId;
  final int? factId;
  final DateTime devoFecha;
  final String devoMotivo;
  final int usuaCreacion;
  final DateTime devoFechaCreacion;
  final int? usuaModificacion;
  final DateTime? devoFechaModificacion;
  final bool devoEstado;
  final String? nombreCompleto;
  final String? clieNombreNegocio;
  final String? usuarioCreacion;
  final String? usuarioModificacion;

  DevolucionesViewModel({
    required this.devoId,
    this.factId,
    required this.devoFecha,
    required this.devoMotivo,
    required this.usuaCreacion,
    required this.devoFechaCreacion,
    this.usuaModificacion,
    this.devoFechaModificacion,
    required this.devoEstado,
    this.nombreCompleto,
    this.clieNombreNegocio,
    this.usuarioCreacion,
    this.usuarioModificacion,
  });

  factory DevolucionesViewModel.fromJson(Map<String, dynamic> json) {
    // Normalizar las claves del JSON para manejar diferentes formatos
    Map<String, dynamic> normalizedJson = _normalizeKeys(json);

    // Resolver valores de ID y fecha con manejo más robusto
    int devoId = _resolveInt(
      normalizedJson,
      'devo_Id',
      alternativeKeys: ['devoId', 'id'],
    );
    int? factId = _resolveIntNullable(
      normalizedJson,
      'fact_Id',
      alternativeKeys: ['factId'],
    );

    // Parseo robusto de fechas
    DateTime devoFecha = _resolveDateTime(
      normalizedJson,
      'devo_Fecha',
      alternativeKeys: ['devoFecha', 'fecha'],
      fallback: DateTime.now(),
    );

    DateTime devoFechaCreacion = _resolveDateTime(
      normalizedJson,
      'devo_FechaCreacion',
      alternativeKeys: ['devoFechaCreacion', 'fechaCreacion'],
      fallback: DateTime.now(),
    );

    DateTime? devoFechaModificacion = _resolveDateTimeNullable(
      normalizedJson,
      'devo_FechaModificacion',
      alternativeKeys: ['devoFechaModificacion', 'fechaModificacion'],
    );

    // Otros valores con manejo robusto
    String devoMotivo = _resolveString(
      normalizedJson,
      'devo_Motivo',
      alternativeKeys: ['devoMotivo', 'motivo'],
      fallback: "Sin motivo especificado",
    );

    int usuaCreacion = _resolveInt(
      normalizedJson,
      'usua_Creacion',
      alternativeKeys: ['usuaCreacion'],
      fallback: 0,
    );

    int? usuaModificacion = _resolveIntNullable(
      normalizedJson,
      'usua_Modificacion',
      alternativeKeys: ['usuaModificacion'],
    );

    bool devoEstado = _resolveBool(
      normalizedJson,
      'devo_Estado',
      alternativeKeys: ['devoEstado', 'estado'],
      fallback: true,
    );

    // Campos de texto opcionales
    String? nombreCompleto = _resolveStringNullable(
      normalizedJson,
      'nombre_Completo',
      alternativeKeys: ['nombreCompleto'],
    );

    String? clieNombreNegocio = _resolveStringNullable(
      normalizedJson,
      'clie_NombreNegocio',
      alternativeKeys: ['clieNombreNegocio', 'nombreNegocio'],
    );

    String? usuarioCreacion = _resolveStringNullable(
      normalizedJson,
      'usuarioCreacion',
    );

    String? usuarioModificacion = _resolveStringNullable(
      normalizedJson,
      'usuarioModificacion',
    );

    return DevolucionesViewModel(
      devoId: devoId,
      factId: factId,
      devoFecha: devoFecha,
      devoMotivo: devoMotivo,
      usuaCreacion: usuaCreacion,
      devoFechaCreacion: devoFechaCreacion,
      usuaModificacion: usuaModificacion,
      devoFechaModificacion: devoFechaModificacion,
      devoEstado: devoEstado,
      nombreCompleto: nombreCompleto,
      clieNombreNegocio: clieNombreNegocio,
      usuarioCreacion: usuarioCreacion,
      usuarioModificacion: usuarioModificacion,
    );
  }

  // Métodos de utilidad para la deserialización robusta

  /// Normaliza las claves del JSON para manejar diferentes formatos de nombres de campo
  static Map<String, dynamic> _normalizeKeys(Map<String, dynamic> json) {
    Map<String, dynamic> normalized = {};
    json.forEach((key, value) {
      // Preservar la clave original
      normalized[key] = value;

      // Si tenemos claves como "devoId", también crear "devo_Id" si no existe
      if (key.startsWith('devo') &&
          key.length > 4 &&
          key[4].toUpperCase() == key[4]) {
        String normalizedKey = key.substring(0, 4) + '_' + key.substring(4);
        if (!json.containsKey(normalizedKey)) {
          normalized[normalizedKey] = value;
        }
      }
    });
    return normalized;
  }

  /// Resuelve un valor entero de un mapa, con manejo de errores y valores por defecto
  static int _resolveInt(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
    int fallback = 0,
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (_) {}
      }
      if (value is double) return value.toInt();
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          if (value is int) return value;
          if (value is String) {
            try {
              return int.parse(value);
            } catch (_) {}
          }
          if (value is double) return value.toInt();
        }
      }
    }

    // Si no se encontró un valor válido, usar el valor por defecto
    return fallback;
  }

  /// Resuelve un valor entero nullable de un mapa
  static int? _resolveIntNullable(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (_) {}
      }
      if (value is double) return value.toInt();
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          if (value is int) return value;
          if (value is String) {
            try {
              return int.parse(value);
            } catch (_) {}
          }
          if (value is double) return value.toInt();
        }
      }
    }

    // Si no se encontró un valor válido, devolver null
    return null;
  }

  /// Resuelve un valor String de un mapa, con manejo de errores y valores por defecto
  static String _resolveString(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
    String fallback = "",
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      return value.toString();
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          return value.toString();
        }
      }
    }

    // Si no se encontró un valor válido, usar el valor por defecto
    return fallback;
  }

  /// Resuelve un valor String nullable de un mapa
  static String? _resolveStringNullable(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      return value.toString();
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          return value.toString();
        }
      }
    }

    // Si no se encontró un valor válido, devolver null
    return null;
  }

  /// Resuelve un valor booleano de un mapa, con manejo de errores y valores por defecto
  static bool _resolveBool(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
    bool fallback = false,
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      if (value is bool) return value;
      if (value is int) return value != 0;
      if (value is String) {
        if (value.toLowerCase() == 'true') return true;
        if (value.toLowerCase() == 'false') return false;
        try {
          return int.parse(value) != 0;
        } catch (_) {}
      }
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          if (value is bool) return value;
          if (value is int) return value != 0;
          if (value is String) {
            if (value.toLowerCase() == 'true') return true;
            if (value.toLowerCase() == 'false') return false;
            try {
              return int.parse(value) != 0;
            } catch (_) {}
          }
        }
      }
    }

    // Si no se encontró un valor válido, usar el valor por defecto
    return fallback;
  }

  /// Resuelve un valor DateTime de un mapa, con manejo de errores y valores por defecto
  static DateTime _resolveDateTime(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
    DateTime? fallback,
  }) {
    fallback ??= DateTime.now();

    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          // Intentar formatos alternativos
          try {
            // Para formato "dd/MM/yyyy"
            if (value.contains('/')) {
              List<String> parts = value.split('/');
              if (parts.length == 3) {
                int day = int.parse(parts[0]);
                int month = int.parse(parts[1]);
                int year = int.parse(parts[2]);
                return DateTime(year, month, day);
              }
            }
          } catch (_) {}
        }
      }
      if (value is int) {
        try {
          // Interpretar como timestamp en milisegundos
          return DateTime.fromMillisecondsSinceEpoch(value);
        } catch (_) {}
      }
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          if (value is DateTime) return value;
          if (value is String) {
            try {
              return DateTime.parse(value);
            } catch (_) {
              // Intentar formatos alternativos
              try {
                // Para formato "dd/MM/yyyy"
                if (value.contains('/')) {
                  List<String> parts = value.split('/');
                  if (parts.length == 3) {
                    int day = int.parse(parts[0]);
                    int month = int.parse(parts[1]);
                    int year = int.parse(parts[2]);
                    return DateTime(year, month, day);
                  }
                }
              } catch (_) {}
            }
          }
          if (value is int) {
            try {
              // Interpretar como timestamp en milisegundos
              return DateTime.fromMillisecondsSinceEpoch(value);
            } catch (_) {}
          }
        }
      }
    }

    // Si no se encontró un valor válido, usar el valor por defecto
    return fallback;
  }

  /// Resuelve un valor DateTime nullable de un mapa
  static DateTime? _resolveDateTimeNullable(
    Map<String, dynamic> json,
    String key, {
    List<String>? alternativeKeys,
  }) {
    // Intentar con la clave principal
    dynamic value = json[key];
    if (value != null) {
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (_) {
          // Intentar formatos alternativos
          try {
            // Para formato "dd/MM/yyyy"
            if (value.contains('/')) {
              List<String> parts = value.split('/');
              if (parts.length == 3) {
                int day = int.parse(parts[0]);
                int month = int.parse(parts[1]);
                int year = int.parse(parts[2]);
                return DateTime(year, month, day);
              }
            }
          } catch (_) {}
        }
      }
      if (value is int) {
        try {
          // Interpretar como timestamp en milisegundos
          return DateTime.fromMillisecondsSinceEpoch(value);
        } catch (_) {}
      }
    }

    // Si hay claves alternativas, intentar con ellas
    if (alternativeKeys != null) {
      for (String altKey in alternativeKeys) {
        value = json[altKey];
        if (value != null) {
          if (value is DateTime) return value;
          if (value is String) {
            try {
              return DateTime.parse(value);
            } catch (_) {
              // Intentar formatos alternativos
              try {
                // Para formato "dd/MM/yyyy"
                if (value.contains('/')) {
                  List<String> parts = value.split('/');
                  if (parts.length == 3) {
                    int day = int.parse(parts[0]);
                    int month = int.parse(parts[1]);
                    int year = int.parse(parts[2]);
                    return DateTime(year, month, day);
                  }
                }
              } catch (_) {}
            }
          }
          if (value is int) {
            try {
              // Interpretar como timestamp en milisegundos
              return DateTime.fromMillisecondsSinceEpoch(value);
            } catch (_) {}
          }
        }
      }
    }

    // Si no se encontró un valor válido, devolver null
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'devo_Id': devoId,
      'fact_Id': factId,
      'devo_Fecha': devoFecha.toIso8601String(),
      'devo_Motivo': devoMotivo,
      'usua_Creacion': usuaCreacion,
      'devo_FechaCreacion': devoFechaCreacion.toIso8601String(),
      'usua_Modificacion': usuaModificacion,
      'devo_FechaModificacion': devoFechaModificacion?.toIso8601String(),
      'devo_Estado': devoEstado,
      'nombre_Completo': nombreCompleto,
      'clie_NombreNegocio': clieNombreNegocio,
      'usuarioCreacion': usuarioCreacion,
      'usuarioModificacion': usuarioModificacion,
    };
  }
}
