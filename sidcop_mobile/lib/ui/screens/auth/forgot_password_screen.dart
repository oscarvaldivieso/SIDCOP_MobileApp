import 'package:flutter/material.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_background.dart';
import '../auth/verify_email_screen.dart';
import '../../../services/user_verification_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  String? _error;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AuthBackground(),

          Material(
            color: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/eslogancompleto_Claro_SIDCOP 2.png',
                                  width: 200,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.pop(context);
                                          },
                                          child: const Icon(
                                            Icons.arrow_back_ios_new,
                                            size: 24,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const Text(
                                          '   Restablecer contraseña',
                                          style: TextStyle(
                                            fontFamily: 'Satoshi',
                                            fontWeight: FontWeight.w900,
                                            fontSize: 20,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Ingrese el usuario y recibirás un código para restablecer tu contraseña',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    CustomInput(
                                      label: 'Usuario:',
                                      hint: 'Ingresa tu usuario',
                                      controller: _emailController,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                    ),
                                    if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 4.0,
                                          left: 4.0,
                                        ),
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 20),
                                    CustomButton(
                                      text: _isLoading
                                          ? 'Cargando...'
                                          : 'Enviar',
                                      onPressed: _isLoading
                                          ? null
                                          : () async {
                                              if (_emailController
                                                  .text
                                                  .isEmpty) {
                                                setState(() {
                                                  _error = 'Ingresa tu usuario';
                                                });
                                                return;
                                              }

                                              setState(() {
                                                _error = null;
                                                _isLoading = true;
                                              });

                                              try {
                                                print(
                                                  'Verificando usuario: ${_emailController.text.trim()}',
                                                );
                                                final email =
                                                    await UserVerificationService.getUserEmail(
                                                      _emailController.text
                                                          .trim(),
                                                    );
                                                print('Email obtenido: $email');

                                                if (!mounted) return;

                                                if (email != null &&
                                                    email.isNotEmpty) {
                                                  // Obtener la respuesta completa del usuario para extraer el ID y username
                                                  final userResponse =
                                                      await UserVerificationService.verifyUser(
                                                        _emailController.text
                                                            .trim(),
                                                      );

                                                  if (userResponse == null ||
                                                      userResponse
                                                          .data
                                                          .isEmpty) {
                                                    setState(() {
                                                      _error =
                                                          'No se pudo obtener la información del usuario';
                                                      _isLoading = false;
                                                    });
                                                    return;
                                                  }

                                                  final userData =
                                                      userResponse.data.first;

                                                  // Enviar el código de verificación
                                                  final codeSent =
                                                      await UserVerificationService.sendVerificationCode(
                                                        email,
                                                      );

                                                  if (!mounted) return;

                                                  if (codeSent) {
                                                    // Navegar a la pantalla de verificación con los datos del usuario
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            VerifyEmailScreen(
                                                              email: email,
                                                              userId: userData
                                                                  .usuaId,
                                                              username:
                                                                  userData
                                                                      .usuaUsuario ??
                                                                  _emailController
                                                                      .text
                                                                      .trim(),
                                                            ),
                                                      ),
                                                    );
                                                  } else {
                                                    setState(() {
                                                      _error =
                                                          'Error al enviar el código de verificación. Intente nuevamente.';
                                                      _isLoading = false;
                                                    });
                                                  }
                                                } else {
                                                  setState(() {
                                                    _error =
                                                        'No se encontró un correo asociado a este usuario';
                                                  });
                                                }
                                              } catch (e) {
                                                print(
                                                  'Error al verificar el usuario: $e',
                                                );
                                                if (!mounted) return;
                                                setState(() {
                                                  _error =
                                                      'Error al verificar el usuario. Intenta de nuevo.';
                                                });
                                              } finally {
                                                if (mounted) {
                                                  setState(() {
                                                    _isLoading = false;
                                                  });
                                                }
                                              }
                                            },
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.6,
                                      height: 48,
                                    ),
                                    const SizedBox(height: 30),
                                    SizedBox(
                                      width: 200,
                                      height: 200,
                                      child: Image.asset(
                                        'assets/undraw_forgot-password_odai 1.png',
                                      ),
                                    ),
                                  ],
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
          ),
        ],
      ),
    );
  }
}
