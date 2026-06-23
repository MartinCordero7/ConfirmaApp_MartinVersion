import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/usuario.dart';

/// Excepción especial: el usuario es nuevo en Google Sign-In y necesita elegir un rol.
class NeedsRoleSelectionException implements Exception {
  final String uid;
  final String nombre;
  final String email;
  const NeedsRoleSelectionException({required this.uid, required this.nombre, required this.email});
}

class FirebaseAuthRepository implements AuthRepository {
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Usuario? _userFromFirebase(auth.User? user, Map<String, dynamic>? data) {
    if (user == null || data == null) return null;
    return Usuario(
      id: user.uid,
      nombre: data['nombre'] ?? '',
      email: user.email ?? '',
      rol: data['rol'] == 'organizador' ? RolUsuario.organizador : RolUsuario.participante,
      biometriaRegistrada: data['biometriaRegistrada'] ?? false,
      fotoBiometriaUrl: data['fotoBiometriaUrl'],
    );
  }

  @override
  Future<Usuario?> login(String email, String password) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
      final doc = await _firestore.collection('usuarios').doc(credential.user!.uid).get();
      return _userFromFirebase(credential.user, doc.data());
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error de autenticación');
    }
  }

  @override
  Future<Usuario?> loginWithGoogle({String? rol}) async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // usuario canceló

      final googleAuth = await googleUser.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      final user = userCredential.user!;

      final docRef = _firestore.collection('usuarios').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        if (rol == null) {
          // Usuario nuevo sin rol: pedir selección en la UI
          throw NeedsRoleSelectionException(
            uid: user.uid,
            nombre: user.displayName ?? googleUser.email.split('@')[0],
            email: user.email ?? '',
          );
        }
        // Crear perfil con el rol elegido
        await docRef.set({
          'nombre': user.displayName ?? googleUser.email.split('@')[0],
          'email': user.email ?? '',
          'rol': rol,
          'biometriaRegistrada': false,
        });
      }

      final updatedDoc = await docRef.get();
      return _userFromFirebase(user, updatedDoc.data());
    } on NeedsRoleSelectionException {
      rethrow; // dejar que la UI lo maneje
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error al iniciar sesión con Google');
    } catch (e) {
      throw Exception('Error al iniciar sesión con Google: $e');
    }
  }

  @override
  Future<void> logout() async {
    await GoogleSignIn().signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<Usuario?> getCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('usuarios').doc(user.uid).get();
    return _userFromFirebase(user, doc.data());
  }

  @override
  Future<void> registrarUsuario(Usuario usuario, String password) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(email: usuario.email, password: password);
      await _firestore.collection('usuarios').doc(credential.user!.uid).set({
        'nombre': usuario.nombre,
        'email': usuario.email,
        'rol': usuario.rol == RolUsuario.organizador ? 'organizador' : 'participante',
        'biometriaRegistrada': usuario.biometriaRegistrada,
      });
    } on auth.FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Error al registrar usuario');
    }
  }

  @override
  Future<void> registrarBiometria(String userId) async {
    await _firestore.collection('usuarios').doc(userId).update({
      'biometriaRegistrada': true,
    });
  }

  @override
  Future<void> registrarBiometriaConFoto(String userId, File foto) async {
    // 1. Subir foto a Firebase Storage
    final ref = FirebaseStorage.instance.ref().child('biometria/$userId.jpg');
    
    // Leemos los bytes para evitar problemas de permisos de archivo en Android
    final bytes = await foto.readAsBytes();
    
    // Usamos UploadTask explícitamente para asegurar que termine
    final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    
    // Esperamos a que la subida esté 100% completada
    final snapshot = await uploadTask;
    
    // Obtenemos la URL directamente de la referencia que acaba de subirse
    final url = await snapshot.ref.getDownloadURL();

    // 2. Actualizar Firestore
    await _firestore.collection('usuarios').doc(userId).update({
      'biometriaRegistrada': true,
      'fotoBiometriaUrl': url,
    });
  }
}
