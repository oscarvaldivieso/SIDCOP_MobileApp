import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../../services/UsuarioService.dart';
import '../../../services/perfil_usuario_service.dart';
import '../../../services/SyncService.dart';
import '../../../services/OfflineAuthService.dart';
import '../../screens/auth/forgot_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LoginScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const LoginScreen({super.key, this.scrollController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();

  // Método estático para limpiar credenciales guardadas (accesible desde otras clases)
  static Future<void> clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_me');
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
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

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  // Verificar si hay una sesión guardada
  Future<void> _checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('saved_email') ?? '';
      final savedPassword = prefs.getString('saved_password') ?? '';
      final rememberMe = prefs.getBool('remember_me') ?? false;
      
      // Cargar credenciales en los campos del formulario
      if (rememberMe && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _passwordController.text = savedPassword;
          _rememberMe = true;
        });
      }
      
      // Verificar si hay una sesión offline válida para auto-login directo
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
            try {
              // Usar las credenciales guardadas para iniciar sesión
              result = await _usuarioService.iniciarSesion(savedEmail, savedPassword);
              
              if (result != null && result['error'] != true) {
                // Actualizar credenciales offline con datos frescos
                await OfflineAuthService.saveOfflineCredentials(
                  username: savedEmail,
                  password: savedPassword,
                  userData: result,
                );
                await OfflineAuthService.updateLastOnlineLogin();
              }
            } catch (e) {
              // Si falla online, usar offline
              result = await OfflineAuthService.autoRestoreOfflineSession();
            }
          } else {
            // Sin conexión, usar offline
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
          developer.log('Error en auto-login: $e');
        }
        
        // Si llegamos aquí, el auto-login falló, mostrar pantalla normal
        if (mounted) {
          setState(() {
            _isLoading = false;
            _syncStatus = '';
          });
        }
      }
    } catch (e) {
      // Error general, continuar con pantalla de login normal
      developer.log('Error al verificar sesión guardada: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _syncStatus = '';
        });
      }
    }
  }

  // Maneja el inicio de sesión
  Future<void> _handleLogin() async {
    // Limpiar errores previos
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    // Validar campos individualmente
    bool hasError = false;

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'El campo Usuario es requerido';
      });
      hasError = true;
    }

    if (_passwordController.text.isEmpty) {
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
      
      if (hasConnection) {
        /// Intenta realizar login offline
        result = await _attemptOfflineLogin();
        isOfflineLogin = true;
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
        
        // Si fue login online exitoso, asegurar que se guarden credenciales offline
        if (!isOfflineLogin) {
          await OfflineAuthService.saveOfflineCredentials(
            username: _emailController.text.trim(),
            password: _passwordController.text,
            userData: result,
          );
          await OfflineAuthService.updateLastOnlineLogin();
        }
        
        // Guardar credenciales si "Remember me" está activado
        await _saveCredentials();
        
        if (isOfflineLogin) {
          setState(() {
            _syncStatus = 'Acceso offline exitoso';
          });
          
          // Pequeña pausa para mostrar el mensaje
          await Future.delayed(const Duration(milliseconds: 1500));
        } else {
          // Sincronización solo para login online
          setState(() {
            _syncStatus = 'Ingresando';
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
        // Login fallido
        final errorMessage = result?['message'] ?? "Usuario y/o contraseña incorrectos";
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
      // Primero intentar con las credenciales proporcionadas
      var result = await OfflineAuthService.authenticateOffline(
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // Si falla, intentar con cualquier credencial guardada
      if (result == null || result['error'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString('saved_email') ?? '';
        final savedPassword = prefs.getString('saved_password') ?? '';
        
        if (savedEmail.isNotEmpty && savedPassword.isNotEmpty) {
          result = await OfflineAuthService.authenticateOffline(
            username: savedEmail,
            password: savedPassword,
          );
        }
      }
      
      if (result != null && result['error'] != true) {
        // Intentar obtener los datos completos del usuario
        try {
          // Usar el método de login con isOffline: true para obtener los datos completos
          final userData = await _usuarioService.iniciarSesion(
            result['usua_Usuario'] ?? _emailController.text.trim(),
            _passwordController.text,
            isOffline: true,
          );
          
          if (userData != null && userData['error'] != true) {
            return {
              ...userData,
              'offline_login': true,
            };
          }
        } catch (e) {
          developer.log('Error al cargar datos completos del usuario: $e');
        }
        
        // Si no se pueden cargar los datos completos, devolver al menos los básicos
        return {
          ...result,
          'offline_login': true,
        };
      }
      return result;
    } catch (e) {
      developer.log('Error en login offline: $e');
      return {'error': true, 'message': 'Error al intentar acceso offline: $e'};
    }
  }

  // Guardar credenciales en SharedPreferences
  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      
      if (_rememberMe) {
        await prefs.setString('saved_email', _emailController.text.trim());
        await prefs.setString('saved_password', _passwordController.text);
        
        // Obtener los datos del usuario actuales o de la respuesta de login
        var userData = await _perfilUsuarioService.obtenerDatosUsuario();
        
        // Si no hay datos del perfil, intentar obtenerlos de la respuesta de login
        if (userData == null || userData.isEmpty) {
          final loginResult = await _usuarioService.iniciarSesion(
            _emailController.text.trim(),
            _passwordController.text,
            isOffline: true,
          );
          
          if (loginResult != null && loginResult['error'] != true) {
            userData = loginResult;
          }
        }
        
        // Guardar los datos del usuario para acceso offline
        if (userData != null) {
          await prefs.setString('offline_user_data', jsonEncode(userData));
          developer.log('Datos de usuario guardados para acceso offline');
        }
      } else {
        // No limpiar offline_user_data aquí para permitir acceso offline
        await prefs.remove('saved_email');
        await prefs.remove('saved_password');
      }
    } catch (e) {
      developer.log('Error al guardar credenciales: $e');
    }
  }

  // Handle back button press
  Future<bool> _onWillPop() async {
    if (!_isLoading) {
      Navigator.of(context).pop();
      return false;
    }
    return false; // Prevent back when loading
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
            // Back button
            if (widget.scrollController != null) // Only show back button if not in bottom sheet
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, top: 50),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
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
                              // Texto principal - Solo 'Cargando...'
                              const Text(
                                'Cargando...',
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
      ),
    );
  }
}