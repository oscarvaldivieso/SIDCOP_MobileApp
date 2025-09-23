import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../services/PerfilUsuarioService.Dart';
import '../../../Offline_Services/InicioSesion_OfflineService.dart';

class UserInfoScreen extends StatefulWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

  @override
  State<UserInfoScreen> createState() => _UserInfoScreenState();
}

class _UserInfoScreenState extends State<UserInfoScreen> {
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();
  
  String _nombreCompleto = 'Cargando...';
  String _numeroIdentidad = 'Cargando...';
  String _numeroEmpleado = 'Cargando...';
  String _correoElectronico = 'Cargando...';
  String _telefono = 'Cargando...';
  String _cargo = 'Cargando...';
  String _supervisor = 'Cargando...';
  String _rutaAsignada = 'Cargando...';
  String? _imagenUsuario;
  bool _isLoading = true;
  bool _isOfflineMode = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      Map<String, dynamic>? userData;
      
      if (hasConnection) {
        // Modo online: obtener datos del servicio normal
        print('=== MODO ONLINE: Obteniendo datos del servicio ===');
        userData = await _perfilUsuarioService.obtenerDatosUsuario();
        
        if (userData == null) {
          print('⚠ No se pudieron obtener datos online, intentando offline...');
          userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
          _isOfflineMode = true;
        }
      } else {
        // Modo offline: obtener datos del caché
        print('=== MODO OFFLINE: Obteniendo datos del caché ===');
        userData = await InicioSesionOfflineService.obtenerDatosUsuarioCache();
        _isOfflineMode = true;
        
        if (userData == null) {
          print('⚠ No hay datos en caché, intentando servicio offline...');
          userData = await _perfilUsuarioService.obtenerDatosUsuario();
        }
      }

