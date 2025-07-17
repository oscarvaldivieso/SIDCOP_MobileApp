// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../screens/auth/login_screen.dart';
// import 'dart:convert';
/*
    TODO: Reemplazar los datos en duro por modelos y servicios reales cuando estén listos
*/

class CustomDrawer extends StatefulWidget {
  const CustomDrawer({super.key});

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  // Datos en duro para pruebas
  String usuario = 'Usuario Demo';
  String cliente = 'Cliente Demo';
  String empleado = 'Empleado Demo';
  List<String> pantallas = ['Home', 'Perfil', 'Configuración'];

  // No es necesario initState ni cargarDatos para datos en duro

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1A1F2B),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF22263A),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bienvenido,', style: TextStyle(color: Colors.white70)),
                Text(usuario, style: TextStyle(color: Colors.white, fontSize: 20)),
                SizedBox(height: 8),
                Text('Cliente: $cliente', style: TextStyle(color: Colors.white54)),
                Text('Empleado: $empleado', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
            decoration: const BoxDecoration(
              color: Color(0xFF0C1120),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    if (usuario != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ModificarUsuario(),
                        ),
                      ).then((_) {
                        // cuando regreses de la pantalla, recarga datos
                        cargarDatos();
                      });
                    }
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundImage: (usuario != null && usuario!.usua_Imagen?.isNotEmpty == true)
                            ? NetworkImage(usuario!.usua_Imagen!)
                            : const AssetImage('assets/user.jpg') as ImageProvider,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  usuario!.usua_Clie == true
                      ? '${cliente!.clie_Nombre} ${cliente!.clie_Apellido}'
                      : '${empleado!.empl_Nombre} ${empleado!.empl_Apellido}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.white),
            title: const Text('Inicio',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w300)),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DashboardInicioScreen(),
                ),
              );
            },
          ),
          if (usuario != null && usuario!.usua_Clie == false)
            if(pantallas!=null && pantallas.contains("Insertar carro") && !usuario!.usua_Admin)
              ListTile(
                leading: const Icon(Icons.drive_eta_rounded, color: Colors.white),
                title: const Text('Insertar carro',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w300)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InsertarCarroScreen(),
                    ),
                  );
                },
              ),
          //if (usuario != null && usuario!.usua_Clie == true)
            ListTile(
              leading: const Icon(Icons.car_rental, color: Colors.white),
              title: const Text('Catalogo de carros',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyWidget(),
                  ),
                );
              },
            ),
          if (usuario != null && usuario!.usua_Clie == true)
            ListTile(
              leading: const Icon(Icons.list, color: Colors.white),
              title: const Text('Registro de Rentas',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RentasClienteScreen(),
                  ),
                );
              },
            ),
          if(usuario!.usua_Admin)
            ListTile(
                leading: const Icon(Icons.drive_eta_rounded, color: Colors.white),
                title: const Text('Insertar carro',
                    style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Satoshi',
                        fontWeight: FontWeight.w300)),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InsertarCarroScreen(),
                    ),
                  );
                },
              ),
          if(pantallas!=null && pantallas.contains("DashBoard Admin") && !usuario!.usua_Admin)
            ListTile(
              leading: const Icon(Icons.space_dashboard_rounded, color: Colors.white),
              title: const Text('Dashboard rentas',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: ()  {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DashboardRentaScreen(),
                  ),
                );
              },
            ),
          if(usuario!.usua_Admin)
            ListTile(
              leading: const Icon(Icons.space_dashboard_rounded, color: Colors.white),
              title: const Text('Dashboard rentas',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: ()  {
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
          if(pantallas!=null && pantallas.contains("DashBoard Supervisor") && !usuario!.usua_Admin)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('DashBoard Supervisor',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: ()  {
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
          if(usuario!.usua_Admin)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white),
              title: const Text('DashBoard Supervisor',
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Satoshi',
                      fontWeight: FontWeight.w300)),
              onTap: ()  {
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
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Cerrar',
                style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Satoshi',
                    fontWeight: FontWeight.w300)),
            onTap: () async {
              await UsuarioService().cerrarSesion();

              Navigator.pop(context);

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}
