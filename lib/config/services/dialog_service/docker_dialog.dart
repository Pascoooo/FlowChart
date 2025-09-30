// pascoooo/flowchart/FlowChart-rework-flowchart/lib/config/services/dialog_service/docker_setup_dialog.dart

import 'package:flowchart_thesis/config/services/banner_service.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../screens/settings/widgets/settings_provider.dart';

// Funzione helper per mostrare il dialogo e registrare la visualizzazione
Future<void> showDockerSetupDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _DockerSetupDialog(),
  ).then((_) {
    // Al termine, segna che l'utente ha aperto la guida
    context.read<SettingsProvider>().setDockerInfoClicked();
  });
}

class _DockerSetupDialog extends StatelessWidget {
  const _DockerSetupDialog();

  // Metodo robusto per lanciare l'URL di Docker Desktop
  Future<void> _launchDockerURL(BuildContext context) async {
    final url = Uri.parse('https://www.docker.com/products/docker-desktop/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        BannerService.showError(context, 'Impossibile aprire il link al sito di Docker.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    const dockerImageName = 'pasco/unichart-executor:latest';

    // Legge la porta live dalle impostazioni (default 8080)
    final port = context.watch<SettingsProvider>().localExecutorPort;
    final command = 'docker run -d --rm -p 127.0.0.1:$port:8080 --name unichart-executor $dockerImageName';

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 700),
      title: Row(
        children: [
          FaIcon(FontAwesomeIcons.docker, color: theme.accentColor, size: 24),
          const SizedBox(width: 16),
          const Text('Guida all\'Esecuzione Locale con Docker'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Segui questi passaggi per eseguire il codice dei tuoi flowchart in modo sicuro e privato sulla tua macchina, senza bisogno di una connessione a server esterni.',
            ),
            const SizedBox(height: 24),

            // --- Step 1 ---
            _buildStep(
              context,
              index: 1,
              title: 'Installa Docker Desktop',
              content:
                  'Se non l\'hai già fatto, scarica e installa l\'applicazione gratuita Docker Desktop. Una volta installata, assicurati che sia in esecuzione.',
              action: HyperlinkButton(
                onPressed: () => _launchDockerURL(context),
                child: const Text('Scarica Docker Desktop'),
              ),
            ),
            const SizedBox(height: 20),

            // --- Step 2 ---
            _buildStep(
              context,
              index: 2,
              title: 'Avvia l\'Esecutore Unichart',
              content:
                  'Apri un terminale (o PowerShell su Windows) e incolla questo comando. Scaricherà l\'ultima versione del nostro esecutore e lo avvierà in background.',
              action: _CodeBlock(command: command),
            ),
            const SizedBox(height: 20),

            // --- Step 3 ---
            _buildStep(
              context,
              index: 3,
              title: 'Configura e Attiva',
              content:
                  'Torna alla pagina delle impostazioni e attiva la levetta "Abilita Esecutore Locale". Assicurati che la porta corrisponda a quella del comando (di default 8080).',
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Ho capito'),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context,
      {required int index,
      required String title,
      required String content,
      Widget? action}) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: theme.accentColor, width: 2),
          ),
          child: Center(
            child: Text(
              '$index',
              style:
                  theme.typography.bodyStrong?.copyWith(color: theme.accentColor),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.typography.subtitle),
              const SizedBox(height: 4),
              Text(content, style: theme.typography.body),
              if (action != null) ...[
                const SizedBox(height: 12),
                action,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CodeBlock extends StatefulWidget {
  final String command;
  const _CodeBlock({required this.command});

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.command);
  }

  @override
  void didUpdateWidget(covariant _CodeBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.command != widget.command) {
      // Aggiorna il testo mantenendo readOnly
      _controller.text = widget.command;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: _controller,
            readOnly: true,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: WidgetStateProperty.all(
              BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border.all(
                    color: theme.inactiveColor.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const FaIcon(FontAwesomeIcons.copy, size: 16),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.command));
            BannerService.showSuccess(context, 'Comando copiato negli appunti');
          },
        ),
      ],
    );
  }
}