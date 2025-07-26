import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/ConfiguracionSerivice.Dart';
import '../../widgets/OfflineConfigWidget.dart';
import '../../widgets/ProductPreloadDemo.dart';

class ConfiguracionScreen extends StatefulWidget {
  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  bool isOnline = true;

  /// Método para limpiar la caché con confirmación del usuario
  Future<void> _limpiarCache() async {
    // Mostrar diálogo de confirmación
    bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Limpiar Caché', style: TextStyle(fontFamily: 'Satoshi')),
          content: Text('¿Está seguro de que desea limpiar toda la memoria caché? Esta acción eliminará todos los datos almacenados temporalmente.', style: TextStyle(fontFamily: 'Satoshi')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar', style: TextStyle(fontFamily: 'Satoshi')),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Limpiar', style: TextStyle(color: Colors.red, fontFamily: 'Satoshi')),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text('Limpiando caché...', style: TextStyle(fontFamily: 'Satoshi')),
              ],
            ),
          );
        },
      );

      try {
        // Llamar al servicio para limpiar caché
        bool resultado = await ConfiguracionService.limpiarCache();
        
        // Cerrar el diálogo de carga
        Navigator.of(context).pop();
        
        // Mostrar resultado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resultado 
                ? 'Caché limpiado exitosamente' 
                : 'Error al limpiar caché',
              style: TextStyle(fontFamily: 'Satoshi'),
            ),
            backgroundColor: resultado ? Colors.green : Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        // Cerrar el diálogo de carga en caso de error
        Navigator.of(context).pop();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inesperado al limpiar caché', style: TextStyle(fontFamily: 'Satoshi')),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco para toda la pantalla
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sección superior con fondo azul oscuro
            Container(
              width: double.infinity,
              height: 280,
              color: const Color(0xFF1a1d3a),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Imagen SVG de fondo con flip horizontal y opacidad
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.7,
                      child: Transform.flip(
                        flipX: true,
                        child: SvgPicture.asset(
                          'assets/FondoNuevo2.svg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  // Ícono de configuración
                  Positioned(
                    top: 100,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.settings,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // AppBar personalizado integrado (al final para estar encima)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      color: Colors.transparent,
                      child: SafeArea(
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Text(
                              'Configuración',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Satoshi',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido principal con fondo blanco
            Transform.translate(
              offset: const Offset(0, -50),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sección Cuenta alineada a la izquierda
                      const Text(
                        'Cuenta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Widget de configuración offline
                      const OfflineConfigWidget(),
                      
                      // Widget de estado de precarga de productos (sin botones)
                      const ProductPreloadDemo(),
                      
                      const SizedBox(height: 24),
                      
                      // Sección Acerca de
                      const Text(
                        'Acerca de',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ListTile(
                        leading: const Icon(Icons.help_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Ayuda y soporte',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      ListTile(
                        leading: const Icon(Icons.info_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Términos y condiciones',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Sección Almacenamiento
                      const Text(
                        'Almacenamiento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          fontFamily: 'Satoshi',
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      ListTile(
                        leading: const Icon(Icons.delete_outline, color: Color(0xFF666666)),
                        title: const Text(
                          'Limpiar caché',
                          style: TextStyle(
                            fontFamily: 'Satoshi',
                            fontSize: 16,
                            color: Color(0xFF333333),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                        onTap: () => _limpiarCache(),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Espacio adicional para asegurar fondo blanco completo
            Container(
              height: 100,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}


