import 'package:flutter/material.dart';
import 'package:sidcop_mobile/ui/widgets/auth_background.dart';
import 'package:sidcop_mobile/services/user_verification_service.dart';
import 'package:sidcop_mobile/models/reset_password_request.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';

class ResetPasswordScreen extends StatefulWidget {
  final int userId;
  final String email;
  final String username;
  
  const ResetPasswordScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.username,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _verifyPassword = TextEditingController();
    String? _error;
    bool _isLoading = false;

  Future<void> _resetPassword() async {
    final password = _passwordController.text;
    final confirmPassword = _verifyPassword.text;

    // Validar que las contraseñas coincidan
    if (password != confirmPassword) {
      setState(() {
        _error = 'Las contraseñas no coinciden';
      });
      return;
    }

    // Validar longitud mínima de contraseña
    if (password.length < 6) {
      setState(() {
        _error = 'La contraseña debe tener al menos 6 caracteres';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final request = ResetPasswordRequest(
        usua_Id: widget.userId,
        usua_Usuario: widget.username,
        correo: widget.email,
        usua_Clave: password,
        usua_Modificacion: widget.userId, // Mismo que usua_Id
        usua_FechaModificacion: DateTime.now(),
      );

      final success = await UserVerificationService.resetPassword(request);

      if (!mounted) return;

      if (success) {
        // Mostrar mensaje de éxito y regresar al login
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contraseña actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      } else {
        setState(() {
          _error = 'Error al actualizar la contraseña. Por favor, intente nuevamente.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error inesperado. Por favor, intente nuevamente.';
      });
      print('Error resetting password: $e');
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
                                      obscureText: true,
                                      keyboardType: TextInputType.visiblePassword,
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
                                      obscureText: true,
                                      keyboardType: TextInputType.visiblePassword,
                                      onChanged: (_) {
                                        setState(() {
                                          _error = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 24),
                                    _isLoading
                                        ? const Center(child: CircularProgressIndicator())
                                        : CustomButton(
                                            text: 'Confirmar',
                                            onPressed: _resetPassword,
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