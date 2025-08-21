import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthErrorMapper {
  static const Map<String, String> _messages = {
    'email-already-in-use': 'Email già registrata. Vai al login.',
    'account-exists-with-google': 'Account già esistente con Google. Usa il login Google.',
    'account-exists-with-password': 'Account esistente con email/password. Fai login con email e password.',
    'weak-password': 'Password troppo debole.',
    'invalid-email': 'Email non valida.',
    'user-disabled': 'Utente disabilitato.',
    'user-not-found': 'Utente non trovato.',
    'wrong-password': 'Password errata.',
    'operation-not-allowed': 'Operazione non consentita.',
    'too-many-requests': 'Troppe richieste, riprova più tardi.',
    'network-request-failed': 'Problema di rete, riprova.',
  };

  static String fromFirebase(fb.FirebaseAuthException e) {
    return _messages[e.code] ?? (e.message ?? 'Errore sconosciuto');
  }
}