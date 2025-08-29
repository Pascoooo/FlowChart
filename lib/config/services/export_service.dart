import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:ui' as ui;

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

  /// Esporta la WorkArea come PNG
  static Future<void> exportToPng({
    required GlobalKey workareaKey,
    String? fileName,
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
        fileName ?? '${_downloadName}_${DateTime.now().millisecondsSinceEpoch}.png',
        'image/png',
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

  /// Mostra dialog per selezionare il formato di esportazione
  static Future<void> showExportDialog({
    required BuildContext context,
    required GlobalKey workareaKey,
    String? defaultFileName,
  }) async {
    final theme = Theme.of(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.surface,
                  theme.colorScheme.surface.withOpacity(0.95),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.2),
                        theme.colorScheme.primary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.download_rounded,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Esporta Diagramma',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scegli il formato di esportazione',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 32),
                _buildExportOption(
                  context: dialogContext,
                  theme: theme,
                  icon: Icons.image,
                  title: 'PNG',
                  description: 'Immagine di alta qualità',
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await exportToPng(
                        workareaKey: workareaKey,
                        fileName: defaultFileName,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('PNG esportato con successo'),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore nell\'esportazione: $e'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildExportOption(
                  context: dialogContext,
                  theme: theme,
                  icon: Icons.photo,
                  title: 'JPG',
                  description: 'Immagine compressa',
                  onTap: () async {
                    Navigator.pop(dialogContext);
                    try {
                      await exportToJpg(
                        workareaKey: workareaKey,
                        fileName: defaultFileName,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('JPG esportato con successo'),
                            backgroundColor: theme.colorScheme.primary,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Errore nell\'esportazione: $e'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),

                const SizedBox(height: 32),

                // Bottone annulla
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Annulla',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _buildExportOption({
    required BuildContext context,
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withOpacity(0.2),
                      theme.colorScheme.primary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}