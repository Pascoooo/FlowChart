import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_event.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_state.dart';
import 'console_models.dart';
import 'console_entry_widget.dart';
import 'debug_engine.dart';

class DebugConsole extends StatefulWidget {
  final FlowNode currentNode;
  final String flowchartId;
  final dynamic projectRepo;
  final List<VariableDeclaration> allVariables;
  final VoidCallback onCommandExecuted;

  const DebugConsole({
    super.key,
    required this.currentNode,
    required this.flowchartId,
    required this.projectRepo,
    required this.allVariables,
    required this.onCommandExecuted,
  });

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  late DebugEngine _engine;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ConsoleEntry> _history = [];
  bool _isWaitingForInput = false;

  @override
  void initState() {
    super.initState();
    _initializeEngine();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentNode.id != oldWidget.currentNode.id) {
      _initializeEngine();
    }
  }

  void _initializeEngine() {
    final bloc = context.read<FlowchartBloc>();
    final state = bloc.state;
    bool isReentry = false;

    if (state is FlowchartLoaded && widget.currentNode is DoWhileNode) {
      final currentIndex = state.debugIndex;
      if (currentIndex > 0 && state.debugPath.length > currentIndex) {
        final prevId = state.debugPath[currentIndex - 1];
        final currId = widget.currentNode.id;
        final arrivedViaLoop = state.flowchart.edges.any(
              (e) => e.from == prevId && e.to == currId && e.port == 'loop',
        );
        isReentry = arrivedViaLoop;
      } else {
        isReentry = false;
      }
    }

    bool isInSubprogram = false;
    if (state is FlowchartLoaded) {
      isInSubprogram = state.callStack.depth > 0;
    }

    _engine = DebugEngine(
      currentNode: widget.currentNode,
      flowchartId: widget.flowchartId,
      projectRepo: widget.projectRepo,
      allVariables: widget.allVariables,
      onHistoryUpdate: _handleHistoryUpdate,
      onCommandExecuted: widget.onCommandExecuted,
      onDebugExit: () {
        context.read<FlowchartBloc>().add(const DebugExit());
      },
      onDebugNext: () {
        context.read<FlowchartBloc>().add(const DebugNextNode());
      },
      onDebugPrev: () {
        context.read<FlowchartBloc>().add(const DebugPrevNode());
      },
      onDecisionEvaluated: (String nodeId, bool result) {
        context.read<FlowchartBloc>().add(DebugDecisionEvaluated(nodeId, result));
      },
      isDoWhileReentry: isReentry,
      onStepIntoSubprogram: (ProcessNode node) {
        context.read<FlowchartBloc>().add(DebugStepIntoSubprogram(node));
      },
      onReturnFromSubprogram: ({dynamic returnValue}) {
        _handleReturnFromSubprogram(returnValue: returnValue);
      },
      isInSubprogram: isInSubprogram,
    );
  }

  Future<void> _handleReturnFromSubprogram({dynamic returnValue}) async {
    final bloc = context.read<FlowchartBloc>();
    final state = bloc.state;

    if (state is! FlowchartLoaded || state.callStack.isEmpty) return;

    try {
      final sessionVars = await widget.projectRepo.getDebugVariables(
        projectId: widget.flowchartId,
      );

      final returnVar = widget.allVariables
          .where((v) => v.scope == VariableScope.output)
          .firstOrNull;

      dynamic finalReturnValue = returnValue;
      if (returnVar != null && sessionVars.containsKey(returnVar.name)) {
        finalReturnValue = sessionVars[returnVar.name];
      }

      final currentFrame = state.callStack.current;
      if (currentFrame?.callerNodeId == null) return;

      final callerFlowchart = state.projectFlowcharts.values.firstWhere(
            (f) => f.nodes.any((n) => n.id == currentFrame!.callerNodeId),
        orElse: () => state.flowchart,
      );

      final callerNode = callerFlowchart.nodes
          .firstWhere((n) => n.id == currentFrame!.callerNodeId);

      if (callerNode is ProcessNode &&
          callerNode.resultTarget != null &&
          callerNode.resultTarget!.trim().isNotEmpty &&
          finalReturnValue != null) {

        final resultVar = callerNode.resultTarget!.trim();

        await widget.projectRepo.updateDebugVariables(
          projectId: callerFlowchart.flowchartId,
          variables: {resultVar: finalReturnValue},
        );
      }

      bloc.add(DebugReturnFromSubprogram(returnValue: finalReturnValue));

    } catch (e) {
      debugPrint('⚠️ Errore nel ritorno dal sottoprogramma: $e');
    }
  }

  void _handleHistoryUpdate(List<ConsoleEntry> history) {
    if (!mounted) return;
    setState(() {
      _history = history;
      _isWaitingForInput = _engine.isWaitingForInput;
    });
    _scrollToBottom();
  }

  void _handleInput(String input) {
    final trimmedInput = input.trim();

    if (trimmedInput.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
      return;
    }

    _inputController.clear();
    _engine.handleInput(trimmedInput);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
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
    _inputController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF3F3F3),
        border: Border(
          top: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(theme),
          _buildHistoryArea(theme),
          _buildInputArea(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          bottom: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          FaIcon(
            FontAwesomeIcons.terminal,
            size: 14,
            color: theme.accentColor.defaultBrushFor(theme.brightness),
          ),
          const SizedBox(width: 8),
          Text(
            'Console Debug',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.resources.textFillColorPrimary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(FluentIcons.chevron_left, size: 14),
            onPressed: () {
              context.read<FlowchartBloc>().add(const DebugPrevNode());
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.chevron_right, size: 14),
            onPressed: () {
              context.read<FlowchartBloc>().add(const DebugNextNode());
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, size: 14),
            onPressed: () {
              context.read<FlowchartBloc>().add(const DebugExit());
            },
            style: ButtonStyle(
              padding: WidgetStateProperty.all(const EdgeInsets.all(6)),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.isHovered) {
                  return Colors.red.withValues(alpha: 0.2);
                }
                return Colors.transparent;
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryArea(FluentThemeData theme) {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _history.length,
        itemBuilder: (context, index) {
          return ConsoleEntryWidget(entry: _history[index]);
        },
      ),
    );
  }

  Widget _buildInputArea(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          top: BorderSide(
            color: theme.resources.dividerStrokeColorDefault,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '>',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: theme.accentColor.defaultBrushFor(theme.brightness),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextBox(
              controller: _inputController,
              focusNode: _focusNode,
              placeholder: _isWaitingForInput
                  ? 'Inserisci valore...'
                  : 'Usa "help" per visualizzare i comandi disponibili',
              enabled: true,
              style: const TextStyle(
                fontFamily: 'Consolas',
                fontSize: 13,
              ),
              onSubmitted: _handleInput,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => _handleInput(_inputController.text),
            child: const Text('Invio'),
          ),
        ],
      ),
    );
  }
}