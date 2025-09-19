import 'package:flutter/material.dart';
import 'package:sidcop_mobile/services/PerfilUsuarioService.dart';
import 'package:sidcop_mobile/services/UserInfoService.dart';

/// Archivo de prueba para el nuevo endpoint /Usuarios/IniciarSesion
/// Este archivo permite probar la funcionalidad de obtener información
/// completa del usuario usando las credenciales guardadas
class TestEndpointIniciarSesion extends StatefulWidget {
  const TestEndpointIniciarSesion({Key? key}) : super(key: key);

  @override
  State<TestEndpointIniciarSesion> createState() => _TestEndpointIniciarSesionState();
}

class _TestEndpointIniciarSesionState extends State<TestEndpointIniciarSesion> {
  final PerfilUsuarioService _perfilService = PerfilUsuarioService();
  final UserInfoService _userInfoService = UserInfoService();
  
  Map<String, dynamic>? _informacionCompleta;
  Map<String, String>? _camposEspecificos;
  bool _isLoading = false;
  String _status = 'Listo para probar';

  @override
  void initState() {
    super.initState();
    _userInfoService.initialize();
  }

  /// Prueba el método obtenerInformacionCompletaUsuario
  Future<void> _probarInformacionCompleta() async {
    setState(() {
      _isLoading = true;
      _status = 'Obteniendo información completa...';
      _informacionCompleta = null;
    });

    try {
      final resultado = await _perfilService.obtenerInformacionCompletaUsuario();
      
      setState(() {
        _informacionCompleta = resultado;
        _status = resultado != null 
            ? 'Información completa obtenida exitosamente' 
            : 'No se pudo obtener información completa (sin conexión o error)';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Prueba el método obtenerCamposEspecificos
  Future<void> _probarCamposEspecificos() async {
    setState(() {
      _isLoading = true;
      _status = 'Obteniendo campos específicos...';
      _camposEspecificos = null;
    });

    try {
      final resultado = await _perfilService.obtenerCamposEspecificos();
      
      setState(() {
        _camposEspecificos = resultado;
        _status = 'Campos específicos obtenidos exitosamente';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Prueba la sincronización con el UserInfoService
  Future<void> _probarSincronizacion() async {
    setState(() {
      _isLoading = true;
      _status = 'Ejecutando sincronización...';
    });

    try {
      final resultado = await _userInfoService.syncWithAPI();
      
      setState(() {
        _status = resultado 
            ? 'Sincronización completada exitosamente' 
            : 'Sincronización falló (sin conexión o error)';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en sincronización: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Prueba métodos individuales del UserInfoService
  Future<void> _probarMetodosIndividuales() async {
    setState(() {
      _isLoading = true;
      _status = 'Probando métodos individuales...';
    });

    try {
      final correo = await _userInfoService.obtenerCorreo();
      final telefono = await _userInfoService.obtenerTelefono();
      final ruta = await _userInfoService.obtenerRutaAsignada();
      final supervisor = await _userInfoService.obtenerSupervisorResponsable();
      
      setState(() {
        _camposEspecificos = {
          'correo': correo,
          'telefono': telefono,
          'rutaAsignada': ruta,
          'supervisor': supervisor,
        };
        _status = 'Métodos individuales ejecutados exitosamente';
      });
    } catch (e) {
      setState(() {
        _status = 'Error en métodos individuales: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Endpoint IniciarSesion'),
        backgroundColor: const Color(0xFF1a1d3a),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Estado actual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_status),
                  const SizedBox(height: 8),
                  StreamBuilder<bool>(
                    stream: _userInfoService.connectivityStream,
                    initialData: _userInfoService.isConnected,
                    builder: (context, snapshot) {
                      final isConnected = snapshot.data ?? false;
                      return Row(
                        children: [
                          Icon(
                            isConnected ? Icons.wifi : Icons.wifi_off,
                            color: isConnected ? Colors.green : Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isConnected ? 'Online' : 'Offline',
                            style: TextStyle(
                              color: isConnected ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botones de prueba
            const Text(
              'Pruebas disponibles:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _probarInformacionCompleta,
              child: const Text('1. Probar Información Completa'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _probarCamposEspecificos,
              child: const Text('2. Probar Campos Específicos'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _probarSincronizacion,
              child: const Text('3. Probar Sincronización UserInfoService'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _probarMetodosIndividuales,
              child: const Text('4. Probar Métodos Individuales'),
            ),
            
            const SizedBox(height: 20),
            
            // Resultados
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      ),
                    
                    if (_informacionCompleta != null) ...[
                      const Text(
                        'Información Completa:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _informacionCompleta!.entries
                              .map((entry) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '${entry.key}: ${entry.value}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    if (_camposEspecificos != null) ...[
                      const Text(
                        'Campos Específicos:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Teléfono: ${_camposEspecificos!['telefono']}'),
                            Text('Correo: ${_camposEspecificos!['correo']}'),
                            Text('Ruta Asignada: ${_camposEspecificos!['rutaAsignada']}'),
                            Text('Supervisor: ${_camposEspecificos!['supervisor']}'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // No llamamos dispose en UserInfoService porque es singleton
    super.dispose();
  }
}
