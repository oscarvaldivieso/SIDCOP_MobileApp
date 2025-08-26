import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/screens/home_screen.dart';

import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../../services/UsuarioService.dart';
import '../../../services/PerfilUsuarioService.Dart';
import '../../../services/SyncService.dart';
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
  
  // Errores individuales para cada campo
  String? _emailError;
  String? _passwordError;
  
  // Error general para credenciales incorrectas
  String? _generalError;
  bool _isLoading = false;
  String _syncStatus = '';
  bool _rememberMe = false;
  bool _obscurePassword = true; // true = oculto, false = visible

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
      final result = await _usuarioService.iniciarSesion(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (result != null && result['error'] != true) {
        // Login exitoso - guardar datos del usuario
        await _perfilUsuarioService.guardarDatosUsuario(result);
        
        // Sincronización
        setState(() {
          _syncStatus = 'Ingresando';
        });
        
        await SyncService.syncAfterLogin(
          immediate: false,  //que no demore el login
          onProgress: (status) {
            if (mounted) {
              setState(() {
                _syncStatus = status;
              });
            }
          },
        );
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        // Login fallido - mostrar error específico o genérico
        setState(() {
          _generalError = "Usuario y/o contraseña incorrectos";
        });
      }
    } catch (e) {
      setState(() {
        _generalError = 'Error de conexión: $e';
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
          
          // Overlay de carga con animación
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Indicador de carga circular animado
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 4,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _syncStatus.isNotEmpty ? _syncStatus : 'Iniciando sesión...',
                        style: const TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Por favor espere',
                        style: TextStyle(
                          fontFamily: 'Satoshi',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
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