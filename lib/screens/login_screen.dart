import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isLogin = true; // true = iniciar sesión, false = registro

  // Muestra un mensaje deslizante en la parte inferior
  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // Traduce los códigos de error de Firebase a mensajes en español
  String _errorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo electrónico no es válido.';
      case 'user-not-found':
        return 'No existe ninguna cuenta con ese correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      default:
        return 'Ha ocurrido un error. Inténtalo de nuevo.';
    }
  }

  // Se ejecuta al pulsar el botón principal
  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (_isLogin) {
        await _authService.signIn(email, password);
      } else {
        await _authService.signUp(email, password, _nameController.text.trim());
      }
    } on FirebaseAuthException catch (e) {
      _showMessage(_errorMessage(e.code));
    } catch (e) {
      _showMessage('Ha ocurrido un error inesperado.');
    } finally {
      // Solo tocamos el estado si la pantalla sigue viva
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Alterna entre modo login y modo registro
  void _toggleMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sin AppBar: el contenido protagonista es el logo. SafeArea evita que
    // trepe hasta la barra de estado del móvil (hora, batería).
    return Scaffold(
      body: SafeArea(
        // LayoutBuilder nos da la altura disponible. Con ConstrainedBox +
        // IntrinsicHeight forzamos a la Column a ocupar TODA esa altura, y
        // centramos el contenido con Spacers arriba y abajo. Así el centro
        // es estable (la altura total no cambia) y el formulario no salta
        // al desplegar el campo Nombre.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),

                      // --- Logo (ya incluye el nombre "Pachanga") ---
                      Center(
                        child: SvgPicture.asset('assets/logo.svg', width: 280),
                      ),
                      const SizedBox(height: 28),

                      // --- Formulario ---
                      // El campo Nombre aparece/desaparece con una transición
                      // suave (AnimatedSize): el único movimiento del layout es
                      // elegante, no un salto brusco.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: _isLogin
                            ? const SizedBox(width: double.infinity)
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre',
                                  ),
                                ),
                              ),
                      ),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submit,
                              child: Text(
                                _isLogin ? 'Iniciar sesión' : 'Registrarse',
                              ),
                            ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _isLoading ? null : _toggleMode,
                        child: Text(
                          _isLogin
                              ? '¿No tienes cuenta? Regístrate'
                              : '¿Ya tienes cuenta? Inicia sesión',
                        ),
                      ),

                      const Spacer(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
