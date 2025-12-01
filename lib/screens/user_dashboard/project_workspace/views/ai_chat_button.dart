import 'package:fluent_ui/fluent_ui.dart';

/// Bottone per aprire la chat AI con icona robot
class AiChatButton extends StatelessWidget {
  final VoidCallback onTap;

  const AiChatButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Tooltip(
      message: 'Assistente AI UniChart',
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.accentColor,
              theme.accentColor.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.accentColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          onPressed: onTap,
          style: ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          ),
          icon: const Icon(
            FluentIcons.robot,
            color: Colors.white,
            size: 25,
          ),
        ),
      ),
    );
  }
}

