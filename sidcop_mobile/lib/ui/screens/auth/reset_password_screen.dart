import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/auth_background.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../widgets/auth_background.dart';

class ResetPasswordScreen extends StatefulWidget {
  
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _verifyPassword = TextEditingController();
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
                                      width: 110,
                                      height: 110,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: Image.asset(
                                        'assets/Key.png',
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                    const Text(
                                      'Ingresa tu nueva \n contraseña',
                                      style: TextStyle(
                                        fontFamily: 'Satoshi',
                                        fontWeight: FontWeight.w900,
                                        fontSize: 20,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'ingrese la nueva contraseña y \n luego confirmela',
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
                                      CustomInput(
                                      label: 'Nueva contraseña',
                                      hint: '',
                                      controller: _passwordController,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                    ),
                                      CustomInput(
                                      label: 'Confirma tu contraseña',
                                      hint: '',
                                      controller: _verifyPassword,
                                      keyboardType: TextInputType.emailAddress,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    CustomButton(
                                      text: 'Confirmar',
                                      onPressed: () {
                                        // Aquí iría la lógica para enviar el correo de recuperación
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ResetPasswordScreen(),
                                          ),
                                        );
                                        
                                      },
                                      width: MediaQuery.of(context).size.width * 0.6,
                                      
                                      height: 48,
                                    ),
                                    const SizedBox(height: 24),
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