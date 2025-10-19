import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:debug_repository/debug_repository.dart';
import '../../../../../blocs/debug_bloc/debug_bloc_exports.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../../../blocs/project_bloc/project_bloc.dart';
import 'debug_ui_components.dart';

/// 📊 Session Variables Panel - Pannello variabili di sessione
class SessionVariablesPanel extends StatelessWidget {
  const SessionVariablesPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<DebugBloc, DebugState>(
      builder: (context, debugState) {
        // Mostra il pannello anche quando siamo in attesa input
        if (debugState is! DebugInProgress && debugState is! DebugAwaitingInput) {
          return Center(
            child: Text(
              'Nessuna sessione di debug attiva',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }

        // Ottieni il flowchart corrente dal FlowchartBloc
        final flowchartState = context.read<FlowchartBloc>().state;
        if (flowchartState is! FlowchartLoaded) {
          return Center(
            child: Text(
              'Flowchart non caricato',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }

        final session = (debugState is DebugInProgress)
            ? debugState.session
            : (debugState as DebugAwaitingInput).session;

        final currentNodeId = (debugState is DebugInProgress)
            ? debugState.currentNodeId
            : (debugState as DebugAwaitingInput).currentNodeId;

        final currentNode = flowchartState.getNodeById(currentNodeId);
        if (currentNode == null) {
          return Center(
            child: Text(
              'Nodo non trovato',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, session, theme),
            const SizedBox(height: 16),

            // Lista variabili - usa le variabili dallo stato del debug
            Expanded(
              child: _buildVariablesList(
                context,
                flowchartState,
                session.variables,
                currentNode,
                theme,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, DebugSession session, FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.cardStrokeColorDefault),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.accentColor
                  .defaultBrushFor(theme.brightness)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FaIcon(
              FontAwesomeIcons.database,
              size: 18,
              color: theme.accentColor.defaultBrushFor(theme.brightness),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Variabili di Sessione',
                  style: theme.typography.subtitle?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Step ${session.currentIndex + 1} / ${session.debugPath.length}',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariablesList(
    BuildContext context,
    FlowchartLoaded state,
    Map<String, dynamic> variables,
    FlowNode currentNode,
    FluentThemeData theme,
  ) {
    // ✨ Unisci dichiarazioni: variabili del flowchart + parametri della signature (come Input)
    final paramDecls = state.flowchart.signature.parameters
        .map((p) => VariableDeclaration(name: p.name, dataType: p.type, scope: VariableScope.input))
        .toList();
    final allDecls = <VariableDeclaration>[...state.flowchart.variables, ...paramDecls];

    // ✨ Completa la mappa variabili con eventuali parametri mancanti (mostrati come null)
    final augmentedVars = Map<String, dynamic>.from(variables);
    for (final p in paramDecls) {
      augmentedVars.putIfAbsent(p.name, () => null);
    }

    final filteredEntries = _filterVariablesByScope(
      augmentedVars,
      state,
      currentNode,
    );

    if (filteredEntries.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Raggruppa per scope con tipo e valore usando le dichiarazioni complete
    final inputVars = _getVariablesByScope(filteredEntries, allDecls, VariableScope.input);
    final outputVars = _getVariablesByScope(filteredEntries, allDecls, VariableScope.output);
    final localVars = _getVariablesByScope(filteredEntries, allDecls, VariableScope.local);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inputVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Input',
              icon: FontAwesomeIcons.arrowRight,
              variables: inputVars,
              allVariables: allDecls,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
          ],
          if (outputVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Output',
              icon: FontAwesomeIcons.arrowLeft,
              variables: outputVars,
              allVariables: allDecls,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          if (localVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Di Lavoro',
              icon: FontAwesomeIcons.wrench,
              variables: localVars,
              allVariables: allDecls,
              color: Colors.orange,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.boxOpen,
              size: 48,
              color: theme.resources.textFillColorTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna variabile in questo scope',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<MapEntry<String, dynamic>> _filterVariablesByScope(
    Map<String, dynamic> variables,
    FlowchartLoaded state,
    FlowNode currentNode,
  ) {
    // Semplificato: mostra tutte le variabili che hanno un valore (incluso null per visualizzazione)
    return variables.entries.toList();
  }

  List<MapEntry<String, dynamic>> _getVariablesByScope(
    List<MapEntry<String, dynamic>> entries,
    List<VariableDeclaration> declarations,
    VariableScope scope,
  ) {
    return entries.where((e) {
      // Cerca dichiarazione nella lista completa (variabili + parametri)
      VariableDeclaration? decl;
      try {
        decl = declarations.firstWhere((v) => v.name == e.key);
      } catch (_) {
        decl = null;
      }
      if (decl == null) return false;
      return decl.scope == scope;
    }).toList();
  }
}

/// 🎨 Variable Scope Section
class VariableScopeSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MapEntry<String, dynamic>> variables;
  final List<VariableDeclaration> allVariables;
  final Color color;

  const VariableScopeSection({
    super.key,
    required this.title,
    required this.icon,
    required this.variables,
    required this.allVariables,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header sezione con gradiente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: isDark ? 0.2 : 0.15),
                  color.withValues(alpha: isDark ? 0.1 : 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),

          // Header colonne moderno
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                ? const Color(0xFF2D2D30)
                : const Color(0xFFF5F5F5),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'NOME',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: theme.resources.textFillColorSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Text(
                    'TIPO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: theme.resources.textFillColorSecondary,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 4,
                  child: Text(
                    'VALORE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: theme.resources.textFillColorSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Variabili
          ...variables.map((entry) {
            // Trova la dichiarazione della variabile per ottenere il tipo
            final varDecl = allVariables.firstWhere(
              (v) => v.name == entry.key,
              orElse: () => const VariableDeclaration(
                name: '_',
                dataType: 'unknown',
                scope: VariableScope.local,
              ),
            );

            // Il valore può essere null se non è ancora stato assegnato
            final hasValue = entry.value != null;

            return DebugVariableRow(
              name: entry.key,
              type: varDecl.dataType,
              value: hasValue ? entry.value.toString() : 'null',
            );
          }),
        ],
      ),
    );
  }
}
