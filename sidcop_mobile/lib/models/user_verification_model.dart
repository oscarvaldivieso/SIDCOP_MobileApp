class UserVerificationResponse {
  final int code;
  final bool success;
  final String message;
  final List<UserVerificationModel> data;

  UserVerificationResponse({
    required this.code,
    required this.success,
    required this.message,
    required this.data,
  });

  factory UserVerificationResponse.fromJson(Map<String, dynamic> json) {
    return UserVerificationResponse(
      code: json['code'] ?? 0,
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: (json['data'] as List?)
          ?.map((item) => UserVerificationModel.fromJson(item))
          .toList() ?? [],
    );
  }
}

class UserVerificationModel {
  final int usuaId;
  final String? usuaUsuario;
  final String? correo;
  final String? usuaClave;
  final int roleId;
  final int usuaIdPersona;
  final bool usuaEsVendedor;
  final bool usuaEsAdmin;
  final String? usuaImagen;
  final int usuaCreacion;
  final DateTime? usuaFechaCreacion;
  final int? usuaModificacion;
  final DateTime? usuaFechaModificacion;
  final bool usuaEstado;
  final String? permisosJson;
  final String? nombreCompleto;

  UserVerificationModel({
    required this.usuaId,
    this.usuaUsuario,
    this.correo,
    this.usuaClave,
    required this.roleId,
    required this.usuaIdPersona,
    required this.usuaEsVendedor,
    required this.usuaEsAdmin,
    this.usuaImagen,
    required this.usuaCreacion,
    this.usuaFechaCreacion,
    this.usuaModificacion,
    this.usuaFechaModificacion,
    required this.usuaEstado,
    this.permisosJson,
    this.nombreCompleto,
  });

  factory UserVerificationModel.fromJson(Map<String, dynamic> json) {
    return UserVerificationModel(
      usuaId: json['usua_Id'] ?? 0,
      usuaUsuario: json['usua_Usuario'],
      correo: json['correo'],
      usuaClave: json['usua_Clave'],
      roleId: json['role_Id'] ?? 0,
      usuaIdPersona: json['usua_IdPersona'] ?? 0,
      usuaEsVendedor: json['usua_EsVendedor'] ?? false,
      usuaEsAdmin: json['usua_EsAdmin'] ?? false,
      usuaImagen: json['usua_Imagen'],
      usuaCreacion: json['usua_Creacion'] ?? 0,
      usuaFechaCreacion: json['usua_FechaCreacion'] != null && 
                         json['usua_FechaCreacion'].toString().isNotEmpty
          ? DateTime.tryParse(json['usua_FechaCreacion']) 
          : null,
      usuaModificacion: json['usua_Modificacion'],
      usuaFechaModificacion: json['usua_FechaModificacion'] != null && 
                            json['usua_FechaModificacion'].toString().isNotEmpty
          ? DateTime.tryParse(json['usua_FechaModificacion'])
          : null,
      usuaEstado: json['usua_Estado'] ?? false,
      permisosJson: json['permisosJson'],
      nombreCompleto: json['nombreCompleto'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'usua_Id': usuaId,
      'usua_Usuario': usuaUsuario,
      'correo': correo,
      'usua_Clave': usuaClave,
      'role_Id': roleId,
      'usua_IdPersona': usuaIdPersona,
      'usua_EsVendedor': usuaEsVendedor,
      'usua_EsAdmin': usuaEsAdmin,
      'usua_Imagen': usuaImagen,
      'usua_Creacion': usuaCreacion,
      'usua_FechaCreacion': usuaFechaCreacion?.toIso8601String(),
      'usua_Modificacion': usuaModificacion,
      'usua_FechaModificacion': usuaFechaModificacion?.toIso8601String(),
      'usua_Estado': usuaEstado,
      'permisosJson': permisosJson,
    };
  }
}
