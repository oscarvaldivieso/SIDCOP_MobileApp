import 'package:flutter/material.dart';

class UserInfoScreen extends StatelessWidget {
  const UserInfoScreen({Key? key}) : super(key: key);

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
            fontSize: 18,
            fontWeight: FontWeight.w500,
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
                // Fondo con curva
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF181C3A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(60),
                      bottomRight: Radius.circular(60),
                    ),
                  ),
                ),
                Positioned(
                  top: 90,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      color: Colors.grey[400],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/galaxia.jpg',
                        fit: BoxFit.cover,
                        width: 90,
                        height: 90,
                      ),
                    ),
                  ),
                ),
                // Nombre debajo de la foto
                Positioned(
                  top: 190,
                  child: Text(
                    'Deiby Deras',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 55),
            // Nombre
            const Text(
              'Deyby Cardenas',
              style: TextStyle(
                color: Color(0xFF1a1d3a),
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 18),
            // Tarjeta de información
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
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
                    'Deyby Josué Deras Cardenas',
                  ),
                  _buildInfoRow('Número de identidad:', '0512-2005-23476'),
                  _buildInfoRow('Número de empleado:', 'SDC-0251'),
                  _buildInfoRow('Correo electrónico:', 'deybideras@gmail.com'),
                  _buildInfoRow('Teléfono:', '+504 8929-0835'),
                  _buildInfoRow('Cargo:', 'Vendedor'),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    'Datos de asignación laboral',
                    Icons.work,
                  ),
                  _buildInfoRow('Ruta asignada:', 'Ruta 410'),
                  _buildInfoRow('Supervisor responsable:', 'Mario Galeas'),
                  _buildInfoRow('Fecha de ingreso:', '2/7/2025'),
                  const SizedBox(height: 18),
                  _buildSectionHeader(
                    'Información operativa',
                    Icons.assessment,
                  ),
                  _buildInfoRow('Inventario asignado:', '52 productos'),
                  _buildInfoRow('Meta de ventas diaria:', 'L.7,500.00'),
                  _buildInfoRow('Ventas del día:', 'L.5,200.00'),
                  _buildInfoRow(
                    'Última recarga solicitada:',
                    '29 jun 2025 - 1:40 pm',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1a1d3a),
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
              ),
            ),
          ),
        ],
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
