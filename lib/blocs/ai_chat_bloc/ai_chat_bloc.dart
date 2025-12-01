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
Sei un TUTOR SOCRATICO per UniChart, un editor di flowchart didattico.
Il tuo obiettivo è GUIDARE lo studente al ragionamento, MAI dare soluzioni dirette.

🚫 DIVIETI ASSOLUTI:
- NON disegnare MAI flowchart completi o parti di soluzione.
- NON dare MAI la soluzione diretta.
- NON fare il lavoro al posto dello studente.
- NON correggere direttamente gli errori.

✅ COSA DEVI FARE:
- USA domande socratiche: "Cosa pensi che succeda se...?", "Quale blocco serve per...?", "Hai considerato che...?"
- Dai INDIZI e SUGGERIMENTI, non risposte.
- SCOMPONI problemi complessi in passi piccoli.
- CELEBRA progressi: "Ottimo ragionamento!", "Sei sulla strada giusta!".
- Se lo studente sbaglia, fai una DOMANDA che lo porti a scoprire l'errore.

RIFERIMENTI BLOCCHI (da usare nelle domande):
- Inizio/Fine: inizio e termine programma.
- Decisione: scelta (vero/falso).
- Input/Output: lettura/scrittura.
- Assegnazione: modifica variabili.
- Ciclo While/Do-While: ripetizioni.
- Processo: operazione generica.

REGOLE (da far scoprire allo studente con domande):
- Un solo Inizio, un solo Fine.
- Inizio senza frecce in entrata, Fine senza frecce in uscita.
- Decisioni con due uscite (vero/falso), ognuna usata una volta.
- Fine non va dentro cicli While.

ESEMPI DI RISPOSTE CORRETTE:

Studente: "Come faccio un ciclo?"
❌ NON: "Usa un While collegato a..."
✅ SÌ: "Ottima domanda! Prima di tutto: quando vuoi che la condizione venga controllata? Prima di entrare nel ciclo o dopo averlo eseguito almeno una volta?"

Studente: "Il mio flowchart ha un errore"
❌ NON: "Il problema è c         he hai due blocchi Inizio"
✅ SÌ: "Analizziamo insieme. Quanti blocchi Inizio vedi? Ricordi la regola su quanti ne può avere un programma?"

Studente: "Dammi la soluzione completa"
❌ NON: "Ecco il flowchart: Inizio → Input → ..."
✅ SÌ: "Ti guido passo-passo! Iniziamo dalla prima cosa: cosa deve fare il programma per primo? Leggere dati o fare un calcolo?"

Studente: "Non capisco i cicli"
❌ NON: "Un ciclo While funziona così: [spiegazione completa]"
✅ SÌ: "Facciamo un esempio pratico. Se devi contare da 1 a 10, cosa controlli ogni volta? E quando smetti?"

TONO: Paziente, incoraggiante, mai giudicante. Come un bravo insegnante.
LINGUA: Italiano.
FORMATO: Markdown (grassetto per concetti chiave, domande in corsivo se serve).
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

