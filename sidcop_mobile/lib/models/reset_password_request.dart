class ResetPasswordRequest {
  final int usua_Id;
  final String usua_Usuario;
  final String role_Descripcion;
  final String correo;
  final String usua_Clave;
  final int role_Id;
  final int usua_IdPersona;
  final bool usua_EsVendedor;
  final bool usua_EsAdmin;
  final String usua_Imagen;
  final int usua_Creacion;
  final DateTime usua_FechaCreacion;
  final int usua_Modificacion;
  final DateTime usua_FechaModificacion;
  final bool usua_Estado;
  final String permisosJson;

  ResetPasswordRequest({
    required this.usua_Id,
    required this.usua_Usuario,
    this.role_Descripcion = ''  ,
    required this.correo,
    required this.usua_Clave,
    this.role_Id = 0,
    this.usua_IdPersona = 0,
    this.usua_EsVendedor = false,
    this.usua_EsAdmin = false,
    this.usua_Imagen = '',
    this.usua_Creacion = 0,
    DateTime? usua_FechaCreacion,
    required this.usua_Modificacion,
    DateTime? usua_FechaModificacion,
    this.usua_Estado = true,
    this.permisosJson = '',
  })  : usua_FechaCreacion = usua_FechaCreacion ?? DateTime.now(),
        usua_FechaModificacion = usua_FechaModificacion ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'usua_Id': usua_Id,
        'usua_Usuario': usua_Usuario,
        'role_Descripcion': role_Descripcion,
        'correo': correo,
        'usua_Clave': usua_Clave,
        'role_Id': role_Id,
        'usua_IdPersona': usua_IdPersona,
        'usua_EsVendedor': usua_EsVendedor,
        'usua_EsAdmin': usua_EsAdmin,
        'usua_Imagen': usua_Imagen,
        'usua_Creacion': usua_Creacion,
        'usua_FechaCreacion': usua_FechaCreacion.toIso8601String(),
        'usua_Modificacion': usua_Modificacion,
        'usua_FechaModificacion': usua_FechaModificacion.toIso8601String(),
        'usua_Estado': usua_Estado,
        'permisosJson': permisosJson,
      };
}
