import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flowchart_thesis/config/services/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:universal_html/html.dart' as html;

/// Servizio per esportare un widget come immagine PNG.
class ExportService {
  static Future<void> exportWidgetToPng({
    required BuildContext context,
    required GlobalKey key,
    required String fileName,
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Impossibile trovare il widget da esportare.');
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      _downloadFile(pngBytes, '$fileName.png');

      if (!context.mounted) return;
      DialogService.showInfoDialog(context,
          title: 'Esportazione completata',
          message: 'Il file è stato esportato con successo.',
          closeText: 'OK',
          icon: Icons.check_circle_outline);
    } catch (e) {
      if (context.mounted) {
        DialogService.showInfoDialog(context,
            title: 'Errore di esportazione',
            message: 'Si è verificato un errore durante l\'esportazione: $e',
            closeText: 'OK',
            icon: Icons.error_outline);
      }
    }
  }

  /// Avvia il download di un file con i byte specificati e il nome del file.
  static void _downloadFile(Uint8List bytes, String fileName) {
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
