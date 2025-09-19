import 'dart:convert';
import 'package:sidcop_mobile/Offline_Services/InicioSesion_OfflineService.dart';

/// Script de prueba para verificar la extracción de correo y teléfono
class TestUserDataExtraction {
  
  /// Simula los datos del endpoint de inicio de sesión
  static Map<String, dynamic> getTestUserData() {
    return {
      "code": 200,
      "success": true,
      "message": "Operación completada exitosamente.",
      "data": {
        "code_Status": 1,
        "message_Status": "Sesión iniciada correctamente.",
        "usua_Id": 57,
        "usua_Usuario": "Poncho",
        "usua_Clave": null,
        "usua_Imagen": "https://res.cloudinary.com/dbt7mxrwk/image/upload/v1755117222/ljginn08r1zhxm2hr1kb.png",
        "personaId": 13,
        "usua_IdPersona": 0,
        "usua_EsVendedor": true,
        "usua_EsAdmin": false,
        "usua_Estado": false,
        "nombres": "Brayan",
        "apellidos": "Reyes xd",
        "dni": "0501200401160",
        "correo": "fernandoscar04@gmail.com",
        "telefono": "89626691",
        "imagen": "assets/images/users/32/user-svg.svg",
        "codigo": "VEND-00008",
        "role_Id": 2,
        "role_Descripcion": "Vendedor",
        "carg_Id": null,
        "cargo": "Vendedor",
        "sucu_Id": 1,
        "sucursal": "Sucursal Rio De Piedra",
        "regC_Id": 25,
        "cantidadInventario": 11,
        "supervisor": "Alex Jose",
        "permisosJson": "[{\"Pant_Id\":10,\"Pantalla\":\"Clientes\",\"Pant_Ruta\":\"/general/clientes\",\"Icono\":\"d\",\"Acciones\":[{\"Accion\":\"Listar\"}]}]",
        "rutasDelDiaJson": "[{\"Ruta_Id\":5,\"Ruta_Codigo\":\"RT-606\",\"Ruta_Descripcion\":\"Ruta - 606\",\"Clientes\":[{\"Clie_Id\":1160,\"Clie_Nombres\":\"María\"}]}]",
        "usua_Creacion": 0,
        "usua_FechaCreacion": "0001-01-01T00:00:00",
        "usua_Modificacion": null,
        "usua_FechaModificacion": null
      }
    };
  }

  /// Ejecuta las pruebas de extracción
  static void runTests() {
    print('=== INICIANDO PRUEBAS DE EXTRACCIÓN DE DATOS ===');
    
    // Obtener datos de prueba (simulando la respuesta del endpoint)
    final testData = getTestUserData();
    final userData = testData['data'] as Map<String, dynamic>;
    
    print('Datos de entrada:');
    print('  correo en userData: ${userData['correo']}');
    print('  telefono en userData: ${userData['telefono']}');
    print('');
    
    // Probar extracción de correo
    print('=== PRUEBA DE EXTRACCIÓN DE CORREO ===');
    final correoExtraido = InicioSesionOfflineService.extraerCorreo(userData);
    print('Correo extraído: "$correoExtraido"');
    print('¿Es correcto? ${correoExtraido == "fernandoscar04@gmail.com" ? "✓ SÍ" : "✗ NO"}');
    print('');
    
    // Probar extracción de teléfono
    print('=== PRUEBA DE EXTRACCIÓN DE TELÉFONO ===');
    final telefonoExtraido = InicioSesionOfflineService.extraerTelefono(userData);
    print('Teléfono extraído: "$telefonoExtraido"');
    print('¿Es correcto? ${telefonoExtraido == "89626691" ? "✓ SÍ" : "✗ NO"}');
    print('');
    
    // Probar con datos nulos
    print('=== PRUEBA CON DATOS NULOS ===');
    final correoNulo = InicioSesionOfflineService.extraerCorreo(null);
    final telefonoNulo = InicioSesionOfflineService.extraerTelefono(null);
    print('Correo con datos nulos: "$correoNulo"');
    print('Teléfono con datos nulos: "$telefonoNulo"');
    print('');
    
    // Probar con datos vacíos
    print('=== PRUEBA CON DATOS VACÍOS ===');
    final datosVacios = <String, dynamic>{};
    final correoVacio = InicioSesionOfflineService.extraerCorreo(datosVacios);
    final telefonoVacio = InicioSesionOfflineService.extraerTelefono(datosVacios);
    print('Correo con datos vacíos: "$correoVacio"');
    print('Teléfono con datos vacíos: "$telefonoVacio"');
    print('');
    
    // Resumen
    print('=== RESUMEN DE PRUEBAS ===');
    final correoOK = correoExtraido == "fernandoscar04@gmail.com";
    final telefonoOK = telefonoExtraido == "89626691";
    
    if (correoOK && telefonoOK) {
      print('✓ TODAS LAS PRUEBAS PASARON - Los métodos funcionan correctamente');
    } else {
      print('✗ ALGUNAS PRUEBAS FALLARON:');
      if (!correoOK) print('  - Extracción de correo falló');
      if (!telefonoOK) print('  - Extracción de teléfono falló');
    }
    
    print('=== FIN DE PRUEBAS ===');
  }
}

/// Función principal para ejecutar las pruebas
void main() {
  TestUserDataExtraction.runTests();
}
