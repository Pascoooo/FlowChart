import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class InteractiveConsoleDialog extends StatefulWidget {
  final String serviceUrl;
  final String cCode;
  final String fileName;

  const InteractiveConsoleDialog({
    super.key,
    required this.serviceUrl,
    required this.cCode,
    required this.fileName,
  });

  @override
  State<InteractiveConsoleDialog> createState() =>
      _InteractiveConsoleDialogState();
}

class _InteractiveConsoleDialogState extends State<InteractiveConsoleDialog> {
  late WebSocketChannel _channel;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _outputLines = [];
  bool _isConnected = false;
  bool _isExecutionFinished = false;
  bool _awaitingInput = false;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    try {
      final wsUrl = widget.serviceUrl.replaceFirst(RegExp(r'^http'), 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/console'));

      setState(() {
        _outputLines.add('Tentativo di connessione...');
      });

      _channel.sink.add(widget.cCode);

      _channel.stream.listen(
            (message) {
          if (!mounted) return;
          setState(() {
            if (message == "[ESECUZIONE AVVIATA]") {
              _isConnected = true;
              _outputLines.clear(); // Pulisce i messaggi di connessione
              _outputLines.add('--- Esecuzione avviata ---');
            } else if (message == "[ESECUZIONE TERMINATA]") {
              _isExecutionFinished = true;
              _awaitingInput = false;
              _outputLines.add('--- Esecuzione terminata ---');
            } else {
              _outputLines.add(message);
              // Logica per determinare se attendere un input.
              // È euristica e potrebbe essere migliorata in base all'output specifico dei programmi C.
              final trimmedMessage = message.trim();
              final lowerMessage = trimmedMessage.toLowerCase();
              if (lowerMessage.contains('inserisci') ||
                  lowerMessage.contains('digita') ||
                  lowerMessage.contains('enter') ||
                  lowerMessage.endsWith(':') ||
                  lowerMessage.endsWith('?')) {
                _awaitingInput = true;
              } else {
                _awaitingInput = false;
              }
            }
          });
          _scrollToBottom();
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            if (!_isExecutionFinished) {
              _outputLines.add('--- Connessione chiusa dal server ---');
            }
            _isConnected = false;
            _isExecutionFinished = true;
            _awaitingInput = false;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _outputLines.add('--- Errore di connessione: $error ---');
            _isConnected = false;
            _isExecutionFinished = true;
            _awaitingInput = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _outputLines.add('--- Errore URL WebSocket: $e ---');
        _isExecutionFinished = true;
      });
    }
  }

  void _sendInput() {
    if (_inputController.text.isNotEmpty && _isConnected && _awaitingInput) {
      final textToSend = _inputController.text;
      _channel.sink.add(textToSend);
      setState(() {
        _outputLines.add('> $textToSend');
        _awaitingInput = false;
      });
      _inputController.clear();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _channel.sink.close();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  TextStyle _getLineStyle(String line, FluentThemeData theme) {
    final baseStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: 14,
      color: theme.typography.body?.color,
    );
    if (line.startsWith('> ')) {
      return baseStyle.copyWith(
          color: theme.accentColor.defaultBrushFor(theme.brightness));
    }
    if (line.startsWith('---')) {
      return baseStyle.copyWith(
          color: theme.typography.body?.color?.withOpacity(0.6),
          fontStyle: FontStyle.italic);
    }
    if (line.contains('[ERRORE')) {
      return baseStyle.copyWith(color: theme.resources.systemFillColorCritical);
    }
    return baseStyle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // MODIFICA: Stile del pulsante distruttivo basato sul tema.
    final destructiveButtonStyle = ButtonStyle(
      backgroundColor: ButtonState.resolveWith((states) {
        final color = theme.resources.systemFillColorCritical;
        if (states.isPressing) return color.withOpacity(0.8);
        if (states.isHovering) return color.withOpacity(0.9);
        return color;
      }),
      foregroundColor: ButtonState.all(Colors.white),
    );

    // MODIFICA: La struttura ora usa le proprietà 'title', 'content' e 'actions'
    // del ContentDialog per un layout più standard e pulito.
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
      // SEZIONE TITOLO
      title: Row(
        children: [
          Icon(FontAwesomeIcons.terminal,
              color: theme.accentColor.defaultBrushFor(theme.brightness),
              size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Console: ${widget.fileName}',
              style: theme.typography.title,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Tooltip(
            message: _isConnected ? 'Connesso' : 'Disconnesso',
            child: InfoBadge(
              // MODIFICA: Colori basati sul tema
              color: _isConnected
                  ? Colors.green
                  : theme.inactiveColor,
            ),
          ),
        ],
      ),
      // SEZIONE CONTENUTO
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // SEZIONE OUTPUT CONSOLE
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.micaBackgroundColor,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _outputLines.length,
                  itemBuilder: (context, index) {
                    final line = _outputLines[index];
                    return SelectableText( // MODIFICA: reso il testo selezionabile
                      line,
                      style: _getLineStyle(line, theme),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // SEZIONE INPUT UTENTE
          if (!_isExecutionFinished)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextBox(
                    controller: _inputController,
                    autofocus: true,
                    enabled: _awaitingInput,
                    placeholder: _awaitingInput
                        ? 'Inserisci il valore e premi Invio...'
                        : 'In attesa del prossimo input dal programma...',
                    onSubmitted: (_) => _sendInput(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _awaitingInput ? _sendInput : null,
                  child: const Text('Invia'),
                ),
              ],
            ),
        ],
      ),
      // SEZIONE AZIONI
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          style: _isExecutionFinished ? null : destructiveButtonStyle,
          child: Text(_isExecutionFinished ? 'Chiudi' : 'Termina Esecuzione'),
        ),
      ],
    );
  }
}