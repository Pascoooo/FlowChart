import 'dart:ui';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter/material.dart';
/// Un motore per trovare la posizione ottimale per un nuovo nodo,
/// evitando collisioni e rimanendo dentro i confini della workarea.
class PlacementEngine {
  // Aumentiamo un po' il padding per dare più respiro tra i nodi.
  static const double _padding = 32.0;

  /// Metodo principale per trovare una posizione valida.
  static Offset? findOptimalPosition({
    required FlowNode fromNode,
    required Size newNodeSize,
    required List<FlowNode> existingNodes,
    required BoxConstraints canvasConstraints,
    String? fromPort, // NUOVO: per gestire le uscite 'true'/'false' del DecisionNode
  }) {
    // Definiamo il rettangolo che rappresenta l'intera area di lavoro.
    final canvasRect = Rect.fromLTWH(
      0, 0,
      canvasConstraints.maxWidth,
      canvasConstraints.maxHeight,
    ).deflate(_padding); // Riduciamo per non stare attaccati ai bordi.

    // La lista di posizioni candidate ora dipende dal nodo di partenza.
    final List<Offset> candidatePositions = _getCandidatePositions(
      fromNode: fromNode,
      newNodeSize: newNodeSize,
      fromPort: fromPort,
    );

    // Prova ogni posizione candidata.
    for (final position in candidatePositions) {
      final candidateRect = Rect.fromLTWH(
        position.dx,
        position.dy,
        newNodeSize.width,
        newNodeSize.height,
      );

      // CONTROLLO 1: Il nodo è COMPLETAMENTE dentro la workarea?
      final bool isInside = canvasRect.contains(candidateRect.topLeft) &&
          canvasRect.contains(candidateRect.bottomRight);

      // CONTROLLO 2: La posizione è libera da altri nodi?
      if (isInside && _isPositionFree(candidateRect, existingNodes)) {
        // Se entrambi i controlli passano, abbiamo trovato la posizione perfetta!
        return position;
      }
    }

    // Se nessun candidato va bene, prova una posizione di fallback più lontana.
    final fallbackPosition = Offset(
      fromNode.x + fromNode.width / 2 - newNodeSize.width / 2,
      fromNode.y + fromNode.height + (_padding * 4), // Più in basso
    );
    final fallbackRect = Rect.fromLTWH(fallbackPosition.dx, fallbackPosition.dy, newNodeSize.width, newNodeSize.height);
    if (canvasRect.contains(fallbackRect.topLeft) && canvasRect.contains(fallbackRect.bottomRight) && _isPositionFree(fallbackRect, existingNodes)) {
      return fallbackPosition;
    }


    debugPrint("PlacementEngine: Nessuno spazio valido trovato.");
    return null;
  }

  /// Genera le posizioni candidate in base al tipo di nodo di partenza.
  static List<Offset> _getCandidatePositions({
    required FlowNode fromNode,
    required Size newNodeSize,
    String? fromPort,
  }) {
    // Caso specifico per il DecisionNode.
    if (fromNode.kind == FlowNodeKind.decision && fromPort != null) {
      if (fromPort == 'true') {
        // Prova solo a destra.
        return [
          Offset(
            fromNode.x + fromNode.width + _padding,
            fromNode.y + (fromNode.height / 2) - (newNodeSize.height / 2),
          ),
        ];
      } else { // fromPort == 'false'
        // Prova solo a sinistra.
        return [
          Offset(
            fromNode.x - newNodeSize.width - _padding,
            fromNode.y + (fromNode.height / 2) - (newNodeSize.height / 2),
          ),
        ];
      }
    }

    // Per tutti gli altri nodi, l'ordine di preferenza standard.
    return [
      // 1. Sotto (preferita)
      Offset(
        fromNode.x + (fromNode.width / 2) - (newNodeSize.width / 2),
        fromNode.y + fromNode.height + _padding,
      ),
      // 2. Destra
      Offset(
        fromNode.x + fromNode.width + _padding,
        fromNode.y + (fromNode.height / 2) - (newNodeSize.height / 2),
      ),
      // 3. Sinistra
      Offset(
        fromNode.x - newNodeSize.width - _padding,
        fromNode.y + (fromNode.height / 2) - (newNodeSize.height / 2),
      ),
    ];
  }


  /// Controlla se un dato rettangolo si sovrappone a uno dei nodi esistenti.
  static bool _isPositionFree(Rect targetRect, List<FlowNode> nodes) {
    for (final node in nodes) {
      // Gonfiamo il rettangolo del nodo esistente per garantire il padding.
      final existingNodeRect = Rect.fromLTWH(node.x, node.y, node.width, node.height)
          .inflate(_padding / 2); // Un po' di padding extra per sicurezza

      if (targetRect.overlaps(existingNodeRect)) {
        return false; // Trovata una collisione.
      }
    }
    return true; // Nessuna collisione.
  }
}