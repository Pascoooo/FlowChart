import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../../blocs/flowchart_bloc/flowchart_state.dart';

/// 📊 Step Info Card - Mostra il progresso corrente del debug
class DebugStepInfoCard extends StatelessWidget {
  const DebugStepInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return BlocBuilder<FlowchartBloc, FlowchartState>(
      builder: (context, state) {
        if (state is FlowchartLoaded && state.isDebugMode) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.accentColor.defaultBrushFor(theme.brightness),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: theme.accentColor
                      .defaultBrushFor(theme.brightness)
                      .withValues(alpha: 0.3),
                  offset: const Offset(0, 4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  FontAwesomeIcons.locationDot,
                  size: 16,
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : Colors.black,
                ),
                const SizedBox(width: 10),
                Text(
                  'Step ${state.debugIndex + 1} / ${state.debugPath.length}',
                  style: TextStyle(
                    color: theme.brightness == Brightness.light
                        ? Colors.white
                        : Colors.black,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
