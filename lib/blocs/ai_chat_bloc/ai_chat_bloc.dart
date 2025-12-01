import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'ai_chat_event.dart';
import 'ai_chat_state.dart';

/// BLoC per gestire la chat con l'assistente AI usando il package ufficiale Google
class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  final String apiKey;
  late final GenerativeModel _model;

  AiChatBloc({required this.apiKey}) : super(const AiChatInitial()) {
    // Inizializza il modello Gemini usando il package ufficiale google_generative_ai
    _model = GenerativeModel(
      model: 'gemini-2.5-flash-lite',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 1.0,
      ),
      systemInstruction: Content.system(
        '''
Sei un tutor per UniChart, un editor di flowchart didattico.

OBIETTIVO
- Aiutare lo studente a costruire o correggere flowchart.
- Farlo progredire, non lasciarlo bloccato.
- Evitare di dare la soluzione completamente pronta, ma guidarlo con passi concreti.

COMPORTAMENTO
- Puoi:
  - Spiegare passo per passo cosa dovrebbe fare il flowchart.
  - Suggerire blocchi specifici (Inizio, Decisione, Ciclo, ecc.) e dove metterli.
  - Proporre condizioni (ad esempio: "usa `contatore < 10` come condizione del ciclo").
  - Mostrare ESEMPI PARZIALI, mai l’intero flowchart definitivo.
  - Correggere errori in modo chiaro ("qui ti manca un blocco di Fine", "questa Decisione deve avere 2 uscite").

- NON devi:
  - Disegnare l’intero flowchart completo pronto all’uso.
  - Dare la risposta finale di un esercizio in un unico messaggio senza lasciare nulla da fare allo studente.
  - Ignorare completamente la richiesta: se lo studente chiede aiuto concreto, dagli passi concreti.

STRATEGIA DI RISPOSTA
- Se lo studente chiede “fammi il flowchart di X”:
  - Spiega la struttura (fasi principali).
  - Poi proponi un possibile schema, ma lascia almeno una parte da completare (es: “qui devi decidere tu la condizione esatta”).

- Se lo studente mostra un flowchart incompleto o sbagliato:
  - Indica esattamente dove è il problema.
  - Suggerisci come correggerlo (“aggiungi un blocco Decisione dopo questo Processo…”).
  - Puoi anche descrivere come dovrebbe essere il flusso corretto, ma NON disegnarlo già completo.

- Se lo studente è molto bloccato:
  - Puoi proporre una versione quasi completa, ma:
    - spiega sempre IL PERCHÈ dei blocchi.
    - lascia almeno un pezzo da riempire (es. una condizione, un ramo else, il comportamento in un caso particolare).

LINGUAGGIO
- Usa i nomi dei blocchi come li vede l’utente: Inizio, Fine, Processo, Decisione, Ciclo While, ecc.
- Non usare dettagli interni del codice (ReturnNode, FlowNodeKind, ecc.).
- Rispondi sempre in italiano, con Markdown dove utile (liste, pezzi di pseudo-codice, ecc.).

  ''',
      ),
    );

    on<InitializeChat>(_onInitializeChat);
    on<SendMessageToAi>(_onSendMessageToAi);
    on<ClearChatHistory>(_onClearChatHistory);
  }

  /// Inizializza la chat con un messaggio di benvenuto
  void _onInitializeChat(InitializeChat event, Emitter<AiChatState> emit) {
    emit(AiChatReady(
      messages: [
        ChatMessage(
          content: '👋 Ciao! Sono l\'assistente virtuale di **UniChart**.\n\n'
              'Sono qui per aiutarti con:\n'
              '• Creazione e modifica di flowchart\n'
              '• Spiegazioni su costrutti e nodi\n'
              '• Best practices per la programmazione visuale\n'
              '• Risoluzione di problemi\n\n'
              'Come posso assisterti oggi?',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
    ));
  }

  /// Gestisce l'invio di un messaggio all'AI usando il package ufficiale
  Future<void> _onSendMessageToAi(SendMessageToAi event, Emitter<AiChatState> emit) async {
    final currentState = state;
    List<ChatMessage> currentMessages = [];

    if (currentState is AiChatReady) {
      currentMessages = List.from(currentState.messages);
    } else if (currentState is AiChatError) {
      currentMessages = List.from(currentState.messages);
    }

    // Aggiungi il messaggio dell'utente
    final userMessage = ChatMessage(
      content: event.message,
      isUser: true,
      timestamp: DateTime.now(),
    );
    currentMessages.add(userMessage);

    // Emetti stato loading
    emit(AiChatReady(messages: currentMessages, isLoading: true));

    try {
      // Costruisci il prompt con contesto opzionale
      String userPrompt = event.message;
      if (event.context != null && event.context!.isNotEmpty) {
        userPrompt = 'Contesto flowchart:\n${event.context}\n\nDomanda: ${event.message}';
      }

      // Chiamata API usando il package ufficiale (molto più semplice!)
      final content = [Content.text(userPrompt)];
      final response = await _model.generateContent(content);

      // Estrai la risposta
      final aiResponse = response.text ?? 'Mi dispiace, non ho ricevuto una risposta valida.';

      final aiMessage = ChatMessage(
        content: aiResponse,
        isUser: false,
        timestamp: DateTime.now(),
      );
      currentMessages.add(aiMessage);

      emit(AiChatReady(messages: currentMessages, isLoading: false));
    } on GenerativeAIException catch (e) {
      // Gestione errori specifici dell'API Gemini
      String errorMsg = 'Errore API Gemini: ${e.message}';
      emit(AiChatError(
        errorMessage: errorMsg,
        messages: currentMessages,
      ));

      await Future.delayed(const Duration(seconds: 3));
      emit(AiChatReady(messages: currentMessages, isLoading: false));
    } catch (e) {
      // Gestione errori generici
      emit(AiChatError(
        errorMessage: 'Errore nella comunicazione con l\'AI: ${e.toString()}',
        messages: currentMessages,
      ));

      await Future.delayed(const Duration(seconds: 3));
      emit(AiChatReady(messages: currentMessages, isLoading: false));
    }
  }

  /// Cancella la cronologia della chat
  void _onClearChatHistory(ClearChatHistory event, Emitter<AiChatState> emit) {
    emit(const AiChatReady(messages: []));
  }
}

