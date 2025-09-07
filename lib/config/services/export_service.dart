import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

import 'dialog_service.dart';

class ExportService {
  static const String _downloadName = 'unichart_export';

  /// Esporta la WorkArea come JPG
  static Future<void> exportToJpg({
    required GlobalKey workareaKey,
    String? fileName,
    double quality = 0.9,
  }) async {
    try {
      // Cattura screenshot della workarea
      final boundary = workareaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Impossibile trovare la workarea per l\'esportazione');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Errore nella generazione dell\'immagine');
      }

      final imageBytes = byteData.buffer.asUint8List();

      // Download del file
      _downloadFile(
        imageBytes,
        fileName ?? '${_downloadName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'image/jpeg',
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Helper per scaricare il file nel browser
  static void _downloadFile(Uint8List bytes, String fileName, String mimeType) {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..style.display = 'none';

    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
  }

  /// Funzione per esportare direttamente in JPG dalla topbar
  static Future<void> exportDirectlyToJpg({
    required BuildContext context,
    required GlobalKey workareaKey,
    String? defaultFileName,
  }) async {
    final theme = Theme.of(context);

    void showExportingOverlay(BuildContext context, String message) {
      DialogService.showLoadingDialog(
        context,
        message: message,
      );
    }

    // Mostra indicatore di caricamento
    showExportingOverlay(context, 'Preparazione esportazione JPG...');



    // Aggiungi un timer di 1 secondo prima di eseguire l'esportazione
    Future.delayed(const Duration(seconds: 1), () async {
      try {
        await exportToJpg(
          workareaKey: workareaKey,
          fileName: defaultFileName,
        );
        if (context.mounted) {
          Navigator.of(context).pop(); // Chiudi l'overlay
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('JPG esportato con successo'),
              backgroundColor: theme.colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore nell\'esportazione: $e'),
              backgroundColor: theme.colorScheme.error,
            ),
          );
        }
      }
    });
  }
}

