import 'models/models.dart';

abstract class FileRepo {
  /// Recupera tutti i file.
  Future<List<MyFile>> getFiles();

  /// Crea un nuovo file con il nome specificato.
  Future<void> createFile({required String name});

  /// Elimina il file con l'ID specificato.
  Future<void> deleteFile({required String fileId});

  /// Rinomina il file con l'ID specificato.
  Future<void> renameFile({required String fileId, required String newName});
}
