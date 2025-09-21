import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../blocs/flowchart_bloc/flowchart_state.dart';

/// Un motore per trovare la posizione ottimale per una nuova forma,
/// evitando collisioni e rimanendo dentro i confini della workarea.
class PlacementEngine {
  static const double _padding = 20.0;

  /// Metodo principale per trovare una posizione valida.
  static Offset? findOptimalPosition({
    required FlowchartShape fromShape,
    required Size newShapeSize,
    required List<FlowchartShape> existingShapes,
    required BoxConstraints canvasConstraints, // <-- NUOVO PARAMETRO
  }) {
    // Definiamo il rettangolo che rappresenta l'intera area di lavoro
    final canvasRect = Rect.fromLTWH(
      0, 0,
      canvasConstraints.maxWidth,
      canvasConstraints.maxHeight,
    ).deflate(_padding); // Riduciamo leggermente per non stare attaccati ai bordi

    // Lista di posizioni candidate da provare in ordine di preferenza
    final List<Offset> candidatePositions = [
      // Sotto
      Offset(
        fromShape.x + (fromShape.width / 2) - (newShapeSize.width / 2),
        fromShape.y + fromShape.height + (_padding * 2),
      ),
      // Destra
      Offset(
        fromShape.x + fromShape.width + (_padding * 2),
        fromShape.y + (fromShape.height / 2) - (newShapeSize.height / 2),
      ),
      // Sinistra
      Offset(
        fromShape.x - newShapeSize.width - (_padding * 2),
        fromShape.y + (fromShape.height / 2) - (newShapeSize.height / 2),
      ),
    ];

    // Prova ogni posizione candidata
    for (final position in candidatePositions) {
      final candidateRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        newShapeSize.width,
        newShapeSize.height,
      );

      // --- DOPPIO CONTROLLO PERFETTO ---
      // 1. La forma è COMPLETAMENTE dentro la workarea?
      final bool isInside = canvasRect.contains(candidateRect.topLeft) &&
          canvasRect.contains(candidateRect.bottomRight);

      // 2. La posizione è libera da altre forme?
      if (isInside && _isPositionFree(candidateRect, existingShapes)) {
        // Se entrambi i controlli passano, abbiamo trovato la posizione perfetta!
        return position;
      }
    }

    print("PlacementEngine: Nessuno spazio valido trovato.");
    return null;
  }

  /// Controlla se un dato rettangolo si sovrappone a una delle forme esistenti.
  static bool _isPositionFree(Rect targetRect, List<FlowchartShape> shapes) {
    for (final shape in shapes) {
      final existingShapeRect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height)
          .inflate(_padding);

      if (targetRect.overlaps(existingShapeRect)) {
        return false;
      }
    }
    return true;
  }
}