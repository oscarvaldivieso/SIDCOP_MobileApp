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
    return DevolucionDetalleModel(
      devD_Id: json['devD_Id'] as int,
      devo_Id: json['devo_Id'] as int,
      prod_Id: json['prod_Id'] as int,
      cate_Descripcion: json['cate_Descripcion'] as String? ?? 'Sin categoría',
      prod_Descripcion:
          json['prod_Descripcion'] as String? ?? 'Producto sin nombre',
      prod_DescripcionCorta: json['prod_DescripcionCorta'] as String? ?? '',
      secuencia: json['secuencia'] as int? ?? 0,
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
