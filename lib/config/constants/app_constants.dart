class AppConstants {
  static const double projectContainerWidth = 900;
  static const double projectContainerHeight = 500;
  static const int maxProjectNameLength = 20;
  static const int projectsPerPage = 3;
  static const Duration animationDuration = Duration(milliseconds: 800);
  static const Duration staggerDelay = Duration(milliseconds: 100);

  // Regione Firebase Functions per le chiamate HTTP.
  static const String kFunctionsRegion = 'europe-west8';

  // Scope di Google Drive per consentire la creazione di file.
  static const String kDriveScope = 'https://www.googleapis.com/auth/drive.file';

  // Nome della Cloud Function per l'eliminazione dell'utente.
  static const String kDeleteUserFunctionName = 'deleteUserAuthHttp';

  // Durata massima per le richieste API prima di un timeout.
  static const Duration kApiTimeoutDuration = Duration(seconds: 15);
}

