import 'package:flutter/material.dart';
import '../services/UserInfoService.dart';
import '../Offline_Services/InicioSesion_OfflineService.dart';

/// Pantalla de debug para verificar que la información de usuario funcione correctamente
class UserInfoDebugScreen extends StatefulWidget {
  const UserInfoDebugScreen({Key? key}) : super(key: key);

  @override
  State<UserInfoDebugScreen> createState() => _UserInfoDebugScreenState();
}

class _UserInfoDebugScreenState extends State<UserInfoDebugScreen> {
  final UserInfoService _userInfoService = UserInfoService();
  Map<String, dynamic> _userData = {};
  Map<String, String> _infoOperativa = {};
  bool _isLoading = true;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _initializeDebug();
  }

  Future<void> _initializeDebug() async {
    setState(() {
      _debugLog = 'Iniciando debug...\n';
    });

    try {
      // 1. Inicializar servicio
      _addLog('1. Inicializando UserInfoService...');
      await _userInfoService.initialize();
      _addLog('✓ UserInfoService inicializado');

      // 2. Obtener datos del diccionario
      _addLog('2. Obteniendo diccionario de usuario...');
      final diccionario = await InicioSesionOfflineService.obtenerDiccionarioUsuario();
      if (diccionario != null) {
        _addLog('✓ Diccionario encontrado con ${diccionario.keys.length} campos');
        setState(() {
          _userData = diccionario;
        });
      } else {
        _addLog('⚠ No se encontró diccionario, generando...');
        await InicioSesionOfflineService.generarYGuardarDiccionarioUsuario();
        final nuevoDiccionario = await InicioSesionOfflineService.obtenerDiccionarioUsuario();
        if (nuevoDiccionario != null) {
          _addLog('✓ Diccionario generado con ${nuevoDiccionario.keys.length} campos');
          setState(() {
            _userData = nuevoDiccionario;
          });
        }
      }

      // 3. Obtener información operativa
      _addLog('3. Obteniendo información operativa...');
      final infoOp = await InicioSesionOfflineService.obtenerInformacionOperativa();
      setState(() {
        _infoOperativa = infoOp;
      });
      _addLog('✓ Información operativa obtenida');

      // 4. Verificar campos específicos
      _addLog('4. Verificando campos específicos...');
      _addLog('   - Correo: ${_getUserField('correo')}');
      _addLog('   - Teléfono: ${_getUserField('telefono')}');
      _addLog('   - Inventario: ${_infoOperativa['inventarioAsignado']}');
      _addLog('   - Clientes: ${_infoOperativa['clientesAsignados']}');
      _addLog('   - Última recarga: ${_infoOperativa['ultimaRecargaSolicitada']}');

      setState(() {
        _isLoading = false;
      });
      _addLog('✓ Debug completado exitosamente');

    } catch (e) {
      _addLog('✗ Error en debug: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _debugLog += '$message\n';
    });
    print('DEBUG: $message');
  }

  String _getUserField(String fieldName) {
    final value = _userData[fieldName];
    if (value == null || value.toString().isEmpty || value.toString() == 'null') {
      return 'Sin información';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Información Usuario'),
        backgroundColor: const Color(0xFF1a1d3a),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _isLoading = true;
                _debugLog = '';
                _userData = {};
                _infoOperativa = {};
              });
              _initializeDebug();
            },
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
                  
                  // Datos personales
                  _buildDataSection('Datos Personales', {
                    'Nombre completo': _getUserField('nombreCompleto'),
                    'Número identidad': _getUserField('numeroIdentidad'),
                    'Número empleado': _getUserField('numeroEmpleado'),
                    'Correo electrónico': _getUserField('correo'),
                    'Teléfono': _getUserField('telefono'),
                    'Cargo': _getUserField('cargo'),
                  }),
                  const SizedBox(height: 16),
                  
                  // Datos laborales
                  _buildDataSection('Datos Laborales', {
                    'Ruta asignada': _infoOperativa['rutaAsignada'] ?? 'Sin información',
                    'Supervisor responsable': _infoOperativa['supervisorResponsable'] ?? 'Sin información',
                  }),
                  const SizedBox(height: 16),
                  
                  // Información operativa
                  _buildDataSection('Información Operativa', {
                    'Inventario asignado': '${_infoOperativa['inventarioAsignado'] ?? '0'} productos',
                    'Clientes asignados': _infoOperativa['clientesAsignados'] ?? '0',
                    'Meta ventas diaria': _infoOperativa['metaVentasDiaria'] ?? 'Sin información',
                    'Ventas del día': _infoOperativa['ventasDelDia'] ?? 'Sin información',
                    'Última recarga': _infoOperativa['ultimaRecargaSolicitada'] ?? 'Sin información',
                  }),
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
              height: 200,
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

  Widget _buildDataSection(String title, Map<String, String> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...data.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      '${entry.key}:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 14,
                        color: entry.value == 'Sin información' 
                            ? Colors.red 
                            : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ],
        ),
      ),
    );
  }
}
