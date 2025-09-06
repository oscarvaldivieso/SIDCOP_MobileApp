class PedidosViewModel {
  final String? coFaNombreEmpresa;
  final String? coFaDireccionEmpresa;
  final String? coFaRTN;
  final String? coFaCorreo;
  final String? coFaTelefono1;
  final String? coFaTelefono2;
  final String? coFaLogo;
  final int? secuencia;
  final int pediId;
  final int diClId;
  final int vendId;
  final DateTime pediFechaPedido;
  final DateTime? pediFechaEntrega;
  final String? pedi_Codigo;
  final int usuaCreacion;
  final DateTime pediFechaCreacion;
  final int? usuaModificacion;
  final DateTime? pediFechaModificacion;
  final bool pediEstado;
  final String? clieCodigo;
  final int? clieId;
  final String? clieNombreNegocio;
  final String? clieNombres;
  final String? clieApellidos;
  final String? coloDescripcion;
  final String? muniDescripcion;
  final String? depaDescripcion;
  final String? diClDireccionExacta;
  final String? vendNombres;
  final String? vendApellidos;
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final String? prodCodigo;
  final String? prodDescripcion;
  final double? peDeProdPrecio;
  final int? peDeCantidad;
  final List<dynamic> detalles;
  final String? detallesJson;

  PedidosViewModel({
    this.coFaNombreEmpresa,
    this.coFaDireccionEmpresa,
    this.coFaRTN,
    this.coFaCorreo,
    this.coFaTelefono1,
    this.coFaTelefono2,
    this.coFaLogo,
    this.secuencia,
    required this.pediId,
    required this.diClId,
    required this.vendId,
    required this.pediFechaPedido,
    this.pediFechaEntrega,
    this.pedi_Codigo,
    required this.usuaCreacion,
    required this.pediFechaCreacion,
    this.usuaModificacion,
    this.pediFechaModificacion,
    required this.pediEstado,
    this.clieCodigo,
    this.clieId,
    this.clieNombreNegocio,
    this.clieNombres,
    this.clieApellidos,
    this.coloDescripcion,
    this.muniDescripcion,
    this.depaDescripcion,
    this.diClDireccionExacta,
    this.vendNombres,
    this.vendApellidos,
    this.usuarioCreacion,
    this.usuarioModificacion,
    this.prodCodigo,
    this.prodDescripcion,
    this.peDeProdPrecio,
    this.peDeCantidad,
    required this.detalles,
    this.detallesJson,
  });

  factory PedidosViewModel.fromJson(Map<String, dynamic> json) {
    return PedidosViewModel(
      coFaNombreEmpresa: json['coFa_NombreEmpresa'],
      coFaDireccionEmpresa: json['coFa_DireccionEmpresa'],
      coFaRTN: json['coFa_RTN'],
      coFaCorreo: json['coFa_Correo'],
      coFaTelefono1: json['coFa_Telefono1'],
      coFaTelefono2: json['coFa_Telefono2'],
      coFaLogo: json['coFa_Logo'],
      secuencia: json['secuencia'],
      pediId: json['pedi_Id'],
      diClId: json['diCl_Id'],
      vendId: json['vend_Id'],
      pediFechaPedido: DateTime.parse(json['pedi_FechaPedido']),
      pediFechaEntrega: json['pedi_FechaEntrega'] != null ? DateTime.parse(json['pedi_FechaEntrega']) : null,
      pedi_Codigo: json['pedi_Codigo'],
      usuaCreacion: json['usua_Creacion'],
      pediFechaCreacion: DateTime.parse(json['pedi_FechaCreacion']),
      usuaModificacion: json['usua_Modificacion'],
      pediFechaModificacion: json['pedi_FechaModificacion'] != null ? DateTime.parse(json['pedi_FechaModificacion']) : null,
      pediEstado: json['pedi_Estado'],
      clieCodigo: json['clie_Codigo'],
      clieId: json['clie_Id'],
      clieNombreNegocio: json['clie_NombreNegocio'],
      clieNombres: json['clie_Nombres'],
      clieApellidos: json['clie_Apellidos'],
      coloDescripcion: json['colo_Descripcion'],
      muniDescripcion: json['muni_Descripcion'],
      depaDescripcion: json['depa_Descripcion'],
      diClDireccionExacta: json['diCl_DireccionExacta'],
      vendNombres: json['vend_Nombres'],
      vendApellidos: json['vend_Apellidos'],
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
      prodCodigo: json['prod_Codigo'],
      prodDescripcion: json['prod_Descripcion'],
      peDeProdPrecio: json['peDe_ProdPrecio'] != null ? (json['peDe_ProdPrecio'] as num).toDouble() : null,
      peDeCantidad: json['peDe_Cantidad'],
      detalles: json['detalles'] ?? [],
      detallesJson: json['detallesJson'],
    );
  }
}