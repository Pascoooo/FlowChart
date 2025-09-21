import 'dart:typed_data';

/// Cache volatile (in-memory) usata per passare lo screenshot della workarea
/// alla pagina di disegno aperta in una nuova finestra.
class EditorScreenshotCache {
  static Uint8List? lastWorkareaPng;
  static DateTime? lastUpdated;

  static void store(Uint8List bytes) {
    lastWorkareaPng = bytes;
    lastUpdated = DateTime.now();
  }

  static void clear() {
    lastWorkareaPng = null;
    lastUpdated = null;
  }
}
