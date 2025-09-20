import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../blocs/flowchart_bloc/flowchart_state.dart';

/// Un motore per trovare la posizione ottimale per una nuova forma, evitando collisioni.
class PlacementEngine {
  // Padding extra per evitare che le forme si tocchino
  static const double _padding = 20.0;

  /// Metodo principale per trovare una posizione valida.
  /// Ritorna un Offset con le coordinate (x, y) o null se non trova spazio.
  static Offset? findOptimalPosition({
    required FlowchartShape fromShape,
    required Size newShapeSize,
    required List<FlowchartShape> existingShapes,
  }) {

    // --- Strategia di Ricerca Semplice: Sotto -> Destra -> Sinistra ---

    // 1. Prova la posizione SOTTO (quella predefinita)
    Offset candidatePosition = Offset(
      fromShape.x + (fromShape.width / 2) - (newShapeSize.width / 2), // Centrata orizzontalmente
      fromShape.y + fromShape.height + (_padding * 2),
    );
    Rect candidateRect = Rect.fromLTWH(candidatePosition.dx, candidatePosition.dy, newShapeSize.width, newShapeSize.height);
    if (_isPositionFree(candidateRect, existingShapes)) {
      return candidatePosition;
    }

    // 2. Se sotto è occupato, prova a DESTRA
    candidatePosition = Offset(
      fromShape.x + fromShape.width + (_padding * 2),
      fromShape.y + (fromShape.height / 2) - (newShapeSize.height / 2), // Centrata verticalmente
    );
    candidateRect = Rect.fromLTWH(candidatePosition.dx, candidatePosition.dy, newShapeSize.width, newShapeSize.height);
    if (_isPositionFree(candidateRect, existingShapes)) {
      return candidatePosition;
    }

    // 3. Se anche a destra è occupato, prova a SINISTRA
    candidatePosition = Offset(
      fromShape.x - newShapeSize.width - (_padding * 2),
      fromShape.y + (fromShape.height / 2) - (newShapeSize.height / 2), // Centrata verticalmente
    );
    candidateRect = Rect.fromLTWH(candidatePosition.dx, candidatePosition.dy, newShapeSize.width, newShapeSize.height);
    if (_isPositionFree(candidateRect, existingShapes)) {
      return candidatePosition;
    }

    // Caso limite: non è stato trovato spazio con la strategia semplice.
    print("PlacementEngine: Nessuno spazio libero trovato nelle vicinanze.");
    return null;
  }

  /// Controlla se un dato rettangolo si sovrappone a una delle forme esistenti.
  static bool _isPositionFree(Rect targetRect, List<FlowchartShape> shapes) {
    for (final shape in shapes) {
      final existingShapeRect = Rect.fromLTWH(shape.x, shape.y, shape.width, shape.height)
          .inflate(_padding); // Aggiungiamo padding per sicurezza

      if (targetRect.overlaps(existingShapeRect)) {
        return false; // Collisione trovata! La posizione non è libera.
      }
    }
    return true; // Nessuna collisione, la posizione è libera.
  }
}