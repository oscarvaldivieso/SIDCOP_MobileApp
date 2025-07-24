
class Cliente {

  final int clie_Id ;
  final String? clie_Codigo;
  final String? clie_DNI;
  final String? clie_RTN;
  final String? clie_Nombres;
  final String? clie_Apellidos;
  final String? clie_NombreNegocio;
  final String? clie_ImagenDelNegocio;
  final String? clie_DireccionExacta;
  final String? clie_Telefono;
  final String? clie_Correo;
  final String? clie_Sexo;
  final DateTime clie_FechaNacimiento ;
  final int cana_Id ;
  final int colo_Id ;
  final int esCv_Id ;
  final double clie_Latitud ;
  final double clie_Longitud ;
  final int ruta_Id ;
  final double clie_LimiteCredito ;
  final int clie_DiasCredito ;
  final double clie_Saldo ;
  final bool clie_Vencido = true;
  final String? clie_Observaciones;
  final String? clie_ObservacionRetiro;
  final bool clie_Confirmacion = true;
  final int TiVi_Id;
  final String? Clie_Nacionalidad;
  final int usua_Creacion ;
  final DateTime clie_FechaCreacion ;
  final int usua_Modificacion ;
  final DateTime clie_FechaModificacion ;
  final bool clie_Estado = true;
  final String? usuarioCreacion;
  final String? usuarioModificacion;
  final String? cana_Descripcion;
  final String? colo_Descripcion;
  final String? esCv_Descripcion;
  final String? ruta_Descripcion;

  Cliente({
    required this.clie_Id,
    required this.clie_Codigo,
    required this.clie_DNI,
    required this.clie_RTN,
    required this.clie_Nombres,
    required this.clie_Apellidos,
    required this.clie_NombreNegocio,
    required this.clie_ImagenDelNegocio,
    required this.clie_DireccionExacta,
    required this.clie_Telefono,
    required this.clie_Correo,
    required this.clie_Sexo,
    required this.clie_FechaNacimiento,
    required this.cana_Id,
    required this.colo_Id,
    required this.esCv_Id,
    required this.clie_Latitud,
    required this.clie_Longitud,
    required this.ruta_Id,
    required this.clie_LimiteCredito,
    required this.clie_DiasCredito,
    required this.clie_Saldo,
    required this.clie_Vencido,
    required this.clie_Observaciones,
    required this.clie_ObservacionRetiro,
    required this.clie_Confirmacion,
    this.TiVi_Id = 1,
    this.Clie_Nacionalidad = 'pdt',
    required this.usua_Creacion,
    required this.clie_FechaCreacion,
    required this.usua_Modificacion,
    required this.clie_FechaModificacion,
    required this.clie_Estado,
  });

  Map<String, dynamic> toJson() {
    return {
      "clie_Id": clie_Id,
      "clie_Codigo": clie_Codigo,
      "clie_DNI": clie_DNI,
      "clie_RTN": clie_RTN,
      "clie_Nombres": clie_Nombres,
      "clie_Apellidos": clie_Apellidos,
      "clie_NombreNegocio": clie_NombreNegocio,
      "clie_ImagenDelNegocio": clie_ImagenDelNegocio,
      "clie_DireccionExacta": clie_DireccionExacta,
      "clie_Telefono": clie_Telefono,
      "clie_Correo": clie_Correo,
      "clie_Sexo": clie_Sexo,
      "clie_FechaNacimiento": clie_FechaNacimiento.toUtc().toIso8601String?(),
      "cana_Id": cana_Id,
      "colo_Id": colo_Id,
      "esCv_Id": esCv_Id,
      "clie_Latitud": clie_Latitud,
      "clie_Longitud": clie_Longitud,
      "ruta_Id": ruta_Id,
      "clie_LimiteCredito": clie_LimiteCredito,
      "clie_DiasCredito": clie_DiasCredito,
      "clie_Saldo": clie_Saldo,
      "clie_Vencido": clie_Vencido,
      "clie_Observaciones": clie_Observaciones,
      "clie_ObservacionRetiro": clie_ObservacionRetiro,
      "clie_Confirmacion": clie_Confirmacion,
      "TiVi_Id": TiVi_Id,
      "Clie_Nacionalidad": Clie_Nacionalidad,
      "usua_Creacion": usua_Creacion,
      "clie_FechaCreacion": clie_FechaCreacion.toUtc().toIso8601String?(),
      "usua_Modificacion": usua_Modificacion,
      "clie_FechaModificacion": clie_FechaModificacion.toUtc().toIso8601String?(),
      "clie_Estado": clie_Estado,
      "usuarioCreacion": usuarioCreacion,
      "usuarioModificacion": usuarioModificacion,
      "cana_Descripcion": cana_Descripcion,
      "colo_Descripcion": colo_Descripcion,
      "esCv_Descripcion": esCv_Descripcion,
      "ruta_Descripcion": ruta_Descripcion,
    };
  }

  factory Cliente.fromJson(Map<String?, dynamic> json) {
    return Cliente(
      clie_Id: json['clie_Id'],
      clie_Codigo: json['clie_Codigo'],
      clie_DNI: json['clie_DNI'],
      clie_RTN: json['clie_RTN'],
      clie_Nombres: json['clie_Nombres'],
      clie_Apellidos: json['clie_Apellidos'],
      clie_NombreNegocio: json['clie_NombreNegocio'],
      clie_ImagenDelNegocio: json['clie_ImagenDelNegocio'],
      clie_DireccionExacta: json['clie_DireccionExacta'],
      clie_Telefono: json['clie_Telefono'],
      clie_Correo: json['clie_Correo'],
      clie_Sexo: json['clie_Sexo'],
      clie_FechaNacimiento: DateTime.parse(json['clie_FechaNacimiento']),
      cana_Id: json['cana_Id'],
      colo_Id: json['colo_Id'],
      esCv_Id: json['esCv_Id'],
      clie_Latitud: json['clie_Latitud'],
      clie_Longitud: json['clie_Longitud'],
      ruta_Id: json['ruta_Id'],
      clie_LimiteCredito: json['clie_LimiteCredito'],
      clie_DiasCredito: json['clie_DiasCredito'],
      clie_Saldo: json['clie_Saldo'],
      clie_Vencido: json['clie_Vencido'],
      clie_Observaciones: json['clie_Observaciones'],
      clie_ObservacionRetiro: json['clie_ObservacionRetiro'],
      clie_Confirmacion: json['clie_Confirmacion'] ?? true,
      TiVi_Id: json['TiVi_Id'] ?? 1,
      Clie_Nacionalidad: json['Clie_Nacionalidad'] ?? 'pdt',
      usua_Creacion: json['usua_Creacion'],
      clie_FechaCreacion: json['clie_FechaCreacion'] != null ? DateTime.parse(json['clie_FechaCreacion']) : DateTime.now(),
      usua_Modificacion: json['usua_Modificacion'] ?? 0,
      clie_FechaModificacion: json['clie_FechaModificacion'] != null ? DateTime.parse(json['clie_FechaModificacion']) : DateTime.now(),
      clie_Estado: json['clie_Estado'] ?? true,
      usuarioCreacion: json['usuarioCreacion'],
      usuarioModificacion: json['usuarioModificacion'],
      cana_Descripcion: json['cana_Descripcion'],
      colo_Descripcion: json['colo_Descripcion'],
      esCv_Descripcion: json['esCv_Descripcion'],
      ruta_Descripcion: json['ruta_Descripcion'],
    };
  }



