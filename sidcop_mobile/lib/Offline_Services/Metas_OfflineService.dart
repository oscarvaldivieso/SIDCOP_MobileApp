import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/GoalsService.dart'; // Debes tener este service
import 'package:sidcop_mobile/models/MetasViewModel.dart'; // Debes tener este modelo

class MetasOffline {
  static const String _carpetaOffline = 'offline';
  static const String _archivoMetas = 'metas.json';
  static final FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<Directory> _directorioDocuments() async {
    return await getApplicationDocumentsDirectory();
  }

  static Future<String> _rutaArchivo(String nombreRelativo) async {
    final docs = await _directorioDocuments();
    final ruta = p.join(docs.path, _carpetaOffline, nombreRelativo);
    final dirPadre = Directory(p.dirname(ruta));
    if (!await dirPadre.exists()) {
      await dirPadre.create(recursive: true);
    }
    return ruta;
  }

  ///Aquí se guarda y lee las metas en local (offline)
    static Future<void> guardarMetas(List<Metas> metas) async {
    await _secureStorage.write(
      key: 'json:$_archivoMetas',
      value: jsonEncode(metas.map((m) => m.toJson()).toList()),
    );
  }

  static Future<List<Metas>> cargarMetas() async {
    final s = await _secureStorage.read(key: 'json:$_archivoMetas');
    if (s == null || s.isEmpty) return [];
    try {
      //print('Contenido metas offline: $s');
      final List<dynamic> lista = jsonDecode(s);
      return lista.map((json) => Metas.fromJson(json)).toList();
    } catch (e) {
    //  print('Error parseando metas: $e');
      return [];
    }
  }

  //Sincroniza las metas desde el endpoint
    static Future<List<Metas>> sincronizarMetasPorVendedor(int vendorId) async {
    try {
      final service = GoalsService();
      final data = await service.getGoalsByVendor(vendorId);
      final metas = (data ?? []).map((json) => Metas.fromJson(json)).toList();
      await guardarMetas(metas);
      return metas;
    } catch (e) {
      //print('Error sincronizando metas: $e');
      return [];
    }
  }

  //Obtener metas offline
  static Future<List<Metas>> obtenerMetasLocal() async {
    return await cargarMetas();
  }

}