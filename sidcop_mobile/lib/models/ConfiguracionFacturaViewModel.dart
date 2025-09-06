class ConfiguracionFacturaViewModel {
    final int? coFa_Id;
    final String? coFa_NombreEmpresa;
    final String? coFa_DireccionEmpresa;
    final String? coFa_RTN;
    final String? coFa_Correo;
    final String? coFa_Telefono1;
    final String? coFa_Telefono2;
    final String? coFa_Logo;
    final String? colo_Descripcion;
    final String? muni_Descripcion;
    final String? depa_Descripcion;

  ConfiguracionFacturaViewModel({
    this.coFa_Id,
    this.coFa_NombreEmpresa,
    this.coFa_DireccionEmpresa,
    this.coFa_RTN,
    this.coFa_Correo,
    this.coFa_Telefono1,
    this.coFa_Telefono2,
    this.coFa_Logo,
    this.colo_Descripcion,
    this.muni_Descripcion,
    this.depa_Descripcion,
  });

  factory ConfiguracionFacturaViewModel.fromJson(Map<String, dynamic> json) {
    return ConfiguracionFacturaViewModel(
      coFa_Id: json['coFa_Id'],
      coFa_NombreEmpresa: json['coFa_NombreEmpresa'],
      coFa_DireccionEmpresa: json['coFa_DireccionEmpresa'],
      coFa_RTN: json['coFa_RTN'],
      coFa_Correo: json['coFa_Correo'],
      coFa_Telefono1: json['coFa_Telefono1'],
      coFa_Telefono2: json['coFa_Telefono2'],
      coFa_Logo: json['coFa_Logo'],
      colo_Descripcion: json['colo_Descripcion'],
      muni_Descripcion: json['muni_Descripcion'],
      depa_Descripcion: json['depa_Descripcion'],
    );
  }



  Map<String, dynamic> toJson() {
    return {
      'coFa_Id': coFa_Id,
      'coFa_NombreEmpresa': coFa_NombreEmpresa,
      'coFa_DireccionEmpresa': coFa_DireccionEmpresa,
      'coFa_RTN': coFa_RTN,
      'coFa_Correo': coFa_Correo,
      'coFa_Telefono1': coFa_Telefono1,
      'coFa_Telefono2': coFa_Telefono2,
      'coFa_Logo': coFa_Logo,
      'colo_Descripcion': colo_Descripcion,
      'muni_Descripcion': muni_Descripcion,
      'depa_Descripcion': depa_Descripcion,
    };
  }
}