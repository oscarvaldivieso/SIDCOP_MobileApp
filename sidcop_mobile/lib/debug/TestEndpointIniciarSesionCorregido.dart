import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/services/UserInfoService.dart';

/// Archivo de prueba para verificar el funcionamiento del endpoint /Usuarios/IniciarSesion corregido
/// Este archivo ayuda a diagnosticar y validar que la información se obtenga correctamente
class TestEndpointIniciarSesionCorregido {
  
  /// Prueba completa del nuevo método obtenerInformacionCompletaUsuario corregido
  static Future<void> probarEndpointCorregido() async {
    print('=== INICIANDO PRUEBA DEL ENDPOINT /Usuarios/IniciarSesion CORREGIDO ===');
    
    try {
      final perfilService = PerfilUsuarioService();
      
      // Paso 1: Verificar datos guardados
      print('\n--- PASO 1: Verificando datos guardados ---');
      final userData = await perfilService.obtenerDatosUsuario();
      
      if (userData == null) {
        print('❌ ERROR: No hay datos de usuario guardados');
        return;
      }
      
      print('✓ Datos de usuario encontrados');
      print('  - usua_Id: ${userData['usua_Id']}');
      print('  - usua_Usuario: ${userData['usua_Usuario']}');
      print('  - usua_IdPersona: ${userData['usua_IdPersona']}');
      print('  - usua_EsVendedor: ${userData['usua_EsVendedor']}');
      print('  - Campos disponibles: ${userData.keys.length}');
      
      // Paso 2: Verificar credenciales seguras (indirectamente)
      print('\n--- PASO 2: Verificando disponibilidad de credenciales ---');
      print('ℹ Las credenciales se verificarán internamente durante la consulta');
      
      // Paso 3: Probar el método completo corregido
      print('\n--- PASO 3: Probando obtenerInformacionCompletaUsuario CORREGIDO ---');
      final informacionCompleta = await perfilService.obtenerInformacionCompletaUsuario();
      
      if (informacionCompleta != null) {
        print('✅ ÉXITO: Información completa obtenida');
        print('\n📋 INFORMACIÓN OBTENIDA:');
        print('  📞 Teléfono: ${informacionCompleta['telefono']}');
        print('  📧 Correo: ${informacionCompleta['correo']}');
        print('  🛣️ Ruta asignada: ${informacionCompleta['rutaAsignada']}');
        print('  👨‍💼 Supervisor: ${informacionCompleta['supervisor']}');
        print('  👤 Nombres: ${informacionCompleta['nombres']}');
        print('  👤 Apellidos: ${informacionCompleta['apellidos']}');
        print('  🆔 DNI: ${informacionCompleta['dni']}');
        print('  💼 Cargo: ${informacionCompleta['cargo']}');
        print('  🔢 Código: ${informacionCompleta['codigo']}');
        print('  📦 Inventario: ${informacionCompleta['cantidadInventario']}');
        print('  🔄 Fuente de datos: ${informacionCompleta['fuenteDatos']}');
        print('  📅 Fecha consulta: ${informacionCompleta['fechaConsulta']}');
        
        // Verificar si los datos críticos están disponibles
        print('\n🔍 VERIFICACIÓN DE DATOS CRÍTICOS:');
        final datosCriticos = ['telefono', 'correo', 'rutaAsignada', 'supervisor'];
        bool todosCriticosDisponibles = true;
        
        for (String campo in datosCriticos) {
          final valor = informacionCompleta[campo];
          final disponible = valor != null && 
                           valor.toString().isNotEmpty && 
                           valor.toString() != 'Sin información' &&
                           valor.toString() != 'No disponible';
          
          print('  ${disponible ? '✓' : '❌'} $campo: $valor');
          if (!disponible) todosCriticosDisponibles = false;
        }
        
        if (todosCriticosDisponibles) {
          print('\n🎉 TODOS LOS DATOS CRÍTICOS ESTÁN DISPONIBLES');
        } else {
          print('\n⚠ ALGUNOS DATOS CRÍTICOS NO ESTÁN DISPONIBLES');
        }
        
        print('\n🔍 TODOS LOS CAMPOS DISPONIBLES:');
        informacionCompleta.forEach((key, value) {
          print('  $key: $value');
        });
        
      } else {
        print('❌ ERROR: No se pudo obtener información completa');
      }
      
      // Paso 4: Probar obtenerCamposEspecificos
      print('\n--- PASO 4: Probando obtenerCamposEspecificos ---');
      final camposEspecificos = await perfilService.obtenerCamposEspecificos();
      
      print('📋 CAMPOS ESPECÍFICOS:');
      camposEspecificos.forEach((key, value) {
        print('  $key: $value');
      });
      
    } catch (e) {
      print('❌ ERROR CRÍTICO en prueba: $e');
      print('Stack trace: ${e.toString()}');
    }
    
    print('\n=== PRUEBA DEL ENDPOINT CORREGIDO COMPLETADA ===');
  }
  
