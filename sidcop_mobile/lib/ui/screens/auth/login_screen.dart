import 'package:flutter/material.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../auth/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  final ScrollController? scrollController;
  const LoginScreen({super.key, this.scrollController});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: widget.scrollController,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 0.0, left: 16.0, right: 16.0, bottom: 8.0),
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
                        label: 'Correo electrónico',
                        hint: 'Ingresa tu correo',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(Icons.email_outlined),
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
                        text: 'Ingresar',
                        onPressed: () {
                          // Aquí iría la lógica de login
                          if (_emailController.text.isEmpty && _passwordController.text.isEmpty) {
                            setState(() {
                              _error = 'Completa ambos campos';
                            });
                          } else {
                            // Autenticación
                          }
                        },
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
                            MaterialPageRoute(builder: (context) => ForgotPasswordScreen()),
                          );
                        },
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: const TextStyle(
                            color: Color(0xFF98774A),
                            fontFamily: 'Satoshi',
                            fontWeight: FontWeight.w700,
                            fontSize: 16
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
    );
  }
}