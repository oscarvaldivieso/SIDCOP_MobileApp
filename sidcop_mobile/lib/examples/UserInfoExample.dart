import 'package:flutter/material.dart';
import '../services/UserInfoService.dart';

/// Ejemplo completo de uso del UserInfoService
/// Demuestra cómo usar el servicio offline-first con sincronización automática
class UserInfoExample extends StatefulWidget {
  const UserInfoExample({Key? key}) : super(key: key);

  @override
  State<UserInfoExample> createState() => _UserInfoExampleState();
}

class _UserInfoExampleState extends State<UserInfoExample> {
  final UserInfoService _userInfoService = UserInfoService();
  
  Map<String, dynamic> _userData = {};
  bool _isConnected = false;
  bool _isLoading = true;
  Map<String, dynamic> _serviceStatus = {};

  @override
  void initState() {
    super.initState();
    _initializeExample();
  }

  Future<void> _initializeExample() async {
    print('=== INICIANDO EJEMPLO DE UserInfoService ===');
    
    // 1. Inicializar el servicio
    await _userInfoService.initialize();
    
    // 2. Configurar listeners para cambios automáticos
    _setupListeners();
    
    // 3. Cargar estado inicial
    _loadInitialState();
  }

  void _setupListeners() {
    // Escuchar cambios en los datos del usuario
    _userInfoService.userDataStream.listen((userData) {
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
        print('📱 Datos de usuario actualizados: ${userData.keys.length} campos');
      }
    });
    
    // Escuchar cambios de conectividad
    _userInfoService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
        print('🌐 Estado de conectividad: ${isConnected ? "Online" : "Offline"}');
      }
    });
  }

  void _loadInitialState() {
    setState(() {
      _userData = _userInfoService.cachedUserData ?? {};
      _isConnected = _userInfoService.isConnected;
      _isLoading = _userInfoService.isLoading;
      _serviceStatus = _userInfoService.getServiceStatus();
    });
  }

  Future<void> _forceRefresh() async {
    print('🔄 Forzando actualización de datos...');
    await _userInfoService.forceRefresh();
    _updateServiceStatus();
  }

  void _updateServiceStatus() {
    setState(() {
      _serviceStatus = _userInfoService.getServiceStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UserInfoService - Ejemplo'),
        backgroundColor: const Color(0xFF1a1d3a),
        foregroundColor: Colors.white,
        actions: [
          // Indicador de estado
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected ? Icons.cloud_done : Icons.cloud_off,
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Estado del servicio
            _buildServiceStatusCard(),
            const SizedBox(height: 16),
            
            // Controles
            _buildControlsCard(),
            const SizedBox(height: 16),
            
            // Datos del usuario
            _buildUserDataCard(),
            const SizedBox(height: 16),
            
            // Información técnica
            _buildTechnicalInfoCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: const Color(0xFF1a1d3a),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Estado del Servicio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Conectado', _isConnected ? 'Sí' : 'No', _isConnected),
            _buildStatusRow('Cargando', _isLoading ? 'Sí' : 'No', !_isLoading),
            _buildStatusRow('Tiene datos', _userData.isNotEmpty ? 'Sí' : 'No', _userData.isNotEmpty),
            _buildStatusRow('Datos frescos', _userInfoService.isDataFresh() ? 'Sí' : 'No', _userInfoService.isDataFresh()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, bool isGood) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isGood ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isGood ? Icons.check_circle : Icons.error,
                size: 16,
                color: isGood ? Colors.green : Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings,
                  color: const Color(0xFF1a1d3a),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Controles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _forceRefresh,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(_isLoading ? 'Actualizando...' : 'Actualizar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a1d3a),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _updateServiceStatus();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Estado actualizado')),
                      );
                    },
                    icon: const Icon(Icons.update),
                    label: const Text('Estado'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person,
                  color: const Color(0xFF1a1d3a),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Datos del Usuario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_userData.isEmpty)
              const Text(
                'No hay datos disponibles',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              )
            else ...[
              _buildDataRow('Nombre', _getUserField('nombreCompleto')),
              _buildDataRow('Identidad', _getUserField('numeroIdentidad')),
              _buildDataRow('Empleado', _getUserField('numeroEmpleado')),
              _buildDataRow('Correo', _getUserField('correo')),
              _buildDataRow('Teléfono', _getUserField('telefono')),
              _buildDataRow('Cargo', _getUserField('cargo')),
              _buildDataRow('Ruta', _getUserField('rutaAsignada')),
              _buildDataRow('Supervisor', _getUserField('supervisorResponsable')),
              _buildDataRow('Inventario', '${_getUserField('inventarioAsignado')} productos'),
              _buildDataRow('Clientes', _getUserField('clientesAsignados')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.code,
                  color: const Color(0xFF1a1d3a),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Información Técnica',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Características del UserInfoService:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Funciona offline-first (siempre lee del caché local)\n'
              '• Sincronización automática cada 5 minutos cuando hay internet\n'
              '• Notificaciones en tiempo real de cambios de datos\n'
              '• Monitoreo automático de conectividad\n'
              '• Actualización automática al restaurar conexión\n'
              '• Datos persistentes en FlutterSecureStorage\n'
              '• Patrón Singleton para uso global\n'
              '• Streams para actualizaciones reactivas',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _getUserField(String fieldName) {
    if (_userData.isEmpty) return 'Cargando...';
    
    final value = _userData[fieldName];
    if (value == null || value.toString().isEmpty || value.toString() == 'null') {
      return 'Sin información';
    }
    
    return value.toString();
  }

  @override
  void dispose() {
    // No llamamos dispose en el servicio porque es singleton
    super.dispose();
  }
}