  /// Prueba el UserInfoService completo con el nuevo endpoint
  static Future<void> probarUserInfoServiceCompleto() async {
    print('\n=== INICIANDO PRUEBA COMPLETA DEL UserInfoService ===');
    
    try {
      final userInfoService = UserInfoService();
      
      // Inicializar el servicio
      print('Inicializando UserInfoService...');
      await userInfoService.initialize();
      
      // Esperar un momento para que se carguen los datos
      await Future.delayed(Duration(seconds: 3));
      
      print('Estado del servicio:');
      print('  - isConnected: ${userInfoService.isConnected}');
      print('  - isLoading: ${userInfoService.isLoading}');
      print('  - hasData: ${userInfoService.cachedUserData != null}');
      
      if (userInfoService.cachedUserData != null) {
        print('  - Campos en caché: ${userInfoService.cachedUserData!.keys.length}');
        
        print('\n📋 DATOS EN CACHÉ:');
        final userData = userInfoService.cachedUserData!;
        
        // Mostrar campos importantes
        final camposImportantes = [
          'nombreCompleto', 'numeroIdentidad', 'numeroEmpleado',
          'correo', 'telefono', 'cargo', 'rutaAsignada', 'supervisorResponsable',
          'inventarioAsignado', 'clientesAsignados', 'ventasDelMes'
        ];
        
        for (String campo in camposImportantes) {
          final valor = userData[campo] ?? 'No disponible';
          print('  $campo: $valor');
        }
        
        // Forzar sincronización si hay conexión
        if (userInfoService.isConnected) {
          print('\n--- FORZANDO SINCRONIZACIÓN ---');
          final syncSuccess = await userInfoService.syncWithAPI();
          print('Sincronización ${syncSuccess ? 'exitosa' : 'falló'}');
          
          // Mostrar datos actualizados
          if (syncSuccess && userInfoService.cachedUserData != null) {
            print('\n📋 DATOS DESPUÉS DE SINCRONIZACIÓN:');
            final updatedData = userInfoService.cachedUserData!;
            
            for (String campo in camposImportantes) {
              final valor = updatedData[campo] ?? 'No disponible';
              print('  $campo: $valor');
            }
          }
        }
      }
      
    } catch (e) {
      print('❌ ERROR en prueba del UserInfoService: $e');
    }
    
    print('\n=== PRUEBA COMPLETA DEL UserInfoService COMPLETADA ===');
  }
  
  /// Método para mostrar información de debug en la UI
  static Widget buildDebugWidget(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Endpoint IniciarSesion'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                await probarEndpointCorregido();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Prueba completada - Ver logs')),
                );
              },
              child: Text('Probar Endpoint Corregido'),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await probarUserInfoServiceCompleto();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Prueba UserInfoService completada - Ver logs')),
                );
              },
              child: Text('Probar UserInfoService Completo'),
            ),
            SizedBox(height: 16),
            Text(
              'Revisa los logs en la consola para ver los resultados detallados.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
