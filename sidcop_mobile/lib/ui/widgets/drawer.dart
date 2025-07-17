// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  @override
  void initState() {
    super.initState();
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
                CircleAvatar(
                  radius: 32,
                  backgroundImage: const AssetImage('assets/user.jpg'),
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
                            'Usuario Demo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cargo del usuario',
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
                      onPressed: () {
                        // Acción de logout aquí
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
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (context) => const DashboardInicioScreen(),
              //     ),
              //   );
            },
          ),
          ListTile(
            leading: const Icon(
              Icons.drive_eta_rounded,
              color: Color(0xFFD6B68A),
            ),
            title: const Text(
              'Insertar carro',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (context) => const InsertarCarroScreen(),
              //     ),
              //   );
            },
          ),
          ListTile(
            leading: const Icon(Icons.car_rental, color: Color(0xFFD6B68A)),
            title: const Text(
              'Catalogo de carros',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              //  Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const MyWidget(),
              //   ),
              // );
            },
          ),
          //   if (usuario != null && usuario!.usua_Clie == true)
          ListTile(
            leading: const Icon(Icons.list, color: Color(0xFFD6B68A)),
            title: const Text(
              'Registro de Rentas',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const RentasClienteScreen(),
              //   ),
              // );
            },
          ),
          //   if(usuario!.usua_Admin)
          ListTile(
            leading: const Icon(
              Icons.drive_eta_rounded,
              color: Color(0xFFD6B68A),
            ),
            title: const Text(
              'Insertar carro',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //       builder: (context) => const InsertarCarroScreen(),
              //     ),
              //   );
            },
          ),
          //   if(pantallas!=null && pantallas.contains("DashBoard Admin") && !usuario!.usua_Admin)
          ListTile(
            leading: const Icon(
              Icons.space_dashboard_rounded,
              color: Color(0xFFD6B68A),
            ),
            title: const Text(
              'Dashboard rentas',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const DashboardRentaScreen(),
              //   ),
              // );
            },
          ),
          //   if(usuario!.usua_Admin)
          ListTile(
            leading: const Icon(
              Icons.space_dashboard_rounded,
              color: Color(0xFFD6B68A),
            ),
            title: const Text(
              'Dashboard rentas',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              // await UsuarioService().cerrarSesion();

              // Navigator.pop(context);

              // Navigator.pushAndRemoveUntil(
              //   context,
              //   MaterialPageRoute(builder: (context) => const LoginScreen()),
              //   (route) => false,
              // );
              print("tiene acceso");
            },
          ),
          //   if(pantallas!=null && pantallas.contains("DashBoard Supervisor") && !usuario!.usua_Admin)
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFD6B68A)),
            title: const Text(
              'DashBoard Supervisor',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () {
              // await UsuarioService().cerrarSesion();

              // Navigator.pop(context);

              // Navigator.pushAndRemoveUntil(
              //   context,
              //   MaterialPageRoute(builder: (context) => const LoginScreen()),
              //   (route) => false,
              // );
              print("tiene acceso 2");
            },
          ),
          //   if(usuario!.usua_Admin)
          ListTile(
            // leading: const Icon(Icons.logout, color: Color(0xFFD6B68A)),
            leading: Transform.rotate(
              angle: 3.1416,
              child: const Icon(Icons.logout, color: Color(0xFFD6B68A)),
            ),
            title: const Text(
              'Cerrar',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Satoshi',
                fontWeight: FontWeight.w300,
              ),
            ),
            onTap: () async {
              //   await UsuarioService().cerrarSesion();

              //   Navigator.pop(context);

              //   Navigator.pushAndRemoveUntil(
              //     context,
              //     MaterialPageRoute(builder: (context) => const LoginScreen()),
              //     (route) => false,
              //   );
            },
          ),
        ],
      ),
    );
  }
}