      if (userData != null) {
        print('Datos de usuario obtenidos: $userData');
        await _procesarDatosUsuario(userData);
      } else {
        print('✗ No se pudieron obtener datos de usuario');
        _mostrarDatosError();
      }
    } catch (e) {
      print('✗ Error cargando datos de usuario: $e');
      _mostrarDatosError();
    }
  }

  Future<void> _procesarDatosUsuario(Map<String, dynamic> userData) async {
    try {
      // Extraer datos basándose en la estructura de la respuesta
      final nombreCompleto = _obtenerNombreCompleto(userData);
      final numeroIdentidad = _obtenerNumeroIdentidad(userData);
      final numeroEmpleado = _obtenerNumeroEmpleado(userData);
      final correoElectronico = _obtenerCorreoElectronico(userData);
      final telefono = _obtenerTelefono(userData);
      final cargo = _obtenerCargo(userData);
      final supervisor = _obtenerSupervisor(userData);
      final rutaAsignada = _obtenerRutaAsignada(userData);
      final imagenUsuario = _obtenerImagenUsuario(userData);

      if (mounted) {
        setState(() {
          _nombreCompleto = nombreCompleto;
          _numeroIdentidad = numeroIdentidad;
          _numeroEmpleado = numeroEmpleado;
          _correoElectronico = correoElectronico;
          _telefono = telefono;
          _cargo = cargo;
          _supervisor = supervisor;
          _rutaAsignada = rutaAsignada;
          _imagenUsuario = imagenUsuario;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error procesando datos de usuario: $e');
      _mostrarDatosError();
    }
  }

  String _obtenerNombreCompleto(Map<String, dynamic> userData) {
    // Priorizar nombres y apellidos separados
    final nombres = userData['nombres'] as String?;
    final apellidos = userData['apellidos'] as String?;
    
    if (nombres != null && apellidos != null) {
      return '$nombres $apellidos';
    }
    
    // Fallbacks
    return userData['nombreCompleto'] as String? ?? 
           userData['usua_Usuario'] as String? ?? 
           'No disponible';
  }

  String _obtenerNumeroIdentidad(Map<String, dynamic> userData) {
    return userData['dni'] as String? ?? 
           userData['usua_NumeroIdentidad'] as String? ?? 
           userData['numeroDocumento'] as String? ?? 
           'No disponible';
  }

  String _obtenerNumeroEmpleado(Map<String, dynamic> userData) {
    return userData['codigo'] as String? ??
           userData['numeroEmpleado'] as String? ?? 
           userData['usua_Id']?.toString() ?? 
           'No disponible';
  }

  String _obtenerCorreoElectronico(Map<String, dynamic> userData) {
    // Primero intentamos en el nivel superior
    if (userData['correo'] != null) {
      return userData['correo'] as String;
    }
    
    // Luego intentamos en datosVendedor si existe
    if (userData['datosVendedor'] != null && userData['datosVendedor'] is Map) {
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>;
      if (datosVendedor['vend_Correo'] != null) {
        return datosVendedor['vend_Correo'] as String;
      }
    }
    
    // Por último, intentamos con otros nombres comunes
    return userData['email'] as String? ?? 
          userData['correoElectronico'] as String? ?? 
          'No disponible';
  }

  String _obtenerTelefono(Map<String, dynamic> userData) {
    // Primero intentamos en el nivel superior
    if (userData['telefono'] != null) {
      return userData['telefono'] as String;
    }
    
    // Luego intentamos en datosVendedor si existe
    if (userData['datosVendedor'] != null && userData['datosVendedor'] is Map) {
      final datosVendedor = userData['datosVendedor'] as Map<String, dynamic>;
      if (datosVendedor['vend_Telefono'] != null) {
        return datosVendedor['vend_Telefono'] as String;
      }
    }
    
    // Por último, intentamos con otros nombres comunes
    return userData['celular'] as String? ?? 
          userData['phone'] as String? ?? 
          'No disponible';
  }

  String _obtenerCargo(Map<String, dynamic> userData) {
    return userData['cargo'] as String? ?? 
           userData['role_Descripcion'] as String? ?? 
           userData['rol'] as String? ?? 
           'No disponible';
  }

  String _obtenerSupervisor(Map<String, dynamic> userData) {
    return userData['supervisor'] as String? ?? 
           userData['nombreSupervisor'] as String? ?? 
           userData['supervisorNombre'] as String? ?? 
           'No disponible';
  }

  String _obtenerRutaAsignada(Map<String, dynamic> userData) {
    try {
      // Intentar extraer de rutasDelDiaJson
      final rutasDelDiaJson = userData['rutasDelDiaJson'] as String?;
      if (rutasDelDiaJson != null && rutasDelDiaJson.isNotEmpty) {
        final List<dynamic> rutas = jsonDecode(rutasDelDiaJson);
        if (rutas.isNotEmpty) {
          final primeraRuta = rutas[0];
          final rutaCodigo = primeraRuta['Ruta_Codigo'] as String?;
          final rutaDescripcion = primeraRuta['Ruta_Descripcion'] as String?;
          
          if (rutaCodigo != null) {
            return rutaDescripcion != null ? '$rutaCodigo - $rutaDescripcion' : rutaCodigo;
          }
        }
      }
      
      // Fallbacks
      return userData['rutaAsignada'] as String? ?? 
             userData['rutaCodigo'] as String? ?? 
             userData['ruta'] as String? ?? 
             'No disponible';
    } catch (e) {
      print('Error extrayendo ruta: $e');
      return 'No disponible';
    }
  }

  String? _obtenerImagenUsuario(Map<String, dynamic> userData) {
    final imagen = userData['imagen'] as String? ?? 
                   userData['usua_Imagen'] as String? ?? 
                   userData['profileImage'] as String?;
    
    // Verificar que la imagen no sea null, vacía o un placeholder
    if (imagen == null || imagen.isEmpty || imagen.toLowerCase() == 'string') {
      return null;
    }
    
    return imagen;
  }

  void _mostrarDatosError() {
    if (mounted) {
      setState(() {
        _nombreCompleto = 'Error al cargar';
        _numeroIdentidad = 'Error al cargar';
        _numeroEmpleado = 'Error al cargar';
        _correoElectronico = 'Error al cargar';
        _telefono = 'Error al cargar';
        _cargo = 'Error al cargar';
        _supervisor = 'Error al cargar';
        _rutaAsignada = 'Error al cargar';
        _imagenUsuario = null;
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
          'Información de usuario',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            fontFamily: 'Satoshi',
          ),
        ),
        centerTitle: false,
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
                  child: Column(
                    children: [
                      // Nombre del usuario
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        child: Text(
                          _isLoading ? 'Cargando...' : _nombreCompleto,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            fontFamily: 'Satoshi',
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      
                      // Espaciado y contenedor del indicador offline
                      if (_isOfflineMode)
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 20), // Margen inferior aumentado
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.orange, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wifi_off,
                                size: 16,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Modo sin conexión',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Espacio ajustado para el indicador offline
            SizedBox(height: _isOfflineMode ? 30 : 20),
            // Tarjeta de información
            Container(
              margin: const EdgeInsets.only(left: 18, right: 18, top: 10),
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
                  _buildInfoRow('Nombre completo:', _nombreCompleto),
                  _buildInfoRow('Número de identidad:', _numeroIdentidad),
                  _buildInfoRow('Número de empleado:', _numeroEmpleado),
                  _buildInfoRow('Correo electrónico:', _correoElectronico),
                  _buildInfoRow('Teléfono:', _telefono),
                  _buildInfoRow('Cargo:', _cargo),
                  
                  const SizedBox(height: 18),
                  _buildSectionHeader('Datos de asignación laboral', Icons.work),
                  _buildInfoRow('Ruta asignada:', _rutaAsignada),
                  _buildInfoRow('Supervisor responsable:', _supervisor),
                  
                  
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

    if (_imagenUsuario != null && _imagenUsuario!.isNotEmpty) {
      // Si la imagen es una URL (comienza con http)
      if (_imagenUsuario!.startsWith('http')) {
        return Image.network(
          _imagenUsuario!,
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
            const Base64Decoder().convert(_imagenUsuario!),
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