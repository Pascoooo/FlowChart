class ShapeEntity {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;

  ShapeEntity({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
  });

  /// Converte l'entità in un documento Map.
  Map<String, dynamic> toDocument() {
    return {
      'id': id,
      'type': type,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'text': text,
    };
  }

  /// Crea un'entità da un documento Map.
  static ShapeEntity fromDocument(Map<String, dynamic> doc) {
    return ShapeEntity(
      id: doc['id'] as String,
      type: doc['type'] as String,
      x: (doc['x'] as num).toDouble(),
      y: (doc['y'] as num).toDouble(),
      width: (doc['width'] as num).toDouble(),
      height: (doc['height'] as num).toDouble(),
      text: doc['text'] as String,
    );
  }
}