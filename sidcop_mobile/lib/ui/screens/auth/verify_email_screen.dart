import 'package:flutter/material.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/auth_background.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
      final TextEditingController _emailController = TextEditingController();
      String? _error;
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
                                      width: 200,
                                      height: 200,
                                      child: Image.asset(
                                        'assets/mark_email_unread.png',
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
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Se envió el código al correo \n asociado al usuario',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w400,
                                        fontSize: 14,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    CustomInput(
                                      label: 'Código:',
                                      hint: 'Ingresa el código',
                                      controller: _emailController,
                                      keyboardType: TextInputType.number,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                    ),
                                    if (_error != null) 
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4.0, left: 4.0),
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
                                      text: 'Enviar',
                                      onPressed: () {
                                        if (_emailController.text.isEmpty) {
                                          setState(() {
                                            _error = 'Ingresa el código';
                                          });
                                          return;
                                        }
                                        // Aquí iría la lógica para enviar el correo de recuperación
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const VerifyEmailScreen(),
                                          ),
                                        );
                                      },
                                      width: MediaQuery.of(context).size.width * 0.6,
                                      height: 48,
                                    ),
                                    const SizedBox(height: 30),
                                    Container(
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