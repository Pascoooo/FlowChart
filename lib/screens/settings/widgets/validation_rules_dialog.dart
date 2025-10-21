import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ValidationRulesDialog extends StatefulWidget {
  const ValidationRulesDialog({super.key});

  @override
  State<ValidationRulesDialog> createState() => _ValidationRulesDialogState();
}

class _ValidationRulesDialogState extends State<ValidationRulesDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.page?.round() != _currentPage) {
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _rulePages = [
    const _RulePage(
      icon: FontAwesomeIcons.lightbulb,
      title: 'Benvenuto in Unichart!',
      description:
          'Unichart è un ambiente di apprendimento visuale progettato per insegnare le basi della programmazione. Attraverso la creazione di diagrammi di flusso (flowchart), puoi visualizzare la logica di un programma e testarla con un debugger integrato.',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.gears,
      title: 'Il Principio dell\'Esecuzione',
      description:
          'Concetto chiave: ogni blocco esegue la sua azione non appena il debugger ci entra, non quando esce. Il debugger si ferma su un blocco DOPO aver già eseguito la sua logica, in attesa del tuo comando per procedere al passo successivo.',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.puzzlePiece,
      title: 'I Blocchi Fondamentali',
      description:
          '• Start/End: Indicano l\'inizio e la fine del flusso. L\'esecuzione termina solo dopo aver superato il nodo End.\n• Process: Mette in pausa il flusso attuale per eseguire un sottoprogramma.\n• Assignment: Assegna a una variabile il risultato di un\'espressione (es. `var = 5 * 2`).',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.rightLeft,
      title: 'Input e Output',
      description:
          '• Input: Prepara una variabile a ricevere un valore dall\'utente, inizializzandola a null. Non chiede l\'input direttamente.\n• Assegnamento vuoto (es. `var = `): È questo il blocco che ferma il debugger e chiede all\'utente di inserire un valore per la variabile.\n• Output: Mostra a schermo il valore di una o più variabili. Puoi creare messaggi formattati usando template come `Il totale è {{tot}}`.',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.codeBranch,
      title: 'Logica Condizionale e Cicli',
      description:
          '• Decisione: Esegue un percorso diverso ("true" o "false") a seconda del risultato della condizione.\n• Ciclo While: Controlla la condizione prima di eseguire il corpo del ciclo.\n• Ciclo Do-While: Esegue il corpo del ciclo almeno una volta, e solo dopo controlla la condizione per decidere se ripetere.',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.diagramProject,
      title: 'Sottoprogrammi (Funzioni)',
      description:
          'Organizza il codice in blocchi riutilizzabili. Ogni funzione inizia con un\'intestazione (Function Header) e termina con uno o più nodi Return, che possono restituire un valore al chiamante.',
    ),
    const _RulePage(
      icon: FontAwesomeIcons.database,
      title: 'Ambiti delle Variabili',
      description:
          '• Input: Per variabili che riceveranno un valore dall\'utente durante l\'esecuzione.\n• Output: Per variabili destinate a essere mostrate a schermo con un nodo Output.\n• Lavoro: Per variabili temporanee usate per calcoli interni.',
    ),
     const _RulePage(
      icon: FontAwesomeIcons.rocket,
      title: 'Ora tocca a te!',
      description:
          'Questa era una panoramica generale. Il modo migliore per imparare è sperimentare. Inizia a costruire il tuo primo flowchart e osserva come la tua logica prende vita. Buon divertimento!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 600),
      title: const Text('Guida Introduttiva di Unichart'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                children: _rulePages,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _rulePages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? theme.accentColor
                        : theme.inactiveColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _currentPage > 0
              ? () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              : null,
          child: const Text('Precedente'),
        ),
        Button(
          onPressed: _currentPage < _rulePages.length - 1
              ? () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              : null,
          child: const Text('Successiva'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Inizia a creare'),
        ),
      ],
    );
  }
}

class _RulePage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _RulePage({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FaIcon(icon, size: 40, color: theme.accentColor),
          const SizedBox(height: 24),
          Text(
            title,
            style: theme.typography.subtitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.typography.body,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
