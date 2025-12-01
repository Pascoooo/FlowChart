/// Entity che rappresenta i dati di un file nel formato Firestore.
/// Utilizzata per serializzare/deserializzare documenti dalla subcollection 'files'.
/// Separa il livello di persistenza dal modello di dominio (MyFile).
class MyFileEntity {
  final String fileId;
  final String name;
  final String content;

  MyFileEntity({
    required this.fileId,
    required this.name,
    required this.content,
  });

  /// Crea un'istanza di MyFileEntity da un documento Firestore.
  /// Deserializza la mappa in un'entity con cast espliciti per type safety.
  static MyFileEntity fromDocument(Map<String, dynamic> json) {
    return MyFileEntity(
      fileId: json['fileId'] as String,
      name: json['name'] as String,
      content: json['content'] as String,
    );
  }

  /// Converte MyFileEntity in una mappa per la scrittura su Firestore.
  /// Serializza tutti i campi nel formato compatibile con il database.
  Map<String, dynamic> toDocument() {
    return {
      'fileId': fileId,
      'name': name,
      'content': content,
    };
  }
}
