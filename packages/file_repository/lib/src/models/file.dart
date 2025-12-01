import 'package:equatable/equatable.dart';
import '../entities/file_entity.dart';

/// Rappresenta un file di testo all'interno di un progetto.
/// Include identificatore univoco, nome e contenuto completo.
/// Usa Equatable per confronti affidabili basati sul valore.
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

  /// Crea una copia di MyFile con i campi specificati aggiornati.
  /// Essenziale per la programmazione con stati immutabili (pattern usato con BLoC).
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

  /// Converte MyFile in MyFileEntity per la persistenza su Firestore.
  MyFileEntity toEntity() {
    return MyFileEntity(
      fileId: fileId,
      name: name,
      content: content,
    );
  }

  /// Crea un'istanza di MyFile da MyFileEntity (deserializzazione).
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