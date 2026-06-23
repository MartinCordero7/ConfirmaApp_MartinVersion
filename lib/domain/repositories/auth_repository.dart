import '../entities/usuario.dart';
import 'dart:io';

abstract class AuthRepository {
  Future<Usuario?> login(String email, String password);
  Future<Usuario?> loginWithGoogle({String? rol});
  Future<void> logout();
  Future<Usuario?> getCurrentUser();
  Future<void> registrarUsuario(Usuario usuario, String password);
  Future<void> registrarBiometria(String userId);
  Future<void> registrarBiometriaConFoto(String userId, File foto);
}
