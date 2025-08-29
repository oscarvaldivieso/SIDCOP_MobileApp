// lib/models/producto_descuento_model.dart

import 'dart:convert';

class ProductoConDescuento {
  final int prodId;
  final String prodDescripcionCorta;
  final String? prodImagen;
  final int impuId;
  final double impuValor;
  final double prodPrecioUnitario;
  final double prodCostoTotal;
  final String prodPagaImpuesto;
  final int cantidadDisponible;
  final bool prod_Impulsado;
  final List<ListaPrecio> listasPrecio;
  final List<DescuentoEscala> descuentosEscala;

  ProductoConDescuento({
    required this.prodId,
    required this.prodDescripcionCorta,
    this.prodImagen,
    required this.impuId,
    required this.impuValor,
    required this.prodPrecioUnitario,
    required this.prodCostoTotal,
    required this.prodPagaImpuesto,
    required this.cantidadDisponible,
    this.prod_Impulsado = false,
    required this.listasPrecio,
    required this.descuentosEscala,
  });

  factory ProductoConDescuento.fromJson(Map<String, dynamic> json) {
    return ProductoConDescuento(
      prodId: json['prod_Id'] as int,
      prodDescripcionCorta: json['prod_DescripcionCorta'] as String? ?? '',
      prodImagen: json['prod_Imagen'] as String?,
      impuId: json['impu_Id'] as int,
      impuValor: (json['impu_Valor'] as num).toDouble(),
      prodPrecioUnitario: (json['prod_PrecioUnitario'] as num).toDouble(),
      prodCostoTotal: (json['prod_CostoTotal'] as num).toDouble(),
      prodPagaImpuesto: json['prod_PagaImpuesto'] as String,
      prod_Impulsado: json['prod_Impulsado'] as bool? ?? false,
      cantidadDisponible: json['cantidadDisponible'] as int,
      listasPrecio: json['listasPrecio_JSON'] != null 
          ? List<ListaPrecio>.from(
              (jsonDecode(json['listasPrecio_JSON']) as List)
                  .map((x) => ListaPrecio.fromJson(x)))
          : <ListaPrecio>[],
      descuentosEscala: json['descuentosEscala_JSON'] != null 
          ? List<DescuentoEscala>.from(
              (jsonDecode(json['descuentosEscala_JSON']) as List)
                  .map((x) => DescuentoEscala.fromJson(x)))
          : <DescuentoEscala>[],
    );
  }
}

class ListaPrecio {
  final int prePListaPrecios;
  final double prePPrecioContado;
  final double prePPrecioCredito;
  final int prePInicioEscala;
  final int prePFinEscala;

  ListaPrecio({
    required this.prePListaPrecios,
    required this.prePPrecioContado,
    required this.prePPrecioCredito,
    required this.prePInicioEscala,
    required this.prePFinEscala,
  });

  factory ListaPrecio.fromJson(Map<String, dynamic> json) {
    return ListaPrecio(
      prePListaPrecios: json['PreP_ListaPrecios'] as int,
      prePPrecioContado: (json['PreP_PrecioContado'] as num).toDouble(),
      prePPrecioCredito: (json['PreP_PrecioCredito'] as num).toDouble(),
      prePInicioEscala: json['PreP_InicioEscala'] as int,
      prePFinEscala: json['PreP_FinEscala'] as int,
    );
  }
}

class DescuentoEscala {
  final int deEsInicioEscala;
  final int deEsFinEscala;
  final double deEsValor;

  DescuentoEscala({
    required this.deEsInicioEscala,
    required this.deEsFinEscala,
    required this.deEsValor,
  });

  factory DescuentoEscala.fromJson(Map<String, dynamic> json) {
    return DescuentoEscala(
      deEsInicioEscala: json['DeEs_InicioEscala'] as int,
      deEsFinEscala: json['DeEs_FinEscala'] as int,
      deEsValor: (json['DeEs_Valor'] as num).toDouble(),
    );
  }
}