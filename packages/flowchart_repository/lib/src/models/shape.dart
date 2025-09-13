import '../../src/entities/shape_entity.dart';

class Shape {
  final String id;
  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String text;

  const Shape({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.text,
  });

  /// Converte il modello [Shape] in una [ShapeEntity].
  ShapeEntity toEntity() {
    return ShapeEntity(
      id: id,
      type: type,
      x: x,
      y: y,
      width: width,
      height: height,
      text: text,
    );
  }

  /// Crea un modello [Shape] da una [ShapeEntity].
  static Shape fromEntity(ShapeEntity entity) {
    return Shape(
      id: entity.id,
      type: entity.type,
      x: entity.x,
      y: entity.y,
      width: entity.width,
      height: entity.height,
      text: entity.text,
    );
  }
}