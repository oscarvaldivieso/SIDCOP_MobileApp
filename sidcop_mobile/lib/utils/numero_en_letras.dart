class NumeroEnLetras {
  static final List<String> _unidades = [
    '', 'uno', 'dos', 'tres', 'cuatro', 'cinco', 'seis', 'siete', 'ocho', 'nueve',
    'diez', 'once', 'doce', 'trece', 'catorce', 'quince', 'dieciséis', 'diecisiete', 'dieciocho', 'diecinueve', 'veinte'
  ];
  static final List<String> _decenas = [
    '', '', 'veinte', 'treinta', 'cuarenta', 'cincuenta', 'sesenta', 'setenta', 'ochenta', 'noventa'
  ];
  static final List<String> _centenas = [
    '', 'ciento', 'doscientos', 'trescientos', 'cuatrocientos', 'quinientos', 'seiscientos', 'setecientos', 'ochocientos', 'novecientos'
  ];

  static String convertir(num numero) {
    if (numero == 0) return 'cero';
    if (numero < 0) return 'menos ${convertir(-numero)}';
    if (numero > 999999999) return numero.toString(); // fuera de rango
    int parteEntera = numero.floor();
    int parteDecimal = ((numero - parteEntera) * 100).round();
    String letras = _convertirEntero(parteEntera);
    if (parteDecimal > 0) {
      letras += ' con ${parteDecimal.toString().padLeft(2, '0')}/100';
    }
    return letras;
  }

  static String _convertirEntero(int numero) {
    if (numero < 21) {
      return _unidades[numero];
    } else if (numero < 100) {
      int decena = numero ~/ 10;
      int unidad = numero % 10;
      return _decenas[decena] + (unidad > 0 ? ' y ${_unidades[unidad]}' : '');
    } else if (numero < 1000) {
      if (numero == 100) return 'cien';
      int centena = numero ~/ 100;
      int resto = numero % 100;
      return _centenas[centena] + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    } else if (numero < 1000000) {
      int miles = numero ~/ 1000;
      int resto = numero % 1000;
      String milesStr = miles == 1 ? 'mil' : '${_convertirEntero(miles)} mil';
      return milesStr + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    } else {
      int millones = numero ~/ 1000000;
      int resto = numero % 1000000;
      String millonesStr = millones == 1 ? 'un millón' : '${_convertirEntero(millones)} millones';
      return millonesStr + (resto > 0 ? ' ${_convertirEntero(resto)}' : '');
    }
  }
}
