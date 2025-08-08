// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';
import 'package:sidcop_mobile/ui/screens/recharges/recharges_screen.dart';
import 'package:sidcop_mobile/models/ProductosViewModel.Dart';
import 'package:sidcop_mobile/ui/screens/products/products_list_screen.dart';
import 'package:sidcop_mobile/ui/screens/general/Clientes/client_screen.dart';
import 'package:sidcop_mobile/ui/screens/products/products_list_screen.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';
import 'package:sidcop_mobile/ui/screens/accesos/UserInfoScreen.dart';
import 'package:sidcop_mobile/ui/screens/accesos/Configuracion_Screen.Dart';
import 'package:sidcop_mobile/ui/screens/inventory/inventory_screen.dart';
import '../../services/PerfilUsuarioService.Dart';
import 'package:sidcop_mobile/ui/screens/auth/login_screen.dart';
import 'package:sidcop_mobile/ui/screens/onboarding/onboarding_screen.dart';
import 'package:sidcop_mobile/ui/screens/logistica/Rutas/Rutas_screen.dart';
import 'package:sidcop_mobile/ui/screens/venta/venta_screen.dart';

class CustomDrawer extends StatefulWidget {
  final List<dynamic> permisos;
  const CustomDrawer({Key? key, required this.permisos}) : super(key: key);

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();

