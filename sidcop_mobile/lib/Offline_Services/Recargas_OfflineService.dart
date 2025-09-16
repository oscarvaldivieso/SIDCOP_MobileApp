import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sidcop_mobile/services/RecargasService.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class RecargasScreenOffline {
  static const String _carpetaOffline = 'offline';
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

  static Future<void> guardarJson(String nombreArchivo, Object objeto) async {
    try {
      final contenido = jsonEncode(objeto);
      final key = 'json:$nombreArchivo';
      await _secureStorage.write(key: key, value: contenido);
    } catch (e) {
      rethrow;
    }
  }

  static Future<dynamic> leerJson(String nombreArchivo) async {
    try {
      final key = 'json:$nombreArchivo';
      final s = await _secureStorage.read(key: key);
      if (s == null) return null;
      return jsonDecode(s);
    } catch (e) {
      rethrow;
    }
  }

  static Future<int> sincronizarPendientes() async {
    final raw = await RecargasScreenOffline.leerJson('recargas_pendientes.json');
    if (raw == null) return 0;
    List<dynamic> pendientes = List.from(raw as List);
    if (pendientes.isEmpty) return 0;
    final recargaService = RecargasService();
    int sincronizadas = 0;
    List<dynamic> restantes = List.from(pendientes);
    for (final recarga in pendientes) {
      try {
        final detalles = recarga['detalles'] ?? [];
        final usuaId = recarga['usua_Id'] ?? 0;
        final ok = await recargaService.insertarRecarga(
          usuaCreacion: usuaId,
          detalles: detalles,
        );
        if (ok) {
          restantes.removeWhere((r) => r['id'] == recarga['id']);
          sincronizadas++;
        }
      } catch (_) {}
    }
    await RecargasScreenOffline.guardarJson('recargas_pendientes.json', restantes);
    return sincronizadas;
  }

  static Future<void> sincronizarRecargasPendientes() async {
    const String archivoPendientes = 'recargas_pendientes.json';
    try {
      final pendientes = await leerJson(archivoPendientes) as List<dynamic>?;
      if (pendientes == null || pendientes.isEmpty) {
        print('No hay recargas pendientes para sincronizar.');
        return;
      }

      final recargaService = RecargasService();
      final noSincronizadas = <Map<String, dynamic>>[];

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (!success) {
            noSincronizadas.add(recarga);
          }
        } catch (e) {
          noSincronizadas.add(recarga);
          print('Error al sincronizar recarga: $e');
        }
      }

      await guardarJson(archivoPendientes, noSincronizadas);
      print('Sincronización completada.');
    } catch (e) {
      print('Error durante la sincronización de recargas pendientes: $e');
    }
  }

  static Future<void> sincronizarRecargasPendientesOffline() async {
    try {
      final pendientes = await leerJson('recargas_pendientes.json') ?? [];
      final recargaService = RecargasService();

      final noSincronizadas = <Map<String, dynamic>>[];

      for (final recarga in pendientes) {
        try {
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          final usuaId = recarga['usua_Id'];

          final success = await recargaService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );

          if (!success) {
            noSincronizadas.add(recarga);
          }
        } catch (e) {
          noSincronizadas.add(recarga);
          print('Error al sincronizar recarga: $e');
        }
      }

      await guardarJson('recargas_pendientes.json', noSincronizadas);
    } catch (e) {
      print('Error al sincronizar recargas pendientes: $e');
    }
  }

  static Future<int> sincronizarRecargasOffline() async {
    try {
      print('🔄 Iniciando sincronización simple de recargas offline...');
      
      final connectivityResult = await Connectivity().checkConnectivity();
      final online = connectivityResult != ConnectivityResult.none;
      if (!online) {
        print('❌ No hay conexión a internet');
        return 0;
      }

      final raw = await leerJson('recargas_pendientes.json');
      if (raw == null || raw is! List || raw.isEmpty) {
        print('✅ No hay recargas pendientes por sincronizar');
        return 0;
      }

      final pendientes = List<Map<String, dynamic>>.from(raw);
      print('📋 Encontradas ${pendientes.length} recargas pendientes');
      
      for (int i = 0; i < pendientes.length; i++) {
        final recarga = pendientes[i];
        print('\n🔍 DEBUG - Recarga ${i + 1}:');
        print('   ID: ${recarga['id']}');
        print('   Usuario: ${recarga['usua_Id']}');
        print('   Fecha: ${recarga['fecha']}');
        print('   Offline: ${recarga['offline']}');
        print('   Detalles (${recarga['detalles'].length} productos):');
        
        final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
        for (int j = 0; j < detalles.length; j++) {
          final detalle = detalles[j];
          print('     Producto ${j + 1}: ID=${detalle['prod_Id']}, Cantidad=${detalle['reDe_Cantidad']}');
        }
      }

      final recargasService = RecargasService();
      final sincronizadasExitosas = <Map<String, dynamic>>[];
      final sincronizadasFallidas = <Map<String, dynamic>>[];
      
      for (int i = 0; i < pendientes.length; i++) {
        final recarga = pendientes[i];
        print('\n🔄 Procesando recarga ${i + 1}/${pendientes.length}');
        
        try {
          final usuaId = recarga['usua_Id'];
          final detalles = List<Map<String, dynamic>>.from(recarga['detalles']);
          
          print('📤 Enviando recarga - Usuario: $usuaId, Detalles: ${detalles.length} productos');
          
          print('📤 DEBUG - Enviando al servidor:');
          print('   usuaCreacion: $usuaId');
          print('   detalles: $detalles');
          
          final success = await recargasService.insertarRecarga(
            usuaCreacion: usuaId,
            detalles: detalles,
          );
          
          if (success) {
            print('✅ Recarga sincronizada exitosamente');
            sincronizadasExitosas.add(recarga);
          } else {
            print('❌ Error al sincronizar recarga');
            sincronizadasFallidas.add(recarga);
          }
        } catch (e) {
          print('❌ Excepción al sincronizar recarga: $e');
          sincronizadasFallidas.add(recarga);
        }
      }

      if (sincronizadasFallidas.isEmpty) {
        await guardarJson('recargas_pendientes.json', []);
        print('🗑️ Todas las recargas sincronizadas, archivo limpiado');
      } else {
        await guardarJson('recargas_pendientes.json', sincronizadasFallidas);
        print('⚠️ Se mantienen ${sincronizadasFallidas.length} recargas fallidas para reintentar');
      }

      print('\n📊 Resumen de sincronización:');
      print('   ✅ Exitosas: ${sincronizadasExitosas.length}');
      print('   ❌ Fallidas: ${sincronizadasFallidas.length}');
      
      return sincronizadasExitosas.length;
    } catch (e) {
      print('❌ Error general en sincronizarRecargasOffline: $e');
      return 0;
    }
  }
}
