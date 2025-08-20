import 'dart:convert';

class ProductosPedidosViewModel {
  final int prodId;
  final String? prodCodigo;
  final String? prodCodigoBarra;
  final String? prodDescripcion;
  final String? prodDescripcionCorta;
  final String? prodImagen;
  final String? pedi_Codigo;
  final int? subcId;
  final int? marcId;
  final int? provId;
  final int? impuId;
  final num? prodPrecioUnitario;
  final num? prodCostoTotal;
  final bool prod_Impulsado;
  final String? prodPagaImpuesto;
  final String? prodEsPromo;
  final bool prodEstado;
  final int? usuaCreacion;
  final String? prodFechaCreacion;
  final int? usuaModificacion;
  final String? prodFechaModificacion;
  final int? secuencia;
  final int? cateId;
  final String? cateDescripcion;
  final String? marcDescripcion;
  final String? provNombreEmpresa;
  final String? subcDescripcion;
  final String? impuDescripcion;
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final List<dynamic>? clientes;
  final List<dynamic>? productos;
  final List<dynamic>? idClientes;
  final List<ListaPrecioModel>? listasPrecio;
  final List<DescuentoEscalaModel>? descuentosEscala;
  final DescEspecificacionesModel? descEspecificaciones;
  final double? impuValor;
  final List<dynamic>? infoPromocion;

  ProductosPedidosViewModel({
    required this.prodId,
    this.prodCodigo,
    this.prodCodigoBarra,
    this.prodDescripcion,
    this.prodDescripcionCorta,
    this.prodImagen,
    this.pedi_Codigo,
    this.subcId,
    this.marcId,
    this.provId,
    this.impuId,
    this.prodPrecioUnitario,
    this.prodCostoTotal,
    required this.prod_Impulsado,
    this.prodPagaImpuesto,
    this.prodEsPromo,
    required this.prodEstado,
    this.usuaCreacion,
    this.prodFechaCreacion,
    this.usuaModificacion,
    this.prodFechaModificacion,
    this.secuencia,
    this.cateId,
    this.cateDescripcion,
    this.marcDescripcion,
    this.provNombreEmpresa,
    this.subcDescripcion,
    this.impuDescripcion,
    this.usuarioCreacion,
    this.usuarioModificacion,
    this.clientes,
    this.productos,
    this.idClientes,
    this.listasPrecio,
    this.descuentosEscala,
    this.descEspecificaciones,
    this.impuValor,
    this.infoPromocion,
  });

  Map<String, dynamic> toJson() {
    return {
      'prod_Id': prodId,
      'prod_Codigo': prodCodigo,
      'prod_CodigoBarra': prodCodigoBarra,
      'prod_Descripcion': prodDescripcion,
      'prod_DescripcionCorta': prodDescripcionCorta,
      'prod_Imagen': prodImagen,
      'pedi_Codigo': pedi_Codigo,
      'subc_Id': subcId,
      'marc_Id': marcId,
      'prov_Id': provId,
      'impu_Id': impuId,
      'prod_PrecioUnitario': prodPrecioUnitario,
      'prod_CostoTotal': prodCostoTotal,
      'prod_Impulsado': prod_Impulsado,
      'prod_PagaImpuesto': prodPagaImpuesto,
      'prod_EsPromo': prodEsPromo,
      'prod_Estado': prodEstado,
      'usua_Creacion': usuaCreacion,
      'prod_FechaCreacion': prodFechaCreacion,
      'usua_Modificacion': usuaModificacion,
      'prod_FechaModificacion': prodFechaModificacion,
      'secuencia': secuencia,
      'cate_Id': cateId,
      'cate_Descripcion': cateDescripcion,
      'marc_Descripcion': marcDescripcion,
      'prov_NombreEmpresa': provNombreEmpresa,
      'subc_Descripcion': subcDescripcion,
      'impu_Descripcion': impuDescripcion,
      'usuarioCreacion': usuarioCreacion,
      'usuarioModificacion': usuarioModificacion,
      'clientes': clientes,
      'productos': productos,
      'idClientes': idClientes,
      'listasPrecio': listasPrecio,
      'descuentosEscala': descuentosEscala,
      'descEspecificaciones': descEspecificaciones,
      'impu_Valor': impuValor,
      'infoPromocion': infoPromocion,
    };
  }

