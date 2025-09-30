import 'dart:math';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flowchart_repository/flowchart_repository.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';
import '../../../user_dashboard/project_workspace/views/painters.dart';

/// Preview statica di un flowchart (solo visualizzazione).
class FlowchartPreview extends StatelessWidget {
  final String flowchartContent;
  final bool showGrid;
  final bool emphasizeBorders;
  final bool showUnsavedBadge;

  const FlowchartPreview({
    super.key,
    required this.flowchartContent,
    this.showGrid = true,
    this.emphasizeBorders = true,
    this.showUnsavedBadge = false,
  });

  FlowchartLoaded _parse(String raw) {
    if (raw.trim().isEmpty) return FlowchartLoaded.empty();
    try {
      return FlowchartLoaded.fromJson(raw);
    } catch (e) {
      debugPrint('FlowchartPreview parse error: $e');
      return FlowchartLoaded.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _parse(flowchartContent);
    final theme = FluentTheme.of(context);
    final primary = theme.accentColor;
    final borderColor = emphasizeBorders
        ? primary.withAlpha((0.85 * 255).round())
        : theme.inactiveColor;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: emphasizeBorders ? 3 : 1.2,
          ),
          boxShadow: emphasizeBorders
              ? [
            BoxShadow(
              color: primary.withAlpha((0.18 * 255).round()),
              blurRadius: 14,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withAlpha((0.05 * 255).round()),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            _StaticFlowchartViewport(
              nodes: state.flowchart.nodes,
              edges: state.flowchart.edges,
              showGrid: showGrid,
              emphasized: emphasizeBorders,
            ),
            if (emphasizeBorders)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withAlpha((0.35 * 255).round()),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            if (showUnsavedBadge)
              const Positioned(
                top: 8,
                left: 10,
                child: _UnsavedBadge(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnsavedBadge extends StatelessWidget {
  const _UnsavedBadge();
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final bg = Colors.red.lighter.withValues(alpha: 0.9);
    final txt = Colors.red.darkest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.light.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FontAwesomeIcons.triangleExclamation,
              color: txt, size: 14),
          const SizedBox(width: 6),
          Text(
            'Versione non salvata',
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
              color: txt,
            ),
          ),
        ],
      ),
    );
  }
}

class _StaticFlowchartViewport extends StatelessWidget {
  final List<FlowNode> nodes;
  final List<FlowchartEdge> edges;
  final bool showGrid;
  final bool emphasized;

  const _StaticFlowchartViewport({
    required this.nodes,
    required this.edges,
    required this.showGrid,
    required this.emphasized,
  });

  @override
  Widget build(BuildContext context) {
    if (nodes.isEmpty) {
      return Stack(
        children: [
          if (showGrid)
            Positioned.fill(
                child: CustomPaint(painter: _previewGrid(context, emphasized))),
          Center(
            child: Text(
              'Diagramma Vuoto',
              style: FluentTheme.of(context).typography.body?.copyWith(
                  color:
                  FluentTheme.of(context).brightness == Brightness.light
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  letterSpacing: 0.3),
            ),
          ),
        ],
      );
    }


    Rect? bounds;
    for (final node in nodes) {
      final rect = Rect.fromLTWH(node.x, node.y, node.width, node.height);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    bounds ??= const Rect.fromLTWH(0, 0, 100, 60);

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 20.0;
        final availW = max(10.0, constraints.maxWidth - padding * 2);
        final availH = max(10.0, constraints.maxHeight - padding * 2);
        final scaleX = availW / bounds!.width;
        final scaleY = availH / bounds.height;
        final scale = min(min(scaleX, scaleY), 1.0);

        final scaledContentW = bounds.width * scale;
        final scaledContentH = bounds.height * scale;
        final offsetX =
            (constraints.maxWidth - scaledContentW) / 2 - bounds.left * scale;
        final offsetY =
            (constraints.maxHeight - scaledContentH) / 2 - bounds.top * scale;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (showGrid)
              Positioned.fill(
                child: CustomPaint(painter: _previewGrid(context, emphasized)),
              ),
            Transform.translate(
              offset: Offset(offsetX, offsetY),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: ConnectionPainter(
                            nodes: nodes,
                            edges: edges, theme: FluentTheme.of(context),
                          ),
                        ),
                      ),
                      for (final node in nodes)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          child: _StaticNode(node: node),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  GridPainter _previewGrid(BuildContext context, bool emphasized) {
    final theme = FluentTheme.of(context);
    if (!emphasized) return GridPainter.fromTheme(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.white : Colors.black;
    return GridPainter(
      minorColor: base.withAlpha(((isDark ? 0.22 : 0.16) * 255).round()),
      majorColor: base.withAlpha(((isDark ? 0.55 : 0.42) * 255).round()),
      spacing: 24,
      minorWidth: 1.1,
      majorWidth: 1.9,
      majorEvery: 4,
    );
  }
}

class _StaticNode extends StatelessWidget {
  final FlowNode node;
  const _StaticNode({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    // Testo sempre scuro perché il fill è sempre bianco
    final textStyle = theme.typography.caption?.copyWith(
      color: Colors.black.withValues(alpha: 0.85),
    );
    final borderColor = theme.inactiveColor;
    // Riempimento sempre bianco nel preview
    final fillColor = Colors.white;
    const borderWidth = 1.5;

    switch (node.kind) {
      case FlowNodeKind.decision:
        return CustomPaint(
          painter: DiamondPainter(
            color: fillColor,
            borderColor: borderColor,
            strokeWidth: borderWidth,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  node.text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      case FlowNodeKind.input:
        return CustomPaint(
          painter: ParallelogramPainter(
            fillColor: fillColor,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: false,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  node.text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      case FlowNodeKind.output:
        return CustomPaint(
          painter: ParallelogramPainter(
            fillColor: fillColor,
            borderColor: borderColor,
            strokeWidth: borderWidth,
            reversed: true,
          ),
          child: SizedBox(
            width: node.width,
            height: node.height,
            child: Center(
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  node.text,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      default: // Per Start, End, Process
        return Container(
          width: node.width,
          height: node.height,
          decoration: BoxDecoration(
            color: Colors.white, // fill sempre bianco
            borderRadius: BorderRadius.circular(
              (node.kind == FlowNodeKind.start || node.kind == FlowNodeKind.end)
                  ? 999
                  : 8,
            ),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: Text(
            node.text,
            textAlign: TextAlign.center,
            style: textStyle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        );
    }
  }
}
