class DevolucionDetalleModel {
  final int devD_Id;
  final int devo_Id;
  final int prod_Id;
  final String cate_Descripcion;
  final String prod_Descripcion;
  final String prod_DescripcionCorta;
  final int secuencia;

  DevolucionDetalleModel({
    required this.devD_Id,
    required this.devo_Id,
    required this.prod_Id,
    required this.cate_Descripcion,
    required this.prod_Descripcion,
    required this.prod_DescripcionCorta,
    required this.secuencia,
  });

  factory DevolucionDetalleModel.fromJson(Map<String, dynamic> json) {
    // Función auxiliar para manejar campos enteros con más robustez
    int parseIntSafely(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        try {
          return int.parse(value);
        } catch (e) {
          return defaultValue;
        }
      }
      if (value is double) return value.toInt();
      return defaultValue;
    }

    // Función auxiliar para manejar campos de texto con más robustez
    String parseStringSafely(dynamic value, String defaultValue) {
      if (value == null) return defaultValue;
      return value.toString();
    }

    // Normalizar nombres de campos para mayor compatibilidad
    Map<String, dynamic> normalizedJson = Map.from(json);

    // Para cada campo, intentar variaciones del nombre
    // Por ejemplo, si no existe 'devD_Id', buscar 'devDId' o 'devd_id'
    [
      ['devD_Id', 'devDId', 'DevD_Id', 'devd_id'],
      ['devo_Id', 'devoId', 'Devo_Id', 'devo_id'],
      ['prod_Id', 'prodId', 'Prod_Id', 'prod_id'],
      [
        'cate_Descripcion',
        'cateDescripcion',
        'categoriaDescripcion',
        'categoria',
      ],
      [
        'prod_Descripcion',
        'prodDescripcion',
        'descripcionProducto',
        'producto',
      ],
      [
        'prod_DescripcionCorta',
        'prodDescripcionCorta',
        'descripcionCorta',
        'resumen',
      ],
      ['secuencia', 'Secuencia', 'orden', 'orden_item'],
    ].forEach((variants) {
      String primaryKey = variants[0];
      if (!normalizedJson.containsKey(primaryKey)) {
        for (int i = 1; i < variants.length; i++) {
          if (json.containsKey(variants[i])) {
            normalizedJson[primaryKey] = json[variants[i]];
            break;
          }
        }
      }
    });

    // Parsear los valores con manejo de errores
    return DevolucionDetalleModel(
      devD_Id: parseIntSafely(normalizedJson['devD_Id'], 0),
      devo_Id: parseIntSafely(normalizedJson['devo_Id'], 0),
      prod_Id: parseIntSafely(normalizedJson['prod_Id'], 0),
      cate_Descripcion: parseStringSafely(
        normalizedJson['cate_Descripcion'],
        'Sin categoría',
      ),
      prod_Descripcion: parseStringSafely(
        normalizedJson['prod_Descripcion'],
        'Producto sin nombre',
      ),
      prod_DescripcionCorta: parseStringSafely(
        normalizedJson['prod_DescripcionCorta'],
        '',
      ),
      secuencia: parseIntSafely(normalizedJson['secuencia'], 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'devD_Id': devD_Id,
      'devo_Id': devo_Id,
      'prod_Id': prod_Id,
      'cate_Descripcion': cate_Descripcion,
      'prod_Descripcion': prod_Descripcion,
      'prod_DescripcionCorta': prod_DescripcionCorta,
      'secuencia': secuencia,
    };
  }
}
