import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';

import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../../services/UsuarioService.dart';
import '../../../services/PerfilUsuarioService.Dart';
import '../../screens/auth/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const LoginScreen({super.key, this.scrollController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UsuarioService _usuarioService = UsuarioService();
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();
  String? _error;
  bool _isLoading = false;

  /// Verifica el estado de la conexión a internet
  Future<bool> _tieneConexionInternet() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
  
  /// Maneja el proceso de login offline
  Future<bool> _intentarLoginOffline() async {
    developer.log('Intentando login offline');
    
    // Verificar si hay datos de usuario guardados
    final userData = await _perfilUsuarioService.obtenerDatosUsuario();
    if (userData == null) {
      developer.log('No hay datos de usuario guardados para login offline');
      setState(() {
        _error = 'No hay datos de usuario guardados para login offline';
      });
      return false;
    }
    
    // Verificar si hay contraseña almacenada
    final hayPassword = await _usuarioService.hayContrasenaOffline();
    if (!hayPassword) {
      developer.log('No hay contraseña almacenada para login offline');
      setState(() {
        _error = 'No hay credenciales almacenadas para login offline';
      });
      return false;
    }
    
    // Verificar si la contraseña coincide con la almacenada
    final passwordMatch = await _usuarioService.verificarContrasenaOffline(
      _passwordController.text
    );
    
    if (passwordMatch) {
      developer.log('Login offline exitoso');
      return true;
    } else {
      developer.log('Contraseña offline incorrecta');
      setState(() {
        _error = 'Contraseña incorrecta';
      });
      return false;
    }
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = 'Completa ambos campos';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Verificar conexión a internet
      final tieneConexion = await _tieneConexionInternet();
      
      if (tieneConexion) {
        // Modo online - intentar login normal
        final result = await _usuarioService.iniciarSesion(
          _emailController.text.trim(),
          _passwordController.text,
        );

        if (result != null && result['error'] != true) {
          // Login exitoso - guardar datos del usuario y navegar al home screen
          await _perfilUsuarioService.guardarDatosUsuario(result);
          
          // Obtener y guardar la contraseña para uso offline
          // Intentar obtener el ID de usuario de diferentes campos posibles en la respuesta
          int? usuaId;
          
          // Registrar la respuesta completa para debug
          developer.log('Respuesta completa del login: $result');
          
          // Intentar obtener el ID de diferentes campos posibles
          if (result['usua_Id'] != null) {
            usuaId = result['usua_Id'] is int ? result['usua_Id'] : int.tryParse(result['usua_Id'].toString());
          } else if (result['id'] != null) {
            usuaId = result['id'] is int ? result['id'] : int.tryParse(result['id'].toString());
          } else if (result['usuaId'] != null) {
            usuaId = result['usuaId'] is int ? result['usuaId'] : int.tryParse(result['usuaId'].toString());
          } else if (result['userId'] != null) {
            usuaId = result['userId'] is int ? result['userId'] : int.tryParse(result['userId'].toString());
          } else if (result['data'] != null && result['data'] is Map) {
            final data = result['data'] as Map;
            if (data['usua_Id'] != null) {
              usuaId = data['usua_Id'] is int ? data['usua_Id'] : int.tryParse(data['usua_Id'].toString());
            } else if (data['id'] != null) {
              usuaId = data['id'] is int ? data['id'] : int.tryParse(data['id'].toString());
            } else if (data['usuaId'] != null) {
              usuaId = data['usuaId'] is int ? data['usuaId'] : int.tryParse(data['usuaId'].toString());
            }
          }
          
          if (usuaId != null) {
            developer.log('ID de usuario encontrado: $usuaId');
            try {
              await _usuarioService.obtenerYGuardarContrasenaOffline(usuaId);
            } catch (e) {
              // Si falla la obtención de la contraseña, solo registramos el error
              // pero no interrumpimos el flujo de login
              developer.log('Error obteniendo contraseña offline: $e');
            }
          } else {
            developer.log('No se pudo encontrar el ID de usuario en la respuesta');
          }
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // Login fallido - mostrar error
          setState(() {
            _error = 'Credenciales incorrectas, intenta de nuevo';
          });
        }
      } else {
        // Modo offline - intentar login con credenciales almacenadas
        developer.log('Sin conexión a internet, intentando login offline');
        
        final loginOfflineExitoso = await _intentarLoginOffline();
        
        if (loginOfflineExitoso) {
          // Login offline exitoso
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        } else {
          // Login offline fallido
          setState(() {
            _error = 'Sin conexión a internet. Credenciales incorrectas o no disponibles offline.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: widget.scrollController,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 0.0,
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Iniciar sesión',
                          style: const TextStyle(
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            fontSize: 35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 50),
                        CustomInput(
                          label: 'Usuario',
                          hint: 'Ingresa tu usuario',
                          controller: _emailController,
                          obscureText: true,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _error,
                          onChanged: (_) {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                        CustomInput(
                          label: 'Contraseña',
                          hint: 'Ingresa tu contraseña',
                          controller: _passwordController,
                          obscureText: true,
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _error,
                          onChanged: (_) {
                            setState(() {
                              _error = null;
                            });
                          },
                        ),
                        const SizedBox(height: 50),
                        CustomButton(
                          text: _isLoading ? 'Ingresando...' : 'Ingresar',
                          onPressed: _isLoading ? null : _handleLogin,
                          icon: const Icon(
                            Icons.login,
                            color: Colors.white,
                            size: 24,
                          ),
                          width: MediaQuery.of(context).size.width * 0.7,
                          height: 56,
                        ),
                        const SizedBox(height: 40),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            '¿Olvidaste tu contraseña?',
                            style: const TextStyle(
                              color: Color(0xFF98774A),
                              fontFamily: 'Satoshi',
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