  factory ProductosPedidosViewModel.fromJson(Map<String, dynamic> json) {
    List<ListaPrecioModel>? listasPrecio;
    if (json['listasPrecio_JSON'] != null && json['listasPrecio_JSON'].toString().isNotEmpty) {
      try {
        final parsed = jsonDecode(json['listasPrecio_JSON']);
        listasPrecio = (parsed as List)
            .map((e) => ListaPrecioModel.fromJson(e))
            .toList();
      } catch (_) {
        listasPrecio = [];
      }
    }

    List<DescuentoEscalaModel>? descuentosEscala;
    if (json['descuentosEscala_JSON'] != null && json['descuentosEscala_JSON'].toString().isNotEmpty) {
      try {
        final parsed = jsonDecode(json['descuentosEscala_JSON']);
        descuentosEscala = (parsed as List)
            .map((e) => DescuentoEscalaModel.fromJson(e))
            .toList();
      } catch (_) {
        descuentosEscala = [];
      }
    }

    DescEspecificacionesModel? descEspecificaciones;
    if (json['desc_EspecificacionesJSON'] != null && json['desc_EspecificacionesJSON'].toString().isNotEmpty) {
      try {
        final parsed = jsonDecode(json['desc_EspecificacionesJSON']);
        descEspecificaciones = DescEspecificacionesModel.fromJson(parsed);
      } catch (_) {
        descEspecificaciones = null;
      }
    }

    List<dynamic>? infoPromocion;
    if (json['infoPromocion_JSON'] != null && json['infoPromocion_JSON'].toString().isNotEmpty) {
      try {
        infoPromocion = jsonDecode(json['infoPromocion_JSON']);
      } catch (_) {
        infoPromocion = null;
      }
    }

    return ProductosPedidosViewModel(
      prodId: json['prod_Id'],
      prodCodigo: json['prod_Codigo'],
      prodCodigoBarra: json['prod_CodigoBarra'],
      prodDescripcion: json['prod_Descripcion'],
      prodDescripcionCorta: json['prod_DescripcionCorta'],
      prodImagen: json['prod_Imagen'],
      pedi_Codigo: json['pedi_Codigo'],
      subcId: json['subc_Id'],
      marcId: json['marc_Id'],
      provId: json['prov_Id'],
      impuId: json['impu_Id'],
      prodPrecioUnitario: json['prod_PrecioUnitario'],
      prodCostoTotal: json['prod_CostoTotal'],
      prod_Impulsado: json['prod_Impulsado'],
      prodPagaImpuesto: json['prod_PagaImpuesto'],
      prodEsPromo: json['prod_EsPromo'],
      prodEstado: json['prod_Estado'] ?? false,
      usuaCreacion: json['usua_Creacion'],
      prodFechaCreacion: json['prod_FechaCreacion'],
      usuaModificacion: json['usua_Modificacion'],
      prodFechaModificacion: json['prod_FechaModificacion'],
      secuencia: json['secuencia'],
      cateId: json['cate_Id'],
      cateDescripcion: json['cate_Descripcion'],
      marcDescripcion: json['marc_Descripcion'],
      provNombreEmpresa: json['prov_NombreEmpresa'],
      subcDescripcion: json['subc_Descripcion'],
      impuDescripcion: json['impu_Descripcion'],
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
      clientes: json['clientes'],
      productos: json['productos'],
      idClientes: json['idClientes'],
      listasPrecio: listasPrecio,
      descuentosEscala: descuentosEscala,
      descEspecificaciones: descEspecificaciones,
      impuValor: json['impu_Valor']?.toDouble(),
      infoPromocion: infoPromocion,
    );
  }
}


class ListaPrecioModel {
  final int prePListaPrecios;
  final double prePPrecioContado;
  final double prePPrecioCredito;
  final int prePInicioEscala;
  final int prePFinEscala;

  ListaPrecioModel({
    required this.prePListaPrecios,
    required this.prePPrecioContado,
    required this.prePPrecioCredito,
    required this.prePInicioEscala,
    required this.prePFinEscala,
  });

  factory ListaPrecioModel.fromJson(Map<String, dynamic> json) {
    return ListaPrecioModel(
      prePListaPrecios: json['PreP_ListaPrecios'],
      prePPrecioContado: (json['PreP_PrecioContado'] as num).toDouble(),
      prePPrecioCredito: (json['PreP_PrecioCredito'] as num).toDouble(),
      prePInicioEscala: json['PreP_InicioEscala'],
      prePFinEscala: json['PreP_FinEscala'],
    );
  }
}

class DescuentoEscalaModel {
  final int deEsInicioEscala;
  final int deEsFinEscala;
  final double deEsValor;

  DescuentoEscalaModel({
    required this.deEsInicioEscala,
    required this.deEsFinEscala,
    required this.deEsValor,
  });

  factory DescuentoEscalaModel.fromJson(Map<String, dynamic> json) {
    return DescuentoEscalaModel(
      deEsInicioEscala: json['DeEs_InicioEscala'],
      deEsFinEscala: json['DeEs_FinEscala'],
      deEsValor: (json['DeEs_Valor'] as num).toDouble(),
    );
  }
}

class DescEspecificacionesModel {
  final int descId;
  final String descAplicar;
  final int descTipo;
  final String descTipoFactura;

  DescEspecificacionesModel({
    required this.descId,
    required this.descAplicar,
    required this.descTipo,
    required this.descTipoFactura,
  });

  factory DescEspecificacionesModel.fromJson(Map<String, dynamic> json) {
    return DescEspecificacionesModel(
      descId: json['Desc_Id'],
      descAplicar: json['Desc_Aplicar'],
      descTipo: json['Desc_Tipo'],
      descTipoFactura: json['Desc_TipoFactura'],
    );
  }
}
