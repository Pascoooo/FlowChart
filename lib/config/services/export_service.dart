// 'lib/config/services/export_service.dart'
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

/// Eccezione personalizzata per gli errori di esportazione
class ExportException implements Exception {
  final String message;
  const ExportException(this.message);
  @override
  String toString() => 'ExportException: $message';
}

class ExportService {
  static const String _downloadName = 'unichart_export';

  /// Esporta la WorkArea come JPG.
  static Future<void> exportToJpg({
    required GlobalKey workareaKey,
    String? fileName,
  }) async {
    try {
      final boundary = workareaKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw const ExportException('Impossibile trovare la workarea per l\'esportazione.');
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw const ExportException('Errore nella generazione dell\'immagine.');
      }

      final imageBytes = byteData.buffer.asUint8List();

      _downloadFile(
        imageBytes,
        fileName ?? '${_downloadName}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        'image/jpeg',
      );
    } catch (e) {
      if (e is ExportException) {
        rethrow;
      }
      throw ExportException('Errore sconosciuto durante l\'esportazione: $e');
    }
  }

  /// Helper per scaricare il file nel browser.
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

  /// Funzione per esportare direttamente in JPG dalla topbar.
  static Future<void> exportDirectlyToJpg({
    required BuildContext context,
    required GlobalKey workareaKey,
    String? defaultFileName,
  }) async {
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _performExport(
          context: dialogContext,
          theme: theme,
          workareaKey: workareaKey,
          defaultFileName: defaultFileName,
        );
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  static Future<void> _performExport({
    required BuildContext context,
    required ThemeData theme,
    required GlobalKey workareaKey,
    String? defaultFileName,
  }) async {
    try {
      await exportToJpg(
        workareaKey: workareaKey,
        fileName: defaultFileName,
      );
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('JPG esportato con successo'),
            backgroundColor: theme.colorScheme.primary,
          ),
        );
      }
    } on ExportException catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Si è verificato un errore inatteso.'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}