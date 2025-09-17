import 'package:flutter/material.dart';
import '../Offline_Services/InicioSesion_OfflineService.dart';

/// Pantalla de debug para ver exactamente qué datos vienen en la respuesta del login
class LoginDataDebugScreen extends StatefulWidget {
  const LoginDataDebugScreen({Key? key}) : super(key: key);

  @override
  State<LoginDataDebugScreen> createState() => _LoginDataDebugScreenState();
}

class _LoginDataDebugScreenState extends State<LoginDataDebugScreen> {
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _datosVendedor;
  bool _isLoading = true;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _loadLoginData();
  }

  Future<void> _loadLoginData() async {
    setState(() {
      _debugLog = 'Cargando datos del login...\n';
      _isLoading = true;
    });

    try {
      // Obtener datos del usuario desde el caché
      final userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
      
      if (userData != null) {
        setState(() {
          _userData = userData;
          _datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
        });
        
        _addLog('✓ Datos del login cargados exitosamente');
        _addLog('Campos principales: ${userData.keys.length}');
        
        if (_datosVendedor != null) {
          _addLog('Campos en datosVendedor: ${_datosVendedor!.keys.length}');
        }
        
        // Verificar campos específicos para ruta y supervisor
        _checkSpecificFields();
        
      } else {
        _addLog('✗ No se encontraron datos del login en caché');
      }
      
    } catch (e) {
      _addLog('✗ Error cargando datos: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _checkSpecificFields() {
    _addLog('\n=== VERIFICANDO CAMPOS ESPECÍFICOS ===');
    
    // Campos relacionados con ruta
    final rutaFields = [
      'ruta', 'rutaAsignada', 'ruta_Codigo', 'ruta_Descripcion', 
      'rutasDelDiaJson', 'codigo'
    ];
    
    _addLog('\nCAMPOS DE RUTA:');
    for (final field in rutaFields) {
      final value = _userData?[field];
      if (value != null) {
        _addLog('  ✓ $field: $value');
      } else {
        _addLog('  ✗ $field: null');
      }
    }
    
    // Campos relacionados con supervisor
    final supervisorFields = [
      'supervisor', 'supervisorResponsable', 'supervisor_Nombre', 
      'nombreSupervisor', 'supervisor_Nombres', 'supervisor_Apellidos'
    ];
    
    _addLog('\nCAMPOS DE SUPERVISOR:');
    for (final field in supervisorFields) {
      final value = _userData?[field];
      if (value != null) {
        _addLog('  ✓ $field: $value');
      } else {
        _addLog('  ✗ $field: null');
      }
    }
    
    // Verificar en datosVendedor también
    if (_datosVendedor != null) {
      _addLog('\nEN DATOS VENDEDOR:');
      _addLog('  vend_Codigo: ${_datosVendedor!['vend_Codigo']}');
      _addLog('  nombreSupervisor: ${_datosVendedor!['nombreSupervisor']}');
      _addLog('  apellidoSupervisor: ${_datosVendedor!['apellidoSupervisor']}');
    }
    
    // Probar los métodos de extracción
    _addLog('\n=== RESULTADOS DE EXTRACCIÓN ===');
    final rutaExtraida = _extraerRutaAsignada(_userData);
    final supervisorExtraido = _extraerSupervisorResponsable(_userData);
    
    _addLog('Ruta extraída: $rutaExtraida');
    _addLog('Supervisor extraído: $supervisorExtraido');
  }

  String _extraerRutaAsignada(Map<String, dynamic>? userData) {
    if (userData == null) return 'No asignada';
    
    try {
      // Datos directos del login
      final rutaLogin = userData['ruta']?.toString() ?? 
                       userData['rutaAsignada']?.toString() ?? 
                       userData['ruta_Codigo']?.toString() ?? 
                       userData['ruta_Descripcion']?.toString() ?? '';
      
      if (rutaLogin.isNotEmpty && rutaLogin != 'null') {
        return rutaLogin;
      }
      
      // Desde rutasDelDiaJson
      final rutasDelDiaJson = userData['rutasDelDiaJson'] as String?;
      if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty && rutasDelDiaJson != 'null') {
        // Aquí iría el parsing del JSON
        return 'Desde rutasDelDiaJson (requiere parsing)';
      }
      
      // Desde datosVendedor
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        final vendCodigo = datosVendedor['vend_Codigo'];
        if (vendCodigo != null) {
          return 'Ruta $vendCodigo';
        }
      }
      
      return 'No asignada';
    } catch (e) {
      return 'Error: $e';
    }
  }

  String _extraerSupervisorResponsable(Map<String, dynamic>? userData) {
    if (userData == null) return 'No asignado';
    
    try {
      // Datos directos del login
      final supervisorLogin = userData['supervisor']?.toString() ?? 
                             userData['supervisorResponsable']?.toString() ?? 
                             userData['supervisor_Nombre']?.toString() ?? 
                             userData['nombreSupervisor']?.toString() ?? '';
      
      if (supervisorLogin.isNotEmpty && supervisorLogin != 'null') {
        return supervisorLogin;
      }
      
      // Campos combinados del login
      final nombreSup = userData['supervisor_Nombres']?.toString() ?? '';
      final apellidoSup = userData['supervisor_Apellidos']?.toString() ?? '';
      if (nombreSup.isNotEmpty || apellidoSup.isNotEmpty) {
        final supervisorCompleto = '$nombreSup $apellidoSup'.trim();
        if (supervisorCompleto.isNotEmpty) {
          return supervisorCompleto;
        }
      }
      
      // Desde datosVendedor
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>?;
      if (datosVendedor != null) {
        final nombreSupervisor = datosVendedor['nombreSupervisor']?.toString() ?? '';
        final apellidoSupervisor = datosVendedor['apellidoSupervisor']?.toString() ?? '';
        final supervisor = '$nombreSupervisor $apellidoSupervisor'.trim();
        if (supervisor.isNotEmpty && supervisor != 'null null') {
          return supervisor;
        }
      }
      
      return 'No asignado';
    } catch (e) {
      return 'Error: $e';
    }
  }

  void _addLog(String message) {
    setState(() {
      _debugLog += '$message\n';
    });
    print('LOGIN DEBUG: $message');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Datos del Login'),
        backgroundColor: const Color(0xFF1a1d3a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLoginData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Log de debug
                  _buildLogSection(),
                  const SizedBox(height: 16),
                  
                  // Datos principales del login
                  if (_userData != null) _buildMainDataSection(),
                  const SizedBox(height: 16),
                  
                  // Datos del vendedor
                  if (_datosVendedor != null) _buildVendedorDataSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildLogSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Log de Debug',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _debugLog,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos Principales del Login',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _userData!.entries.map((entry) {
                    if (entry.key == 'datosVendedor') return Container();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '${entry.key}: ${entry.value}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendedorDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos del Vendedor',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _datosVendedor!.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                      ),
                    ),
                  )).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
