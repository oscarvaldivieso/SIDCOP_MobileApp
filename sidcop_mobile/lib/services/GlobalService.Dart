import 'package:http/http.dart' as http;

int? globalVendId; // usua_IdPersona del vendedor autenticado

//const String apiServer = 'http://sidcop.somee.com';
// const String apiServer = 'http://200.59.27.115:8091';
//const String apiServer = 'http://sidcop.somee.com';
// const String apiServer = 'https://localhost:7071';
const String apiServer = 'http://200.59.27.115:8091'; 
//const String apiServer = 'http://192.168.1.146:8091'; 
const String apikey = 'bdccf3f3-d486-4e1e-ab44-74081aefcdbc';
const String mapApikey = 'AIzaSyA6bbij1_4crYsWVg6E1PnqGb17lNGdIjA';

Future<bool> verificarConexionGlobal() async {
  try {
    final response = await http.get(
      Uri.parse('https://www.google.com'),
      headers: {'Connection': 'close'},
    ).timeout(const Duration(seconds: 10));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}
