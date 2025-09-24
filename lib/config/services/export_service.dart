import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flowchart_thesis/config/services/dialog_service/app_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:universal_html/html.dart' as html;
import 'package:universal_html/js.dart';

import 'dialog_service/service_dialog.dart';

/// Servizio con funzioni di utilità per l'esportazione.
class ExportService {
  /// **Metodo di Preparazione Universale**
  /// Genera i byte di un'immagine PNG da un widget identificato da una GlobalKey.
  /// Restituisce Uint8List in caso di successo, altrimenti null.
  static Future<Uint8List?> generatePngBytes({required GlobalKey key}) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Render boundary non trovato.');
      }
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      AppDialogs.showInfoDialog(
          context as BuildContext,
          title: 'Errore di esportazione',
          message: 'Si è verificato un errore durante la generazione dell\'immagine: $e',
          closeText: 'OK',

          type: DialogType.error);
      return null;
    }
  }

  /// **Metodo di Download Locale Completo**
  /// Avvia il download di un file tramite il browser e mostra i dialoghi di feedback.
  static Future<void> downloadFileWithDialog({
    required BuildContext context,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '$fileName.png')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (!context.mounted) return;
      // --- MODIFICA: Utilizzo di AppDialogs e del nuovo DialogType.success ---
      await AppDialogs.showInfoDialog(context,
          title: 'Esportazione completata',
          message: 'Il file è stato scaricato con successo.',
          type: DialogType.success,
          closeText: 'OK');
    } catch (e) {
      if (context.mounted) {
        // --- MODIFICA: Utilizzo di AppDialogs e del nuovo DialogType.error ---
        await AppDialogs.showInfoDialog(context,
            title: 'Errore di esportazione',
            message: 'Si è verificato un errore durante il download: $e',
            type: DialogType.error,
            closeText: 'OK');
      }
    }
  }
}
