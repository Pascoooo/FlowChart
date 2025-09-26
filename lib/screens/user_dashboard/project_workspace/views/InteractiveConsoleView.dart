import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/services.dart';

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
  State<InteractiveConsoleDialog> createState() => _InteractiveConsoleDialogState();
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
      // Sostituisce l'URL http con ws (o https con wss per connessioni sicure)
      final wsUrl = widget.serviceUrl.replaceFirst(RegExp(r'^http'), 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('${wsUrl}console'));

      setState(() {
        _outputLines.add('Tentativo di connessione a ${wsUrl}console...');
      });

      // Invia subito il codice C dopo la connessione
      _channel.sink.add(widget.cCode);

      _channel.stream.listen(
            (message) {
          if (!mounted) return;
          setState(() {
            if (message == "[ESECUZIONE AVVIATA]") {
              _isConnected = true;
              _outputLines.add('--- Esecuzione avviata ---');
              // Controlla se la prima riga richiede un input
              _awaitingInput = _outputLines.last.contains('Inserisci valore');
            } else if (message == "[ESECUZIONE TERMINATA]") {
              _isExecutionFinished = true;
              _awaitingInput = false; // L'esecuzione è finita, non si attende più input
              _outputLines.add('--- Esecuzione terminata ---');
            } else {
              _outputLines.add(message);
              // Controlla se l'ultima riga ricevuta è una richiesta di input
              _awaitingInput = message.contains('Inserisci valore');
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
        _outputLines.add('> $textToSend'); // Mostra l'input inviato
        _awaitingInput = false; // Assume che l'input sia stato consumato
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.terminal, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Console: ${widget.fileName}',
              style: theme.textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 6,
            backgroundColor: _isConnected ? Colors.green : Colors.grey,
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.black.withOpacity(0.5) : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _outputLines.length,
                  itemBuilder: (context, index) {
                    final line = _outputLines[index];
                    return Text(
                      line,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!_isExecutionFinished)
              TextField(
                controller: _inputController,
                autofocus: true,
                enabled: _awaitingInput, // Abilitato solo quando serve un input
                decoration: InputDecoration(
                  hintText: _awaitingInput ? 'Inserisci un valore e premi Invio...' : 'In attesa di output...',
                  border: const OutlineInputBorder(),
                  filled: true,
                ),
                onSubmitted: (_) => _sendInput(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_isExecutionFinished ? 'Chiudi' : 'Termina'),
        ),
      ],
    );
  }
}