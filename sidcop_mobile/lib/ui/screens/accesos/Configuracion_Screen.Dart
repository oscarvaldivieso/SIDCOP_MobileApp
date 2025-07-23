import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/ConfiguracionSerivice.Dart';
import '../../widgets/OfflineConfigWidget.dart';

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
          title: Text('Limpiar Caché'),
          content: Text('¿Está seguro de que desea limpiar toda la memoria caché? Esta acción eliminará todos los datos almacenados temporalmente.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Limpiar', style: TextStyle(color: Colors.red)),
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
                Text('Limpiando caché...'),
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
            content: Text('Error inesperado al limpiar caché'),
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
      backgroundColor: const Color(0xFF1a1d3a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d3a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Fondo azul oscuro con curva suave y ícono de configuración
            Stack(
              alignment: Alignment.center,
              children: [
                // Fondo decorativo con curva
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: CustomPaint(painter: _HeaderBackgroundPainter()),
                ),
                // Imagen SVG de fondo con flip horizontal y opacidad
                SizedBox(
                  width: double.infinity,
                  height: 220,
                  child: ClipRRect(
                    child: Opacity(
                      opacity: 0.1,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..scale(-1.0, 1.0),
                        child: SvgPicture.asset(
                          'assets/images/fondo.svg',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
                // Ícono de configuración
                Positioned(
                  top: 60,
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
                      size: 50,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            // Contenido principal
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
                child: Column(
                  children: [
                    // Widget de configuración offline
                    const OfflineConfigWidget(),
                    
                    // Separador
                    const Divider(height: 1),
                    
                    // Contenido adicional de configuración
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sección Acerca de
                          const Text(
                            'Acerca de',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2d2d2d),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.help_outline, color: Color(0xFF666666)),
                            title: const Text('Ayuda y soporte'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                            contentPadding: EdgeInsets.zero,
                          ),
                          ListTile(
                            leading: const Icon(Icons.info_outline, color: Color(0xFF666666)),
                            title: const Text('Términos y condiciones'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {},
                            contentPadding: EdgeInsets.zero,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Sección Almacenamiento
                          const Text(
                            'Almacenamiento y sincronización',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2d2d2d),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.delete_outline, color: Color(0xFF666666)),
                            title: const Text('Limpiar caché'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _limpiarCache(),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Fondo decorativo superior (copiado de UserInfoScreen)
class _HeaderBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF23264b);
    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 1.2,
      size.width,
      size.height * 0.6,
    );
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();
    canvas.drawPath(path, paint);

    final paint2 = Paint()..color = const Color(0xFF1a1d3a).withOpacity(0.7);
    final path2 = Path();
    path2.moveTo(0, size.height * 0.8);
    path2.quadraticBezierTo(
      size.width * 0.7,
      size.height * 1.1,
      size.width,
      size.height * 0.7,
    );
    path2.lineTo(size.width, 0);
    path2.lineTo(0, 0);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
