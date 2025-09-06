// Modelo generado para mapear la respuesta JSON de visitas por vendedor
class VisitasViewModel {
	final int? clVi_Id;
	final int? diCl_Id;
	final double? diCl_Latitud;
	final double? diCl_Longitud;
	final int? vend_Id;
	final String? vend_Codigo;
	final String? vend_DNI;
	final String? vend_Nombres;
	final String? vend_Apellidos;
	final String? vend_Telefono;
	final String? vend_Tipo;
	final String? vend_Imagen;
	final int? ruta_Id;
	final String? ruta_Descripcion;
	final int? veRu_Id;
	final String? veRu_Dias;
	final int? clie_Id;
	final String? clie_Codigo;
	final String? clie_Nombres;
	final String? clie_Apellidos;
	final String? clie_NombreNegocio;
	final String? imVi_Imagen;
	final String? clie_Telefono;
	final int? esVi_Id;
	final String? esVi_Descripcion;
	final String? clVi_Observaciones;
	final DateTime? clVi_Fecha;
	final int? usua_Creacion;
	final DateTime? clVi_FechaCreacion;

	VisitasViewModel({
		this.clVi_Id,
		this.diCl_Id,
		this.diCl_Latitud,
		this.diCl_Longitud,
		this.vend_Id,
		this.vend_Codigo,
		this.vend_DNI,
		this.vend_Nombres,
		this.vend_Apellidos,
		this.vend_Telefono,
		this.vend_Tipo,
		this.vend_Imagen,
		this.ruta_Id,
		this.ruta_Descripcion,
		this.veRu_Id,
		this.veRu_Dias,
		this.clie_Id,
		this.clie_Codigo,
		this.clie_Nombres,
		this.clie_Apellidos,
		this.clie_NombreNegocio,
		this.imVi_Imagen,
		this.clie_Telefono,
		this.esVi_Id,
		this.esVi_Descripcion,
		this.clVi_Observaciones,
		this.clVi_Fecha,
		this.usua_Creacion,
		this.clVi_FechaCreacion,
	});

	factory VisitasViewModel.fromJson(Map<String, dynamic> json) {
		DateTime? parseDate(String? s) {
			if (s == null) return null;
			try {
				return DateTime.parse(s);
			} catch (_) {
				return null;
			}
		}

		double? parseDouble(dynamic v) {
			if (v == null) return null;
			if (v is double) return v;
			if (v is int) return v.toDouble();
			if (v is String) return double.tryParse(v);
			return null;
		}

		return VisitasViewModel(
			clVi_Id: json['clVi_Id'] as int?,
			diCl_Id: json['diCl_Id'] as int?,
			diCl_Latitud: parseDouble(json['diCl_Latitud']),
			diCl_Longitud: parseDouble(json['diCl_Longitud']),
			vend_Id: json['vend_Id'] as int?,
			vend_Codigo: json['vend_Codigo'] as String?,
			vend_DNI: json['vend_DNI'] as String?,
			vend_Nombres: json['vend_Nombres'] as String?,
			vend_Apellidos: json['vend_Apellidos'] as String?,
			vend_Telefono: json['vend_Telefono'] as String?,
			vend_Tipo: json['vend_Tipo'] as String?,
			vend_Imagen: json['vend_Imagen'] as String?,
			ruta_Id: json['ruta_Id'] as int?,
			ruta_Descripcion: json['ruta_Descripcion'] as String?,
			veRu_Id: json['veRu_Id'] as int?,
			veRu_Dias: json['veRu_Dias'] as String?,
			clie_Id: json['clie_Id'] as int?,
			clie_Codigo: json['clie_Codigo'] as String?,
			clie_Nombres: json['clie_Nombres'] as String?,
			clie_Apellidos: json['clie_Apellidos'] as String?,
			clie_NombreNegocio: json['clie_NombreNegocio'] as String?,
			imVi_Imagen: json['imVi_Imagen'] as String?,
			clie_Telefono: json['clie_Telefono'] as String?,
			esVi_Id: json['esVi_Id'] as int?,
			esVi_Descripcion: json['esVi_Descripcion'] as String?,
			clVi_Observaciones: json['clVi_Observaciones'] as String?,
			clVi_Fecha: parseDate(json['clVi_Fecha'] as String?),
			usua_Creacion: json['usua_Creacion'] as int?,
			clVi_FechaCreacion: parseDate(json['clVi_FechaCreacion'] as String?),
		);
	}

	Map<String, dynamic> toJson() {
		String? dateToString(DateTime? d) => d?.toIso8601String();

		return {
			'clVi_Id': clVi_Id,
			'diCl_Id': diCl_Id,
			'diCl_Latitud': diCl_Latitud,
			'diCl_Longitud': diCl_Longitud,
			'vend_Id': vend_Id,
			'vend_Codigo': vend_Codigo,
			'vend_DNI': vend_DNI,
			'vend_Nombres': vend_Nombres,
			'vend_Apellidos': vend_Apellidos,
			'vend_Telefono': vend_Telefono,
			'vend_Tipo': vend_Tipo,
			'vend_Imagen': vend_Imagen,
			'ruta_Id': ruta_Id,
			'ruta_Descripcion': ruta_Descripcion,
			'veRu_Id': veRu_Id,
			'veRu_Dias': veRu_Dias,
			'clie_Id': clie_Id,
			'clie_Codigo': clie_Codigo,
			'clie_Nombres': clie_Nombres,
			'clie_Apellidos': clie_Apellidos,
			'clie_NombreNegocio': clie_NombreNegocio,
			'imVi_Imagen': imVi_Imagen,
			'clie_Telefono': clie_Telefono,
			'esVi_Id': esVi_Id,
			'esVi_Descripcion': esVi_Descripcion,
			'clVi_Observaciones': clVi_Observaciones,
			'clVi_Fecha': dateToString(clVi_Fecha),
			'usua_Creacion': usua_Creacion,
			'clVi_FechaCreacion': dateToString(clVi_FechaCreacion),
		};
	}
}

