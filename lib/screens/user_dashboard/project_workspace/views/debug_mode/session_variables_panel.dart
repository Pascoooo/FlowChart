import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is! FlowchartLoaded || !state.isDebugMode) {
          return Center(
            child: Text(
              'Nessuna sessione di debug attiva',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }

        final currentNodeId = state.selectedNodeId;
        if (currentNodeId == null) {
          return Center(
            child: Text(
              'Nessun nodo selezionato',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }

        final currentNode = state.getNodeById(currentNodeId);
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

        final projectRepo = context.read<ProjectBloc>().projectRepository;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, state, theme),
            const SizedBox(height: 16),

            // Lista variabili
            Expanded(
              child: StreamBuilder<Map<String, dynamic>>(
                stream: projectRepo.watchDebugVariables(
                    projectId: state.flowchart.flowchartId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: ProgressRing());
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState(theme, snapshot.error.toString());
                  }

                  final variables = snapshot.data ?? {};
                  return _buildVariablesList(context, state, variables, currentNode, theme);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, FlowchartLoaded state, FluentThemeData theme) {
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
                  'Step ${state.debugIndex + 1} / ${state.debugPath.length}',
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

  Widget _buildErrorState(FluentThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.triangleExclamation,
              size: 32,
              color: theme.resources.systemFillColorCritical,
            ),
            const SizedBox(height: 12),
            Text(
              'Errore caricamento variabili',
              style: theme.typography.bodyStrong?.copyWith(
                color: theme.resources.systemFillColorCritical,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    final filteredEntries = _filterVariablesByScope(
      variables,
      state,
      currentNode,
    );

    if (filteredEntries.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Raggruppa per scope con tipo e valore
    final inputVars = _getVariablesByScope(filteredEntries, state, VariableScope.input);
    final outputVars = _getVariablesByScope(filteredEntries, state, VariableScope.output);
    final localVars = _getVariablesByScope(filteredEntries, state, VariableScope.local);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (inputVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Input',
              icon: FontAwesomeIcons.arrowRight,
              variables: inputVars,
              allVariables: state.flowchart.variables,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
          ],
          if (outputVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Output',
              icon: FontAwesomeIcons.arrowLeft,
              variables: outputVars,
              allVariables: state.flowchart.variables,
              color: Colors.green,
            ),
            const SizedBox(height: 16),
          ],
          if (localVars.isNotEmpty) ...[
            VariableScopeSection(
              title: 'Di Lavoro',
              icon: FontAwesomeIcons.wrench,
              variables: localVars,
              allVariables: state.flowchart.variables,
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
    final debugIndex = state.debugIndex;

    bool _encounteredInDecision(String varName) {
      for (int i = 0; i <= debugIndex; i++) {
        final nodeId = state.debugPath[i];
        final node = state.getNodeById(nodeId);
        if (node is DecisionNode) {
          // Check structured clauses
          if (node.clauses.isNotEmpty) {
            final used = node.clauses.any((c) {
              final leftMatch = c.leftOperand == varName;
              final rightMatch = !c.isRightLiteral && c.rightOperand == varName;
              return leftMatch || rightMatch;
            });
            if (used) return true;
          } else {
            // Legacy string condition
            final pattern = RegExp(r'\b' + RegExp.escape(varName) + r'\b');
            if (pattern.hasMatch(node.condition)) return true;
          }
        }
      }
      // Also consider current node if it's a Decision
      if (currentNode is DecisionNode) {
        final node = currentNode as DecisionNode;
        if (node.clauses.isNotEmpty) {
          final used = node.clauses.any((c) {
            final leftMatch = c.leftOperand == varName;
            final rightMatch = !c.isRightLiteral && c.rightOperand == varName;
            return leftMatch || rightMatch;
          });
          if (used) return true;
        } else {
          final pattern = RegExp(r'\b' + RegExp.escape(varName) + r'\b');
          if (pattern.hasMatch(node.condition)) return true;
        }
      }
      return false;
    }

    bool _encounteredInAssignment(String varName) {
      for (int i = 0; i <= debugIndex; i++) {
        final nodeId = state.debugPath[i];
        final node = state.getNodeById(nodeId);
        if (node is AssignmentNode) {
          if (node.assignments.any((a) => a.target == varName)) return true;
        }
      }
      if (currentNode is AssignmentNode) {
        final node = currentNode as AssignmentNode;
        if (node.assignments.any((a) => a.target == varName)) return true;
      }
      return false;
    }

    bool _encounteredInOutput(String varName) {
      for (int i = 0; i <= debugIndex; i++) {
        final nodeId = state.debugPath[i];
        final node = state.getNodeById(nodeId);
        if (node is OutputNode) {
          if (node.variables.any((v) => v.name == varName)) return true;
        }
      }
      if (currentNode is OutputNode) {
        final node = currentNode as OutputNode;
        if (node.variables.any((v) => v.name == varName)) return true;
      }
      return false;
    }

    return variables.entries.where((entry) {
      final varName = entry.key;
      final decl = state.flowchart.variables.firstWhere(
        (v) => v.name == varName,
        orElse: () => const VariableDeclaration(name: '_', dataType: 'string'),
      );

      if (decl.name == '_') return true; // unknown -> show

      switch (decl.scope) {
        case VariableScope.input:
          return true; // input sempre visibili
        case VariableScope.output:
          return _encounteredInOutput(varName);
        case VariableScope.local:
          return _encounteredInAssignment(varName) || _encounteredInDecision(varName);
      }
    }).toList();
  }

  List<MapEntry<String, dynamic>> _getVariablesByScope(
    List<MapEntry<String, dynamic>> entries,
    FlowchartLoaded state,
    VariableScope scope,
  ) {
    return entries.where((e) {
      final decl = state.flowchart.variables.firstWhere(
        (v) => v.name == e.key,
        orElse: () => const VariableDeclaration(name: '_', dataType: 'string'),
      );
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
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
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
                  color.withOpacity(isDark ? 0.2 : 0.15),
                  color.withOpacity(isDark ? 0.1 : 0.08),
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
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
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
              value: hasValue ? entry.value.toString() : null,
            );
          }),
        ],
      ),
    );
  }
}
