import 'dart:io';
import '../../domain/entities/usuario.dart';
import '../../domain/repositories/auth_repository.dart';

class MockAuthRepository implements AuthRepository {
  Usuario? _currentUser;
  
  final List<Map<String, dynamic>> _usersDB = [
    {'email': 'admin@test.com', 'password': '123456', 'user': Usuario(id: 'org_1', nombre: 'Admin Organizador', email: 'admin@test.com', rol: RolUsuario.organizador)},
    {'email': 'user@test.com', 'password': '123456', 'user': Usuario(id: 'part_1', nombre: 'Juan Participante', email: 'user@test.com', rol: RolUsuario.participante)},
  ];

  @override
  Future<Usuario?> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));

    final userMap = _usersDB.cast<Map<String,dynamic>?>().firstWhere(
      (u) => u?['email'] == email && u?['password'] == password,
      orElse: () => null,
    );

    if (userMap != null) {
      _currentUser = userMap['user'];
      return _currentUser;
    }
    
    throw Exception('Credenciales inválidas. Usa admin@test.com o user@test.com con clave 123456, o regístrate.');
  }

  @override
  Future<Usuario?> loginWithGoogle({String? rol}) async {
    await Future.delayed(const Duration(seconds: 1));
    _currentUser = Usuario(
      id: 'google_mock_1',
      nombre: 'Usuario Google',
      email: 'google@test.com',
      rol: rol == 'organizador' ? RolUsuario.organizador : RolUsuario.participante,
      biometriaRegistrada: false,
    );
    return _currentUser;
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  Future<Usuario?> getCurrentUser() async {
    return _currentUser;
  }

  @override
  Future<void> registrarUsuario(Usuario usuario, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (_usersDB.any((u) => u['email'] == usuario.email)) {
      throw Exception('El correo ya está registrado.');
    }
    _usersDB.add({'email': usuario.email, 'password': password, 'user': usuario});
  }

  @override
  Future<void> registrarBiometria(String userId) async {
    // Mock: no hace nada en memoria
  }

  @override
  Future<void> registrarBiometriaConFoto(String userId, File foto) async {
    // Mock: no hace nada en memoria
  }
}
