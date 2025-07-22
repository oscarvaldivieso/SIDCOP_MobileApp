import 'package:flutter/material.dart';
import '../../../services/ConfiguracionSerivice.Dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFF19213B),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Configuración',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: Color(0xFF19213B),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Icon(Icons.settings, color: Colors.white, size: 48),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 16,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cuenta
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wifi, color: Color(0xFF1CBF63)),
                              SizedBox(width: 8),
                              Text(
                                'Online',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Switch(
                            value: isOnline,
                            activeColor: Color(0xFF1CBF63),
                            onChanged: (val) {
                              setState(() => isOnline = val);
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 24),
                      // Acerca de
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Acerca de',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.help_outline, color: Colors.black54),
                        title: Text('Ayuda y soporte'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      ListTile(
                        leading: Icon(Icons.info_outline, color: Colors.black54),
                        title: Text('Términos y condiciones'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () {},
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                      SizedBox(height: 12),
                      // Almacenamiento y sincronización
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Almacenamiento y sincronización',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.black54),
                        title: Text('Limpiar caché'),
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => _limpiarCache(),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
