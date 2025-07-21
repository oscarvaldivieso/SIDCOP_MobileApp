import 'dart:async';
import 'package:flutter/material.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_background.dart';
import '../../screens/auth/reset_password_screen.dart';
import '../../../services/user_verification_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final int userId;
  final String username;
  
  const VerifyEmailScreen({
    super.key, 
    required this.email,
    required this.userId,
    required this.username,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _codeControllers = List.generate(5, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(5, (_) => FocusNode());
  String? _error;
  late Timer _timer;
  int _countdown = 30; // 30 segundos de cuenta regresiva
  
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    for (var controller in _codeControllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _countdown = 30; // Reiniciar a 30 segundos
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        _timer.cancel();
      }
    });
  }
  
  String get _verificationCode => _codeControllers.map((c) => c.text).join();
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
                      padding: const EdgeInsets.only(top: 0.0, left: 16.0, right: 16.0, bottom: 8.0),
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
                                  borderRadius: BorderRadius.circular(12)
                                ),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
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

                                      ],
                                    ),
                                   Container(
                                      width: 110,
                                      height: 110,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Image.asset(
                                        'assets/mark_email_unread.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const Text(
                                      'Ingresa el código que \n enviamos a tu correo',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Se envió el código al correo \n asociado al usuario',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 24),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: List.generate(5, (index) => 
                                        Container(
                                          width: 50,
                                          height: 60,
                                          margin: const EdgeInsets.symmetric(horizontal: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: _error != null ? Colors.red : Colors.grey),
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.grey[100],
                                          ),
                                          child: TextField(
                                            controller: _codeControllers[index],
                                            focusNode: _focusNodes[index],
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            maxLength: 1,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            decoration: const InputDecoration(
                                              counterText: '',
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (value) {
                                              setState(() {
                                                _error = null;
                                              });
                                              
                                              if (value.isNotEmpty) {
                                                if (index < 4) {
                                                  _focusNodes[index + 1].requestFocus();
                                                } else {
                                                  // Last box, remove focus
                                                  _focusNodes[index].unfocus();
                                                }
                                              } else if (value.isEmpty && index > 0) {
                                                // Move to previous box on backspace
                                                _focusNodes[index - 1].requestFocus();
                                              }
                                            },
                                            onTap: () {
                                              // Select all text when tapping on a box
                                              _codeControllers[index].selection = TextSelection(
                                                baseOffset: 0,
                                                extentOffset: _codeControllers[index].text.length,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_error != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    const SizedBox(height: 24),
                                    CustomButton(
                                      text: 'Confirmar',
                                      onPressed: () async {
                                        if (_verificationCode.length < 5) {
                                          setState(() {
                                            _error = 'Por favor ingresa el código de 5 dígitos';
                                          });
                                          return;
                                        }

                                        // Validar el código ingresado
                                        final isValid = UserVerificationService.validateVerificationCode(
                                          _verificationCode,
                                          widget.email, // Pasar el email para validación
                                        );
                                        
                                        if (isValid) {
                                          // Código válido, navegar a la pantalla de restablecimiento de contraseña
                                          if (!mounted) return;
Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => ResetPasswordScreen(
                                                userId: widget.userId,
                                                email: widget.email,
                                                username: widget.username,
                                              ),
                                            ),
                                          );
                                        } else {
                                          // Código inválido
                                          setState(() {
                                            _error = 'Código incorrecto. Por favor, inténtalo de nuevo.';
                                          });
                                        }
                                      },
                                      width: MediaQuery.of(context).size.width * 0.6,
                                      
                                      height: 48,
                                    ),
                                    const SizedBox(height: 24),
                                     GestureDetector(
                                      onTap: _countdown == 0 ? () async {
                                        // Reenviar el código de verificación
                                        final email = widget.email;
                                        final codeSent = await UserVerificationService.sendVerificationCode(email);
                                        
                                        if (codeSent) {
                                          _startTimer();
                                        } else {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Error al reenviar el código. Intente nuevamente.'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } : null,
                                      child: Text(
                                        _countdown > 0 
                                          ? 'Reenviar código en 00:${_countdown.toString().padLeft(2, '0')}'
                                          : 'Reenviar código',
                                        style: TextStyle(
                                          fontFamily: 'Satoshi',
                                          fontWeight: FontWeight.w400, 
                                          fontSize: 14,
                                          color: _countdown > 0 ? Colors.grey : const Color.fromARGB(255, 38, 43, 64,),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 30),
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