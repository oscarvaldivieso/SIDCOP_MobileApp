import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';

import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../../services/UsuarioService.dart';
import '../../../services/PerfilUsuarioService.Dart';
import '../../../services/SyncService.dart';
import '../../../services/OfflineAuthService.dart';
import 'package:sidcop_mobile/Offline_Services/InicioSesion_OfflineService.dart';
import 'package:sidcop_mobile/Offline_Services/Pedidos_OfflineService.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../screens/auth/forgot_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const LoginScreen({super.key, this.scrollController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  // Método estático para limpiar credenciales guardadas (accesible desde otras clases)
  // No limpia las credenciales offline para permitir el inicio de sesión offline permanente
  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    // Solo eliminamos la bandera de recordar, no las credenciales guardadas
    await prefs.setBool('remember_me', false);
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final UsuarioService _usuarioService = UsuarioService();
  final PerfilUsuarioService _perfilUsuarioService = PerfilUsuarioService();
  
  // Errores individuales para cada campo
  String? _emailError;
  String? _passwordError;
  
  // Error general para credenciales incorrectas
  String? _generalError;
  bool _isLoading = false;
  String _syncStatus = '';
  bool _rememberMe = false;
  bool _obscurePassword = true; // true = oculto, false = visible
  
  // Connectivity listener
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  // Verificar si hay una sesión guardada
  Future<void> _checkSavedSession() async {
    // Primero verificar si hay una sesión offline válida para auto-login directo
    final hasValidSession = await OfflineAuthService.hasValidOfflineSession();
    
    if (hasValidSession) {
      // Verificar conectividad para decidir el tipo de auto-login
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      setState(() {
        _isLoading = true;
        _syncStatus = hasConnection ? 'Restaurando sesión...' : 'Restaurando sesión offline...';
      });
      
      try {
        Map<String, dynamic>? result;
        
        if (hasConnection) {
          // Intentar auto-login online con credenciales guardadas
          final prefs = await SharedPreferences.getInstance();
          final savedEmail = prefs.getString('saved_email') ?? '';
          final savedPassword = prefs.getString('saved_password') ?? '';
          
          try {
            result = await _usuarioService.iniciarSesion(savedEmail, savedPassword);
            
            if (result != null && result['error'] != true) {
              // Actualizar credenciales offline con datos frescos
              await OfflineAuthService.saveOfflineCredentials(
                username: savedEmail,
                password: savedPassword,
                userData: result,
              );
              await OfflineAuthService.updateLastOnlineLogin();
              
              // Cachear datos de pedidos y productos durante el login
              setState(() {
                _syncStatus = 'Cacheando datos para uso offline...';
              });
              await InicioSesionOfflineService.cachearDatosInicioSesion(result);
            }
          } catch (e) {
            // Si falla online, usar offline
            result = await OfflineAuthService.autoRestoreOfflineSession();
          }
        } else {
          // Sin conexión, usar directamente offline
          result = await OfflineAuthService.autoRestoreOfflineSession();
        }
        
        if (result != null && result['error'] != true) {
          // Auto-login exitoso - ir directo al home
          await _perfilUsuarioService.guardarDatosUsuario(result);
          
          if (hasConnection && result['offline_login'] != true) {
            // Sincronización rápida para login online
            setState(() {
              _syncStatus = 'Sincronizando...';
            });
            
            await SyncService.syncAfterLogin(
              immediate: false,
              onProgress: (status) {
                if (mounted) {
                  setState(() {
                    _syncStatus = status;
                  });
                }
              },
            );
          }
          
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
          return; // Salir temprano, no mostrar pantalla de login
        }
      } catch (e) {
        // Error en auto-login, continuar con pantalla de login normal
      }
      
      // Si llegamos aquí, el auto-login falló, mostrar pantalla normal
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncStatus = '';
        });
      }
    }
    
    // Comportamiento normal: cargar credenciales en la pantalla de login
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final savedEmail = prefs.getString('saved_email') ?? '';
    final savedPassword = prefs.getString('saved_password') ?? '';
    
    if (rememberMe && savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  // Maneja el auto-login con soporte para modo offline
  Future<void> _handleAutoLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      Map<String, dynamic>? result;
      bool isOfflineLogin = false;
      
      if (hasConnection) {
        // Intentar auto-login online primero
        setState(() {
          _syncStatus = 'Restaurando sesión...';
        });
        
        try {
          result = await _usuarioService.iniciarSesion(
            _emailController.text.trim(),
            _passwordController.text,
          );
          
          if (result != null && result['error'] != true) {
            // Auto-login online exitoso - actualizar credenciales offline
            await OfflineAuthService.saveOfflineCredentials(
              username: _emailController.text.trim(),
              password: _passwordController.text,
              userData: result,
            );
            await OfflineAuthService.updateLastOnlineLogin();
            
            // Cachear datos de pedidos y productos durante el login
            setState(() {
              _syncStatus = 'Cacheando datos para uso offline...';
            });
            await InicioSesionOfflineService.cachearDatosInicioSesion(result);
          }
        } catch (e) {
          // Error de conexión - intentar auto-login offline
          setState(() {
            _syncStatus = 'Sin conexión, restaurando sesión offline...';
          });
          
          result = await _attemptOfflineLogin();
          isOfflineLogin = true;
        }
      } else {
        // Sin conexión - usar auto-login offline directamente
        setState(() {
          _syncStatus = 'Modo offline - Restaurando sesión...';
        });
        
        result = await _attemptOfflineLogin();
        isOfflineLogin = true;
      }

      if (result != null && result['error'] != true) {
        // Auto-login exitoso (online u offline)
        await _perfilUsuarioService.guardarDatosUsuario(result);
        
        if (isOfflineLogin) {
          setState(() {
            _syncStatus = 'Sesión restaurada (offline)';
          });
          
          // Pequeña pausa para mostrar el mensaje
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          // Sincronización solo para auto-login online
          setState(() {
            _syncStatus = 'Sincronizando datos...';
          });
          
          await SyncService.syncAfterLogin(
            immediate: false,
            onProgress: (status) {
              if (mounted) {
                setState(() {
                  _syncStatus = status;
                });
              }
            },
          );
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Auto-login fallido - mostrar pantalla de login normal
        if (mounted) {
          setState(() {
            _isLoading = false;
            _syncStatus = '';
          });
        }
      }
    } catch (e) {
      // Error en auto-login - mostrar pantalla de login normal
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncStatus = '';
        });
      }
    }
  }

  // Guardar credenciales para acceso offline y preferencia de "Remember me"
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    // Guardar credenciales para acceso offline
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    
    // Actualizar la preferencia de "Remember me"
    await prefs.setBool('remember_me', _rememberMe);
    
    // Si está marcado "Recordar sesión", guardar credenciales para autenticación offline
    if (_rememberMe) {
      try {
        // Usar el método iniciarSesion para obtener los datos del usuario
        final userData = await _usuarioService.iniciarSesion(email, password);
        if (userData != null && userData['error'] != true) {
          // Guardar credenciales offline completas
          await OfflineAuthService.saveOfflineCredentials(
            username: email,
            password: password,
            userData: userData,
          );
        }
      } catch (e) {
        // Si falla, guardar solo las credenciales básicas
        await OfflineAuthService.saveBasicOfflineCredentials(
          username: email,
          password: password,
        );
      }
    }
  }


  Future<void> _handleLogin() async {
    // Limpiar errores previos
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    // Validar campos individualmente
    bool hasError = false;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() {
        _emailError = 'El campo Usuario es requerido';
      });
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() {
        _passwordError = 'El campo Contraseña es requerido';
      });
      hasError = true;
    }

    // Si hay errores de validación, no continuar
    if (hasError) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Verificar conectividad
      final connectivityResult = await Connectivity().checkConnectivity();
      final hasConnection = connectivityResult != ConnectivityResult.none;
      
      Map<String, dynamic>? result;
      bool isOfflineLogin = false;
      
      // Guardar credenciales para acceso offline (incluso antes de intentar login)
      await _saveCredentials();
      
      if (hasConnection) {
        // Intentar login online primero
        setState(() {
          _syncStatus = 'Conectando al servidor...';
        });
        
        try {
          result = await _usuarioService.iniciarSesion(email, password);
          
          if (result != null && result['error'] != true) {
            // Login online exitoso - actualizar credenciales offline
            await OfflineAuthService.saveOfflineCredentials(
              username: email,
              password: password,
              userData: result,
            );
            
            // Actualizar timestamp del último login online
            await OfflineAuthService.updateLastOnlineLogin();
          }
        } catch (e) {
          // Error de conexión - intentar login offline
          setState(() {
            _syncStatus = 'Sin conexión, intentando acceso offline...';
          });
          
          result = await _attemptOfflineLogin();
          isOfflineLogin = true;
        }
      } else {
        // Sin conexión - usar login offline directamente
        setState(() {
          _syncStatus = 'Modo offline - Verificando credenciales...';
        });
        
        result = await _attemptOfflineLogin();
        isOfflineLogin = true;
      }

      if (result != null && result['error'] != true) {
        // Login exitoso (online u offline)
        await _perfilUsuarioService.guardarDatosUsuario(result);
        
        if (isOfflineLogin) {
          setState(() {
            _syncStatus = 'Acceso offline exitoso';
          });
          
          // Pequeña pausa para mostrar el mensaje
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          // Sincronización solo para login online
          setState(() {
            _syncStatus = 'Sincronizando...';
          });
          
          await SyncService.syncAfterLogin(
            immediate: false,
            onProgress: (status) {
              if (mounted) {
                setState(() {
                  _syncStatus = status;
                });
              }
            },
          );
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Login fallido - verificar si hay credenciales offline
        final hasOfflineCredentials = await OfflineAuthService.hasOfflineCredentials();
        String errorMessage = result?['message'] ?? "Usuario y/o contraseña incorrectos";
        
        if (hasOfflineCredentials) {
          errorMessage += "\n\nTienes credenciales guardadas para acceso offline.";
        }
        
        setState(() {
          _generalError = errorMessage;
        });
      }
    } catch (e) {
      setState(() {
        _generalError = 'Error inesperado: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  /// Intenta realizar login offline
  Future<Map<String, dynamic>?> _attemptOfflineLogin() async {
    try {
      final result = await OfflineAuthService.authenticateOffline(
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // Si el login offline fue exitoso, actualizar el timestamp de última sesión
      if (result != null && result['error'] != true) {
        await OfflineAuthService.updateLastSessionTimestamp();
      }
      
      return result;
    } catch (e) {
      return {'error': true, 'message': 'Error al intentar autenticar offline: $e'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          LayoutBuilder(
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
                            const Text(
                              'Iniciar sesión',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontWeight: FontWeight.w700,
                                fontSize: 35,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 50),
                            
                            // Mensaje de error general (credenciales incorrectas)
                            if (_generalError != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  border: Border.all(color: Colors.red.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red.shade600,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _generalError!,
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 14,
                                          fontFamily: 'Satoshi',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            
                            CustomInput(
                              label: 'Usuario',
                              hint: 'Ingresa tu usuario',
                              controller: _emailController,
                              obscureText: false,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(Icons.person_outline),
                              errorText: _emailError,
                              onChanged: (_) {
                                if (_emailError != null) {
                                  setState(() {
                                    _emailError = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            CustomInput(
  label: 'Contraseña',
  hint: 'Ingresa tu contraseña',
  controller: _passwordController,
  obscureText: _obscurePassword,
  prefixIcon: const Icon(Icons.lock_outline),
  suffixIcon: IconButton(
    icon: Icon(
      _obscurePassword ? Icons.visibility_off : Icons.visibility,
      color: const Color(0xFF98774A), // mantiene tu color de diseño
    ),
    onPressed: () {
      setState(() {
        _obscurePassword = !_obscurePassword;
      });
    },
  ),
  errorText: _passwordError,
  onChanged: (_) {
    if (_passwordError != null) {
      setState(() {
        _passwordError = null;
      });
    }
  },
),

                            Row(
  children: [
Row(
  children: [
    Checkbox(
      value: _rememberMe,
      onChanged: (value) {
        setState(() {
          _rememberMe = value ?? false;
        });
      },
      activeColor: const Color(0xFF98774A), // tu color de diseño
    ),
    const Text(
      "Mantener sesión activa",
      style: TextStyle(
        fontFamily: 'Satoshi',
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    ),
  ],
),


  ],
),
const SizedBox(height: 30),
                            const SizedBox(height: 50),
                            CustomButton(
                              text: 'Ingresar', // Texto fijo siempre
                              onPressed: _isLoading ? null : _handleLogin, // Se deshabilita durante carga
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
                                    builder: (context) => const ForgotPasswordScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
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
          // Overlay de carga con animación - pantalla completa
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF181E34).withOpacity(0.95), // Azul oscuro
                      const Color(0xFF06115B).withOpacity(0.95), // Azul más oscuro
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Contenedor con efecto glassmorphism
                      Container(
                        padding: const EdgeInsets.all(40),
                        margin: const EdgeInsets.symmetric(horizontal: 40),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF98774A).withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Indicador de carga circular con colores de marca
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF98774A), // Dorado
                                    const Color(0xFFD6B68A), // Dorado claro
                                  ],
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  backgroundColor: Colors.white.withOpacity(0.3),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            // Texto de carga
                            const Text(
                              'Cargando',
                              style: TextStyle(
                                fontFamily: 'Satoshi',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            // Indicador de puntos animados
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (index) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF98774A).withOpacity(0.7),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}