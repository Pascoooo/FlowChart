import 'package:flutter/material.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final Widget? status;
  final List<Widget> children;

  const SettingsSection({
    super.key,
    required this.title,
    this.status,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 12),
              if (status != null) status!,
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outline.withOpacity(0.2)),
              color: cs.surfaceContainer.withOpacity(0.5)
          ),
          child: Column(
            children: List.generate(children.length, (index) {
              return Column(
                children: [
                  children[index],
                  if (index < children.length - 1)
                    Divider(height: 1, indent: 72, endIndent: 16, color: cs.outline.withOpacity(0.2)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}