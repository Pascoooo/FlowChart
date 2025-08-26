String mapAuthError(dynamic exception) {
  final errorCode = exception?.code ?? 'unknown';

  switch (errorCode) {
    case 'user-not-found':
      return 'Nessun utente trovato con questa email.';
    case 'wrong-password':
      return 'Password incorretta.';
    case 'email-already-in-use':
      return 'Questa email è già registrata.';
    case 'weak-password':
      return 'La password è troppo debole.';
    case 'invalid-email':
      return 'Email non valida.';
    case 'user-disabled':
      return 'Questo account è stato disabilitato.';
    case 'too-many-requests':
      return 'Troppi tentativi. Riprova più tardi.';
    case 'operation-not-allowed':
      return 'Operazione non consentita.';
    case 'network-request-failed':
      return 'Errore di connessione. Controlla la tua connessione internet.';
    case 'popup-closed-by-user':
      return 'Finestra di accesso chiusa dall\'utente.';
    case 'cancelled-popup-request':
      return 'Richiesta di accesso annullata.';
    default:
      return 'Si è verificato un errore imprevisto. Riprova.';
  }
}