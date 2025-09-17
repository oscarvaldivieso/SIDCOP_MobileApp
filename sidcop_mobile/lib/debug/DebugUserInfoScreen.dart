import 'package:flutter/material.dart';
import '../Offline_Services/InicioSesion_OfflineService.dart';

class DebugUserInfoScreen extends StatefulWidget {
  const DebugUserInfoScreen({Key? key}) : super(key: key);

  @override
  State<DebugUserInfoScreen> createState() => _DebugUserInfoScreenState();
}

class _DebugUserInfoScreenState extends State<DebugUserInfoScreen> {
  String _debugOutput = 'Presiona el botón para ejecutar debug...';
  bool _isLoading = false;

  Future<void> _ejecutarDebug() async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Ejecutando debug...';
    });

    try {
      // Ejecutar debug completo
      await InicioSesionOfflineService.debugEstadoCompleto();
      
      setState(() {
        _debugOutput = 'Debug ejecutado exitosamente. Revisa la consola para ver los resultados detallados.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugOutput = 'Error ejecutando debug: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _regenerarDiccionario() async {
    setState(() {
      _isLoading = true;
      _debugOutput = 'Regenerando diccionario...';
    });

    try {
      final resultado = await InicioSesionOfflineService.forzarRegeneracionDiccionario();
      
      setState(() {
        if (resultado != null) {
          _debugOutput = 'Diccionario regenerado exitosamente con ${resultado.keys.length} campos:\n\n${resultado.entries.map((e) => '${e.key}: ${e.value}').join('\n')}';
        } else {
          _debugOutput = 'Error: No se pudo regenerar el diccionario';
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _debugOutput = 'Error regenerando diccionario: $e';
        _isLoading = false;
      });
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
          'Debug - Información de Usuario',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Satoshi',
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _ejecutarDebug,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.bug_report, color: Colors.white),
                    label: const Text(
                      'Ejecutar Debug',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _regenerarDiccionario,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text(
                      'Regenerar Diccionario',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2196F3),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Instrucciones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2a2d4a),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3a3d5a)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Instrucciones:',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Presiona "Ejecutar Debug" para ver el estado completo del sistema\n'
                    '2. Revisa la CONSOLA para ver los logs detallados\n'
                    '3. Si hay problemas, presiona "Regenerar Diccionario"\n'
                    '4. Los resultados aparecerán aquí y en la consola',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Output del debug
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2d4a),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3a3d5a)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugOutput,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'monospace',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
