class NumeroEnLetras {
  static final List<String> _unidades = [
    '', 'UNO', 'DOS', 'TRES', 'CUATRO', 'CINCO', 'SEIS', 'SIETE', 'OCHO', 'NUEVE',
    'DIEZ', 'ONCE', 'DOCE', 'TRECE', 'CATORCE', 'QUINCE', 'DIECISÉIS', 'DIECISIETE', 'DIECIOCHO', 'DIECINUEVE', 'VEINTE'
  ];
  static final List<String> _decenas = [
    '', '', 'VEINTI', 'TREINTA', 'CUARENTA', 'CINCUENTA', 'SESENTA', 'SETENTA', 'OCHENTA', 'NOVENTA'
  ];
  static final List<String> _centenas = [
    '', 'CIENTO', 'DOSCIENTOS', 'TRESCIENTOS', 'CUATROCIENTOS', 'QUINIENTOS', 'SEISCIENTOS', 'SETECIENTOS', 'OCHOCIENTOS', 'NOVECIENTOS'
  ];

  static String convertir(num numero) {
    if (numero == 0) return 'CERO';
    if (numero < 0) return 'MENOS ${convertir(-numero)}';
    if (numero > 999999999) return numero.toString();

    int parteEntera = numero.floor();
    int parteDecimal = ((numero - parteEntera) * 100).round();
    
    String letrasEnteras = _convertirEntero(parteEntera);
    String letrasDecimales = '';
    
    // Convertir decimales a letras
    if (parteDecimal > 0) {
      String decimalesStr = _convertirEntero(parteDecimal);
      letrasDecimales = ' CON $decimalesStr CENTAVOS';
    }

    // Unir la parte entera y la decimal y convertir a mayúsculas
    return '$letrasEnteras$letrasDecimales'.toUpperCase();
  }

  static String _convertirEntero(int numero) {
    if (numero < 21) {
      return _unidades[numero];
    } else if (numero < 30) {
      int unidad = numero % 10;
      return 'VEINTI${_unidades[unidad]}';
    } else if (numero < 100) {
      int decena = numero ~/ 10;
      int unidad = numero % 10;
      return _decenas[decena] + (unidad > 0 ? ' Y ${_unidades[unidad]}' : '');
    } else if (numero < 1000) {
      if (numero == 100) return 'CIEN';
      int centena = numero ~/ 100;
      int resto = numero % 100;
      return _centenas[centena] + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    } else if (numero < 1000000) {
      int miles = numero ~/ 1000;
      int resto = numero % 1000;
      String milesStr = miles == 1 ? 'MIL' : '${_convertirEntero(miles)} MIL';
      return milesStr + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    } else {
      int millones = numero ~/ 1000000;
      int resto = numero % 1000000;
      String millonesStr = millones == 1 ? 'UN MILLÓN' : '${_convertirEntero(millones)} MILLONES';
      return millonesStr + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    }
  }
}