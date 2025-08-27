import '../entities/file_entity.dart';

class MyFile {
  final String fileId;
  final String name;
  final String content;

  const MyFile({
    required this.fileId,
    required this.name,
    required this.content,
  });

  // Costante statica per un'istanza vuota di MyFile.
  static const empty = MyFile(
    fileId: '',
    name: '',
    content: '',
  );

  // Converte un oggetto MyFile in un'entità (Entity).
  MyFileEntity toEntity() {
    return MyFileEntity(
      fileId: fileId,
      name: name,
      content: content,
    );
  }

  // Crea un oggetto MyFile da un'entità (Entity).
  static MyFile fromEntity(MyFileEntity entity) {
    return MyFile(
      fileId: entity.fileId,
      name: entity.name,
      content: entity.content,
    );
  }

  @override
  String toString() {
    return 'MyFile: $fileId, $name';
  }

  // Getter per verificare se l'istanza è vuota.
  bool get isEmpty => this == MyFile.empty;
}
