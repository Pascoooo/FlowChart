import 'package:flowchart_repository/flowchart_repository.dart';
import 'models/models.dart';

/// Repository astratto per la gestione delle sessioni di debug
abstract class DebugRepo {
  /// Crea una nuova sessione di debug
  Future<DebugSession> createSession({
    required Flowchart flowchart,
    required List<String> debugPath,
  });

  /// Ottiene la sessione corrente
  DebugSession? getCurrentSession();

  /// Esegue il prossimo step
  Future<ExecutionResult> executeNextStep();

  /// Torna al passo precedente
  Future<void> previousStep();

  /// Aggiorna le variabili della sessione
  Future<void> updateVariables(Map<String, dynamic> variables);

  /// Ottiene le variabili correnti
  Map<String, dynamic> getVariables();

  /// Stream delle variabili (per la UI)
  Stream<Map<String, dynamic>> watchVariables();

  /// Valuta una condizione/decisione
  Future<bool> evaluateCondition({
    required List<ConditionClause> clauses,
    required String logicalJoin,
  });

  /// Aggiorna il debug path (es. dopo una decisione)
  Future<void> updateDebugPath(List<String> newPath, {int? newIndex});

  /// Termina la sessione di debug
  Future<void> endSession();

  /// Controlla se può tornare indietro
  bool canGoBack();

  /// Salva uno snapshot dello stato
  void saveSnapshot();

  /// Ottiene lo storico degli snapshot
  List<DebugSnapshot> getHistory();

  /// Sincronizza i flowchart del progetto con la versione più recente (in memoria/unsaved)
  Future<void> syncProjectFlowcharts(Map<String, Flowchart> projectFlowcharts);
}
