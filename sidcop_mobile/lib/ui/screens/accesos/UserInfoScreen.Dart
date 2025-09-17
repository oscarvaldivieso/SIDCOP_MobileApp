import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../services/UserInfoService.dart';

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
    // Inicializar el servicio
    await _userInfoService.initialize();
    
    // Escuchar cambios en los datos del usuario
    _userInfoService.userDataStream.listen((userData) {
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    });
    
    // Escuchar cambios de conectividad
    _userInfoService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
    
    // Cargar datos iniciales
    setState(() {
      _userData = _userInfoService.cachedUserData ?? {};
      _isConnected = _userInfoService.isConnected;
      _isLoading = _userInfoService.isLoading;
    });
  }

  Future<void> _refreshData() async {
    await _userInfoService.forceRefresh();
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
    if (_userData.isEmpty) return defaultValue;
    
    final value = _userData[fieldName];
    if (value == null || value.toString().isEmpty || value.toString() == 'null') {
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
