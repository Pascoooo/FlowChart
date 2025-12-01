/// Pannello brand laterale con animazioni fluttuanti e highlight del prodotto.
/// Pensato per layout desktop, arricchisce la pagina di login con messaggi di valore.
/// Include decorazioni animate leggere per dare profondità alla UI.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BrandPanel extends StatefulWidget {
  const BrandPanel({super.key});

  @override
  State<BrandPanel> createState() => _BrandPanelState();
}

class _BrandPanelState extends State<BrandPanel> with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _rotationController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _rotationAnimation;

  /// Avvia le animazioni di floating/rotazione per dare movimento al pannello.
  /// I controller sono ciclici per mantenere l'effetto continuo sul background.
  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    _floatingController.repeat(reverse: true);
    _rotationController.repeat();
  }

  /// Libera i controller per evitare leak quando il pannello esce dal tree.
  /// Mantiene pulizia della memoria durante navigazioni ripetute.
  @override
  void dispose() {
    _floatingController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  /// Costruisce il pannello brand con elementi decorativi animati e testi.
  /// Usa gradienti soft e transizioni per presentare il valore del prodotto.
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.accentColor.lighter.withOpacity(0.05),
            theme.accentColor.lighter.withOpacity(0.02),
            theme.scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Elementi decorativi animati
          Positioned(
            top: size.height * 0.1,
            right: 60,
            child: AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: theme.accentColor.withOpacity(0.1),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: size.height * 0.2,
            left: 40,
            child: AnimatedBuilder(
              animation: _floatingAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatingAnimation.value),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                );
              },
            ),
          ),
          // Contenuto principale
          Padding(
            padding: const EdgeInsets.all(60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo animato
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.brightness == Brightness.light ? theme.cardColor : null,
                          gradient: theme.brightness == Brightness.dark
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    theme.accentColor.dark,
                                    theme.accentColor,
                                    theme.accentColor.light,
                                  ],
                                )
                              : null,
                          border: theme.brightness == Brightness.light
                              ? Border.all(
                                  color: theme.accentColor,
                                  width: 3.5,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: theme.accentColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 48),
                // Titolo animato
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 50 * (1 - value)),
                        child: Text(
                          'Unichart',
                          style: theme.typography.display
                              ?.copyWith(fontWeight: FontWeight.w900, height: 1.1),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Sottotitolo animato
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 30 * (1 - value)),
                        child: Text(
                          'Esegui, analizza e perfeziona la tua logica con un debugger visuale integrato. Dai vita alle tue idee, un blocco alla volta.',
                          style: theme.typography.title?.copyWith(
                            color: theme.typography.title?.color
                                ?.withOpacity(0.7),
                            height: 1.5,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                // Features list
                ..._buildFeatureList(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Genera la lista di feature con animazioni di ingresso scaglionate.
  /// Ogni item mostra icona, titolo e sottotitolo con opacità progressiva.
  List<Widget> _buildFeatureList(BuildContext context) {
    final theme = FluentTheme.of(context);
    final features = [
      {
        'icon': FontAwesomeIcons.eye,
        'title': 'Esecuzione Visuale',
        'subtitle': 'Guarda i tuoi algoritmi prendere vita in tempo reale.'
      },
      {
        'icon': FontAwesomeIcons.bugSlash,
        'title': 'Debug Potenziato',
        'subtitle':
        'Naviga il codice, direttamente sul diagramma.'
      },
      {
        'icon': FontAwesomeIcons.magnifyingGlassChart,
        'title': 'Analisi Dettagliata',
        'subtitle': 'Analizza variabili e stati del programma ad ogni passo.'
      },
    ];

    return List.generate(features.length, (index) {
      final feature = features[index];
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 1200 + (index * 200)),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 30 * (1 - value)),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FaIcon(
                      feature['icon'] as IconData,
                      color: theme.accentColor,
                      size: 20,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            feature['title'] as String,
                            style: theme.typography.subtitle
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            feature['subtitle'] as String,
                            style: theme.typography.body?.copyWith(
                              color: theme.typography.body?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }
}
