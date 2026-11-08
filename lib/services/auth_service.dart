import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Gerencia toda a lógica de autenticação com Firebase Auth.
/// Extende [ChangeNotifier] para que o Provider notifique a UI
/// sempre que o estado de login mudar.
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Retorna o usuário atualmente logado (ou null se deslogado)
  User? get currentUser => _auth.currentUser;

  // ──────────────────────────────────────────────
  // CADASTRO
  // ──────────────────────────────────────────────

  /// Cria uma nova conta com e-mail e senha.
  /// Retorna null em caso de sucesso, ou a mensagem de erro.
  Future<String?> signUp({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return null; // sucesso
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    }
  }

  // ──────────────────────────────────────────────
  // LOGIN
  // ──────────────────────────────────────────────

  /// Faz login com e-mail e senha.
  /// Retorna null em caso de sucesso, ou a mensagem de erro.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      notifyListeners();
      return null; // sucesso
    } on FirebaseAuthException catch (e) {
      return _mapFirebaseError(e.code);
    }
  }

  // ──────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // HELPER: traduz códigos de erro do Firebase
  // ──────────────────────────────────────────────
  String _mapFirebaseError(String code) => mapFirebaseAuthError(code);

  /// Traduz o código de erro do Firebase Auth. Estático para ser testável
  /// sem instanciar o FirebaseAuth.
  static String mapFirebaseAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
        return 'Senha incorreta.';
      // SDKs atuais (proteção contra enumeração de e-mails) devolvem este
      // código no lugar de user-not-found / wrong-password.
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Verifique e tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Ocorreu um erro. Tente novamente.';
    }
  }
}
