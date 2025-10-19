import 'package:equatable/equatable.dart'; // ✨ 1. Importa il pacchetto Equatable
import '../entities/file_entity.dart';

// ✨ 2. Estendi Equatable per confronti affidabili
class MyFile extends Equatable {
  final String fileId;
  final String name;
  final String content;

  const MyFile({
    required this.fileId,
    required this.name,
    required this.content,
  });

  static const empty = MyFile(
    fileId: '',
    name: '',
    content: '',
  );

  // ✨ 3. AGGIUNTO IL METODO `copyWith`
  // Questo metodo è essenziale per la programmazione con stati immutabili (come in BLoC).
  // Crea una copia dell'oggetto, permettendo di modificare solo i campi desiderati.
  MyFile copyWith({
    String? fileId,
    String? name,
    String? content,
  }) {
    return MyFile(
      fileId: fileId ?? this.fileId,
      name: name ?? this.name,
      content: content ?? this.content,
    );
  }

  MyFileEntity toEntity() {
    return MyFileEntity(
      fileId: fileId,
      name: name,
      content: content,
    );
  }

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

  bool get isEmpty => this == MyFile.empty;

  @override
  List<Object?> get props => [fileId, name, content];
}