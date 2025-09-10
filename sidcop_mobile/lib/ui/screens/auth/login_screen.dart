import 'package:flutter/material.dart';
import 'dart:ui';
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

  // Método estático para limpiar completamente la sesión offline (accesible desde otras clases)
  // Usado cuando el usuario cierra sesión explícitamente
  static Future<void> clearSavedCredentials() async {
    await OfflineAuthService.clearOfflineSession();
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

  // Global loading dialog state and palette
  bool _isShowingGlobalLoading = false;
  final Color _primaryColor = const Color(0xFF141A2F);
  final Color _secondaryColor = const Color(0xFF1E2746);
  final Color _accentGold = const Color(0xFFD6B68A);
  final Color _lightGold = const Color(0xFFF1E8D0);

  // Connectivity listener
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      if (result != ConnectivityResult.none) {
        // Connectivity restored, sync offline orders
        _syncOfflineOrders();
      }
    });
  }

  Future<void> _syncOfflineOrders() async {
    try {
      print('Conectividad restaurada, sincronizando pedidos offline...');

      // Check if there are pending orders to sync
      final pedidosPendientes =
          await PedidosScreenOffline.obtenerPedidosPendientes();

      if (pedidosPendientes.isNotEmpty) {
        print(
          'Encontrados ${pedidosPendientes.length} pedidos pendientes para sincronizar',
        );

        // Show sync notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Sincronizando ${pedidosPendientes.length} pedidos offline...',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Sync the orders
        await PedidosScreenOffline.sincronizarPedidosPendientes();

        // Show success notification
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Pedidos sincronizados exitosamente!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }

        print('Sincronización de pedidos completada');
      } else {
        print('No hay pedidos pendientes para sincronizar');
      }
    } catch (e) {
      print('Error sincronizando pedidos offline: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sincronizando pedidos: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
        _syncStatus = hasConnection
            ? 'Restaurando sesión...'
            : 'Restaurando sesión offline...';
      });

      try {
        Map<String, dynamic>? result;

        if (hasConnection) {
          // Intentar auto-login online con credenciales guardadas
          final prefs = await SharedPreferences.getInstance();
          final savedEmail = prefs.getString('saved_email') ?? '';
          final savedPassword = prefs.getString('saved_password') ?? '';

          try {
            result = await _usuarioService.iniciarSesion(
              savedEmail,
              savedPassword,
            );

            if (result != null && result['error'] != true) {
              // Actualizar credenciales offline con datos frescos
              await OfflineAuthService.saveOfflineCredentials(
                username: savedEmail,
                password: savedPassword,
                userData: result,
              );
              await OfflineAuthService.updateLastOnlineLogin();

              // Cachear datos de pedidos y productos en background (no bloquear UI)
              setState(() {
                _syncStatus = 'Finalizando...';
              });
              // Ejecutar caché en background sin bloquear
              InicioSesionOfflineService.cachearDatosInicioSesion(result).catchError((e) {
                print('Error en caché background durante auto-login: $e');
              });
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
            // Sincronización en background para login online
            setState(() {
              _syncStatus = 'Finalizando...';
            });

            // Ejecutar sincronización en background sin bloquear UI
            SyncService.syncAfterLogin(
              immediate: false,
              onProgress: null, // No actualizar UI desde background
            ).catchError((e) {
              print('Error en sincronización background: $e');
            });
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
            // Auto-login online exitoso - SIEMPRE actualizar credenciales permanentes
            await OfflineAuthService.saveOfflineCredentials(
              username: _emailController.text.trim(),
              password: _passwordController.text,
              userData: result,
            );
            await OfflineAuthService.updateLastOnlineLogin();

            // Cachear datos de pedidos y productos en background (no bloquear UI)
            setState(() {
              _syncStatus = 'Finalizando...';
            });
            // Ejecutar caché en background sin bloquear
            InicioSesionOfflineService.cachearDatosInicioSesion(result).catchError((e) {
              print('Error en caché background durante auto-login manual: $e');
            });
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

          // Reducir pausa para login offline más rápido
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          // Sincronización en background para login online
          setState(() {
            _syncStatus = 'Finalizando...';
          });

          // Ejecutar sincronización en background sin bloquear UI
          SyncService.syncAfterLogin(
            immediate: false,
            onProgress: null, // No actualizar UI desde background
          ).catchError((e) {
            print('Error en sincronización background durante login: $e');
          });
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

  // Guardar credenciales PERMANENTES (siempre se guardan, independiente del checkbox)
  Future<void> _saveCredentials({Map<String, dynamic>? userData}) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // SIEMPRE guardar credenciales permanentes para acceso offline
    if (userData != null) {
      await OfflineAuthService.saveOfflineCredentials(
        username: email,
        password: password,
        userData: userData,
      );
    }

    // Guardar también las preferencias de "Remember me" para auto-login
    await OfflineAuthService.saveOfflineSessionPreference(
      username: email,
      password: password,
      rememberMe: _rememberMe,
      userData: userData,
    );
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

      if (hasConnection) {
        // Intentar login online primero
        setState(() {
          _syncStatus = 'Conectando al servidor...';
        });

        try {
          result = await _usuarioService.iniciarSesion(email, password);

          if (result != null && result['error'] != true) {
            // Login online exitoso - SIEMPRE guardar credenciales permanentes
            await OfflineAuthService.saveOfflineCredentials(
              username: email,
              password: password,
              userData: result,
            );

            // Guardar también las preferencias de "Remember me" para auto-login
            await _saveCredentials(userData: result);

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
          
          // Si el login offline fue exitoso, guardar credenciales
          if (result != null && result['error'] != true) {
            await _saveCredentials(userData: result);
          }
        }
      } else {
        // Sin conexión - usar login offline directamente
        setState(() {
          _syncStatus = 'Modo offline - Verificando credenciales...';
        });

        result = await _attemptOfflineLogin();
        isOfflineLogin = true;
        
        // Si el login offline fue exitoso, guardar credenciales
        if (result != null && result['error'] != true) {
          await _saveCredentials(userData: result);
        }
      }

      if (result != null && result['error'] != true) {
        // Login exitoso (online u offline)
        await _perfilUsuarioService.guardarDatosUsuario(result);

        if (isOfflineLogin) {
          setState(() {
            _syncStatus = 'Acceso offline exitoso';
          });

          // Reducir pausa para login offline más rápido
          await Future.delayed(const Duration(milliseconds: 500));
        } else {
          // Sincronización en background para login online
          setState(() {
            _syncStatus = 'Finalizando...';
          });

          // Ejecutar sincronización en background sin bloquear UI
          SyncService.syncAfterLogin(
            immediate: false,
            onProgress: null, // No actualizar UI desde background
          ).catchError((e) {
            print('Error en sincronización background durante login: $e');
          });
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Login fallido - verificar si hay credenciales offline
        final hasOfflineCredentials =
            await OfflineAuthService.hasOfflineCredentials();
        String errorMessage =
            result?['message'] ?? "Usuario y/o contraseña incorrectos";

        if (hasOfflineCredentials) {
          errorMessage +=
              "\n\nTienes credenciales guardadas para acceso offline.";
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
      return {
        'error': true,
        'message': 'Error al intentar autenticar offline: $e',
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sincronizar el diálogo global de carga después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isLoading && !_isShowingGlobalLoading) {
        _showGlobalLoading();
      } else if (!_isLoading && _isShowingGlobalLoading) {
        _hideGlobalLoading();
      }
    });
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
                                  border: Border.all(
                                    color: Colors.red.shade300,
                                  ),
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
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: const Color(
                                    0xFF98774A,
                                  ), // mantiene tu color de diseño
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
                                      activeColor: const Color(
                                        0xFF98774A,
                                      ), // tu color de diseño
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
                              onPressed: _isLoading
                                  ? null
                                  : _handleLogin, // Se deshabilita durante carga
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
                                    builder: (context) =>
                                        const ForgotPasswordScreen(),
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
          // Nota: el overlay local se reemplaza por un diálogo global mostrado con
          // useRootNavigator: true para cubrir toda la pantalla (incluyendo onboarding)
        ],
      ),
    );
  }

  // Muestra un diálogo full-screen usando el root navigator para cubrir toda la app
  void _showGlobalLoading() {
    if (_isShowingGlobalLoading) return;
    _isShowingGlobalLoading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                // Frosted blur behind the dialog to integrate with onboarding
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
                  child: Container(color: Colors.transparent),
                ),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1.0),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 20,
                      ),
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _primaryColor.withOpacity(0.98),
                            _secondaryColor.withOpacity(0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.45),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Circular indicator with icon
                          SizedBox(
                            width: 88,
                            height: 88,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 6,
                                    backgroundColor:
                                        Colors.white.withOpacity(0.06),
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(_accentGold),
                                  ),
                                ),
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.local_shipping_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _syncStatus.isNotEmpty
                                ? _syncStatus
                                : 'Iniciando sesión...',
                            style: const TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Por favor espere',
                            style: TextStyle(
                              fontFamily: 'Satoshi',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: _lightGold.withOpacity(0.95),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          // subtle progress dots row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              return AnimatedContainer(
                                duration: Duration(
                                  milliseconds: 450 + (index * 80),
                                ),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _accentGold.withOpacity(0.85),
                                ),
                              );
                            }),
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
      },
    ).then((_) {
      // Cuando el diálogo se cierra por cualquier razón, marcar como no visible
      _isShowingGlobalLoading = false;
    });
  }

  void _hideGlobalLoading() {
    if (!_isShowingGlobalLoading) return;
    try {
      Navigator.of(context, rootNavigator: true).pop();
    } catch (_) {}
    _isShowingGlobalLoading = false;
  }
}
