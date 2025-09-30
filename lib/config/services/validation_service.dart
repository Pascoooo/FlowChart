import 'package:project_repository/project_repository.dart';

import '../constants/themes.dart';

class ValidationService {
  /// Valida il nome di un progetto, gestendo creazione e rinomina.
  ///
  /// Restituisce una stringa di errore se la validazione fallisce, altrimenti `null`.
  /// [currentProjectId] è l'ID del progetto che si sta rinominando (se applicabile).
  static String? validateProjectName(
      String? value, List<MyProject> existingProjects,
      [String? currentProjectId]) {
    if (value == null || value.trim().isEmpty) {
      return 'Il nome non può essere vuoto';
    }

    final trimmedValue = value.trim();
    final normalizedValue = trimmedValue.toLowerCase();

    // 2. Controllo lunghezza massima
    if (trimmedValue.length > AppConstants.maxProjectNameLength) {
      return 'Nome troppo lungo (max ${AppConstants.maxProjectNameLength} caratteri)';
    }

    // 3. Controllo caratteri non validi
    if (RegExp(r'[<>:"/\\|?*]').hasMatch(trimmedValue)) {
      return 'Il nome contiene caratteri non validi';
    }

    // 4. Rinominando: permettiamo lo stesso nome corrente senza errore
    if (currentProjectId != null) {
      final currentProject = existingProjects.firstWhere(
            (p) => p.projectId == currentProjectId,
      );
      if (currentProject.name.toLowerCase() == normalizedValue) {
        return null; // Nessuna modifica: non bloccare il pulsante Conferma
      }
    }

    final isDuplicate = existingProjects.any((p) =>
    p.projectId != currentProjectId &&
        p.name.toLowerCase() == normalizedValue);

    if (isDuplicate) {
      return 'Nome già in uso';
    }

    return null; // Validazione superata
  }
}