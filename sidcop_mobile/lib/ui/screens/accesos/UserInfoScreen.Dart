import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/UserInfoService.dart';
import '../../../debug/DebugCredenciales.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final UserInfoService _userInfoService = UserInfoService();
  
  Map<String, dynamic> _userData = {};
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    print('=== INICIALIZANDO UserInfoScreen ===');
    
    // Inicializar el servicio
    await _userInfoService.initialize();
    
    // Escuchar cambios en los datos del usuario
    _userInfoService.userDataStream.listen((userData) {
      if (mounted) {
        print('UserInfoScreen: Datos recibidos - ${userData.keys.length} campos');
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    });
    
    // Escuchar cambios de conectividad
    _userInfoService.connectivityStream.listen((isConnected) {
      if (mounted) {
        print('UserInfoScreen: Cambio de conectividad - ${isConnected ? "Online" : "Offline"}');
        setState(() {
          _isConnected = isConnected;
        });
        
        // Si acabamos de conectarnos, intentar sincronizar automáticamente
        if (isConnected && !_userInfoService.isLoading) {
          print('UserInfoScreen: Auto-sincronizando al conectarse...');
          _refreshData();
        }
      }
    });
    
    // Cargar datos iniciales
    setState(() {
      _userData = _userInfoService.cachedUserData ?? {};
      _isConnected = _userInfoService.isConnected;
      _isLoading = _userInfoService.isLoading;
    });
    
    print('UserInfoScreen: Inicialización completada');
    print('Datos iniciales: ${_userData.keys.length} campos');
    print('Conectividad: ${_isConnected ? "Online" : "Offline"}');
  }

  Future<void> _refreshData() async {
    print('UserInfoScreen: Iniciando refresh manual...');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _userInfoService.forceRefresh();
      print('UserInfoScreen: Refresh completado exitosamente');
    } catch (e) {
      print('UserInfoScreen: Error en refresh: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = _userInfoService.isLoading;
        });
      }
    }
  }

  /// Método de debug para mostrar toda la información disponible
  void _showDebugInfo() {
    print('=== DEBUG INFO UserInfoScreen ===');
    print('_isLoading: $_isLoading');
    print('_isConnected: $_isConnected');
    print('_userData.isEmpty: ${_userData.isEmpty}');
    print('_userData.keys.length: ${_userData.keys.length}');
    
    if (_userData.isNotEmpty) {
      print('Campos disponibles:');
      _userData.forEach((key, value) {
        print('  $key: $value');
      });
    }
    
    print('UserInfoService.cachedUserData: ${_userInfoService.cachedUserData?.keys.length ?? 0} campos');
    print('UserInfoService.isConnected: ${_userInfoService.isConnected}');
    print('UserInfoService.isLoading: ${_userInfoService.isLoading}');
    
    // Mostrar dialog con información de debug
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Loading: $_isLoading'),
              Text('Connected: $_isConnected'),
              Text('Data fields: ${_userData.keys.length}'),
              const SizedBox(height: 10),
              const Text('Available fields:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...(_userData.keys.map((key) => Text('• $key: ${_userData[key]}')).toList()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await DebugCredenciales.diagnosticoCompleto();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Diagnóstico completado - Ver logs')),
              );
            },
            child: const Text('Diagnóstico'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _forceSync();
            },
            child: const Text('Forzar Sync'),
          ),
        ],
      ),
    );
  }

  /// Fuerza una sincronización completa con el nuevo endpoint
  Future<void> _forceSync() async {
    print('UserInfoScreen: Forzando sincronización completa...');
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Forzar sincronización con API
      final success = await _userInfoService.syncWithAPI();
      print('UserInfoScreen: Sincronización ${success ? "exitosa" : "falló"}');
      
      // Actualizar datos locales
      setState(() {
        _userData = _userInfoService.cachedUserData ?? {};
        _isLoading = _userInfoService.isLoading;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Sincronización exitosa' : 'Error en sincronización'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      print('UserInfoScreen: Error en sincronización forzada: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // No llamamos dispose en el servicio porque es singleton
    super.dispose();
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
          'Información de usuario',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Satoshi',
          ),
        ),
        centerTitle: false,
        actions: [
          // Indicador de conectividad
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isConnected ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _isConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Botón de debug (temporal)
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: _showDebugInfo,
          ),
          // Botón de refresh
          IconButton(
            icon: _userInfoService.isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _userInfoService.isLoading ? null : _refreshData,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Fondo azul oscuro con curva suave y foto de perfil
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
                    // borderRadius: const BorderRadius.only(
                    //   bottomLeft: Radius.circular(60),
                    //   bottomRight: Radius.circular(60),
                    // ),
                    child: Opacity(
                      opacity: 0.7,
                      child: Positioned.fill(
                        child: Transform.flip(
                          child: SvgPicture.asset(
                            'assets/FondoNuevo2.svg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Foto de perfil y nombre
                Positioned(
                  top: 75,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.grey[400],
                    ),
                    child: ClipOval(
                      child: _buildProfileImage(),
                    ),
                  ),
                ),
                Positioned(
                  top: 170,
                  child: Text(
                    _isLoading ? 'Cargando...' : _getUserField('nombreCompleto'),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Tarjeta de información
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Datos personales', Icons.person),
                  _buildInfoRow(
                    'Nombre completo:',
                    _getUserField('nombreCompleto'),
                  ),
                  _buildInfoRow('Número de identidad:', _getUserField('numeroIdentidad')),
                  _buildInfoRow('Número de empleado:', _getUserField('numeroEmpleado')),
                  _buildInfoRow('Correo electrónico:', _getUserField('correo')),
                  _buildInfoRow('Teléfono:', _getUserField('telefono')),
                  _buildInfoRow('Cargo:', _getUserField('cargo')),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    'Datos de asignación laboral',
                    Icons.work,
                  ),
                  _buildInfoRow('Ruta asignada:', _getUserField('rutaAsignada')),
                  _buildInfoRow('Supervisor responsable:', _getUserField('supervisorResponsable')),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    'Información operativa',
                    Icons.assessment,
                  ),
                  _buildInfoRow('Inventario asignado:', '${_getUserField('inventarioAsignado')}'),
                  _buildInfoRow('Clientes asignados:', _getUserField('clientesAsignados')),
                  _buildInfoRow('Ventas del mes:', _getUserField('ventasDelMes')),
                  _buildInfoRow(
                    'Última recarga solicitada:',
                    _getUserField('ultimaRecargaSolicitada'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF1a1d3a), size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1a1d3a),
              fontFamily: 'Satoshi',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2d2d2d),
                fontWeight: FontWeight.w600,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF2d2d2d),
                fontWeight: FontWeight.w400,
                fontFamily: 'Satoshi',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getUserField(String fieldName, {String defaultValue = 'Cargando...'}) {
    if (_isLoading) return 'Cargando...';
    
    if (_userData.isEmpty) {
      print('UserInfoScreen: _userData está vacío para campo $fieldName');
      return defaultValue;
    }
    
    final value = _userData[fieldName];
    
    // Debug: mostrar qué valor se está obteniendo
    print('UserInfoScreen: Campo $fieldName = $value');
    
    if (value == null || value.toString().isEmpty || value.toString() == 'null' || value.toString() == 'Sin información') {
      // Si no hay información y estamos online, mostrar que se está actualizando
      if (_isConnected) {
        return 'Actualizando...';
      }
      return 'Sin información';
    }
    
    return value.toString();
  }

  Widget _buildProfileImage() {
    if (_isLoading) {
      return Container(
        width: 90,
        height: 90,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey,
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            strokeWidth: 2,
          ),
        ),
      );
    }

    final imagenUsuario = _getUserField('imagenUsuario', defaultValue: '');
    
    if (imagenUsuario.isNotEmpty && imagenUsuario != 'Sin información') {
      // Si la imagen es una URL (comienza con http)
      if (imagenUsuario.startsWith('http')) {
        return Image.network(
          imagenUsuario,
          fit: BoxFit.cover,
          width: 90,
          height: 90,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 2,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultProfileImage();
          },
        );
      } else {
        // Si es una imagen en base64 o otro formato
        try {
          return Image.memory(
            const Base64Decoder().convert(imagenUsuario),
            fit: BoxFit.cover,
            width: 90,
            height: 90,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultProfileImage();
            },
          );
        } catch (e) {
          return _buildDefaultProfileImage();
        }
      }
    }

    // Imagen por defecto si no hay imagen del usuario
    return _buildDefaultProfileImage();
  }

  Widget _buildDefaultProfileImage() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[300],
      ),
      child: const Icon(
        Icons.person,
        size: 50,
        color: Colors.grey,
      ),
    );
  }
}

// Fondo decorativo superior
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
