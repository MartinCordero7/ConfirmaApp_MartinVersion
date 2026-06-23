import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/login_viewmodel.dart';
import '../../domain/entities/usuario.dart';
import '../layouts/main_layout_organizador.dart';
import '../layouts/main_layout_participante.dart';
import 'tomar_selfie_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nombreController = TextEditingController();
  bool _isLogin = true;
  bool _obscureText = true;
  RolUsuario _rolSeleccionado = RolUsuario.participante;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nombreController.dispose();
    super.dispose();
  }

  void _submit() async {
    final viewModel = context.read<LoginViewModel>();
    try {
      if (_isLogin) {
        await viewModel.login(_emailController.text.trim(), _passwordController.text.trim());
      } else {
        await viewModel.register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _nombreController.text.trim(),
          _rolSeleccionado,
        );

        if (_rolSeleccionado == RolUsuario.participante && mounted) {
          final registrar = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('¡Registro Exitoso!'),
              content: const Text('Para acceder a eventos de nivel "Estricto", necesitas registrar tu rostro.\n\n¿Deseas registrar tu biometría ahora? (También puedes hacerlo después en tu Perfil).'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Más tarde')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar ahora')),
              ],
            ),
          );

          if (registrar == true && mounted) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const TomarSelfieScreen()));
          }
        }
      }

      if (viewModel.currentUser != null && mounted) {
        final user = viewModel.currentUser!;
        if (user.rol == RolUsuario.organizador) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayoutOrganizador()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayoutParticipante()));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.errorMessage ?? 'Error desconocido'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _loginWithGoogle() async {
    final viewModel = context.read<LoginViewModel>();
    try {
      final success = await viewModel.loginWithGoogle();
      if (!mounted) return;

      if (success && viewModel.currentUser != null) {
        final user = viewModel.currentUser!;
        if (user.rol == RolUsuario.organizador) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayoutOrganizador()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayoutParticipante()));
        }
      } else if (viewModel.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(viewModel.errorMessage!), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<LoginViewModel>();

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_scanner, size: 80, color: Color(0xFF2563EB)),
              const SizedBox(height: 24),
              Text(_isLogin ? 'Iniciar Sesión' : 'Registro', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (!_isLogin) ...[
                TextField(controller: _nombreController, decoration: InputDecoration(labelText: 'Nombre completo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Correo electrónico', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<RolUsuario>(
                  value: _rolSeleccionado,
                  items: RolUsuario.values.map((rol) => DropdownMenuItem(value: rol, child: Text(rol.name.toUpperCase()))).toList(),
                  onChanged: (val) => setState(() => _rolSeleccionado = val!),
                  decoration: InputDecoration(labelText: 'Rol', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _submit,
                        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: Text(_isLogin ? 'Iniciar Sesión' : 'Registrarse', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLogin = !_isLogin;
                  });
                },
                child: Text(_isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia Sesión', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              if (_isLogin) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('O', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: viewModel.isLoading ? null : _loginWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFDADADA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      backgroundColor: Colors.white,
                    ),
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 22,
                      errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 22),
                    ),
                    label: const Text(
                      'Continuar con Google',
                      style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Admin: admin@test.com / 123456\nParticipante: user@test.com / 123456', 
                textAlign: TextAlign.center, 
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