  String _nombreUsuario = 'Cargando...';
  String _cargoUsuario = 'Cargando...';
  String? _imagenUsuario;
  String? _imagenVendedor;
  int? _usuaIdPersona;
  bool _isLoading = true;
  List<dynamic> permisos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosUsuario();
    _loadPermisos();
  }

  Future<void> _loadPermisos() async {
    final perfilService = PerfilUsuarioService();
    final userData = await perfilService.obtenerDatosUsuario();
    if (userData != null &&
        (userData['PermisosJson'] != null ||
            userData['permisosJson'] != null)) {
      try {
        final permisosJson =
            userData['PermisosJson'] ?? userData['permisosJson'];
        permisos = jsonDecode(permisosJson);
      } catch (_) {
        permisos = [];
      }
    }
    setState(() {});
  }

  Future<void> _cargarDatosUsuario() async {
    try {
      final nombreCompleto = await _perfilUsuarioService
          .obtenerNombreCompleto();
      final cargo = await _perfilUsuarioService.obtenerCargo();
      final imagenUsuario = await _perfilUsuarioService.obtenerImagenUsuario();

      // Obtener usuaIdPersona desde los datos guardados
      final userData = await _perfilUsuarioService.obtenerDatosUsuario();
      print("userData drawer para inve: $userData");
      final usuaIdPersona = userData?['usua_IdPersona'] as int?;
      final imagenVendedor = userData?['imagen'] as String?;

      if (mounted) {
        setState(() {
          _nombreUsuario = nombreCompleto;
          _cargoUsuario = cargo;
          _imagenUsuario = imagenUsuario;
          _usuaIdPersona = usuaIdPersona;
          _imagenVendedor = imagenVendedor;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nombreUsuario = 'Usuario';
          _cargoUsuario = 'Sin cargo';
          _imagenUsuario = null;
          _imagenVendedor = null;
          _isLoading = false;
        });
      }
    }
  }

  bool tienePermiso(int pantId) {
    return permisos.any((p) => p['Pant_Id'] == pantId);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF181E34),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF181E34),
              border: Border(
                bottom: BorderSide(color: Color(0xFF666571), width: 0.2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen de usuario arriba
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context); // Cerrar el drawer primero
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserInfoScreen(),
                      ),
                    );
                  },
                  child: _buildProfileAvatar(),
                ),
                const SizedBox(height: 12),
                // Nombre/cargo y logout en una fila
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Nombre y cargo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nombreUsuario,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _cargoUsuario,
                            style: const TextStyle(
                              color: Color(0xFFD6B68A),
                              fontSize: 14,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Botón logout
                    IconButton(
                      icon: Transform.rotate(
                        angle: 3.1416,
                        child: const Icon(
                          Icons.logout,
                          color: Color(0xFFD6B68A),
                        ),
                      ),
                      tooltip: 'Cerrar sesión',
                      onPressed: () async {
                        await _perfilUsuarioService.limpiarDatosUsuario();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const OnboardingScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          ListTile(
            leading: const Icon(Icons.home, color: Color(0xFFD6B68A)),
            title: const Text(
              'Inicio',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
              );
            },
          ),
          // Accesos móviles según permisos
          if (tienePermiso(30)) // MRuta
            ListTile(
              leading: const Icon(Icons.map, color: Color(0xFFD6B68A)),
              title: const Text(
                'Ruta',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RutasScreen()),
                );
              },
            ),
          if (tienePermiso(25)) // MProductos
            ListTile(
              leading: const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFFD6B68A),
              ),
              title: const Text(
                'Productos',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductScreen(),
                  ),
                );
              },
            ),
          // MMetas
          ListTile(
            leading: const Icon(Icons.speed_outlined, color: Color(0xFFD6B68A)),
            title: const Text(
              'Metas',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              // Navegar a MMetas
            },
          ),
          if (tienePermiso(57)) // MVentas
            ListTile(
              leading: const Icon(
                Icons.sell_outlined,
                color: Color(0xFFD6B68A),
              ),
              title: const Text(
                'Ventas',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const VentaScreen()),
                  (route) => false,
                );
              },
            ),
          //   if(pantallas!=null && pantallas.contains("DashBoard Admin") && !usuario!.usua_Admin)
          ListTile(
            leading: const Icon(Icons.settings, color: Color(0xFFD6B68A)),
            title: const Text(
              'Perfil y configuracion',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ConfiguracionScreen()),
              );
            },
          ),
          if (tienePermiso(10)) // MClientes
            ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: Color(0xFFD6B68A),
              ),
              title: const Text(
                'Clientes',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const clientScreen()),
                  (route) => false,
                );
              },
            ),
          if (tienePermiso(29)) // MRecargas
            ListTile(
              leading: Transform.flip(
                flipX: true,
                child: const Icon(Icons.replay, color: Color(0xFFD6B68A)),
              ),
              title: const Text(
                'Recargas',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RechargesScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
          //   if(usuario!.usua_Admin)
          if (tienePermiso(58)) // MInventario
            ListTile(
              leading: const Icon(
                Icons.assignment_turned_in_outlined,
                color: Color(0xFFD6B68A),
              ),
              title: const Text(
                'Inventario',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Satoshi',
                  fontWeight: FontWeight.w300,
                ),
              ),
              onTap: () async {
                // Navegar a MInventario
                Navigator.pop(context);
                if (_usuaIdPersona != null) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          InventoryScreen(usuaIdPersona: _usuaIdPersona!),
                    ),
                    (route) => false,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo obtener el ID de usuario para Inventario.',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (_isLoading) {
      return CircleAvatar(
        radius: 32,
        backgroundColor: Colors.grey[300],
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        ),
      );
    }

    if (_imagenUsuario != null && _imagenUsuario!.isNotEmpty) {
      // Si la imagen es una URL (comienza con http)
      if (_imagenUsuario!.startsWith('http')) {
        return CircleAvatar(
          radius: 32,
          backgroundImage: NetworkImage(_imagenUsuario!),
          onBackgroundImageError: (exception, stackTrace) {
            // En caso de error, se mostrará el avatar por defecto
          },
          child: null,
        );
      } else {
        // Si es una imagen en base64 o otro formato
        try {
          return CircleAvatar(
            radius: 32,
            backgroundImage: MemoryImage(
              const Base64Decoder().convert(_imagenUsuario!),
            ),
            onBackgroundImageError: (exception, stackTrace) {
              // En caso de error, se mostrará el avatar por defecto
            },
          );
        } catch (e) {
          return _buildDefaultAvatar();
        }
      }
    }

    // Avatar por defecto si no hay imagen del usuario
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      radius: 32,
      backgroundColor: const Color(0xFFD6B68A),
      child: const Icon(Icons.person, size: 32, color: Colors.white),
    );
  }
}
