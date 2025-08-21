import 'package:flutter/material.dart';

class StepProgressIndicator extends StatelessWidget {
  final int totalSteps;
  final int currentStep;
  final List<String> titles;

  const StepProgressIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    required this.titles,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).primaryColor;

    return Column(
      children: [
        Row(
          children: List.generate(totalSteps * 2 - 1, (i) {
            if (i.isOdd) {
              final lineIndex = (i - 1) ~/ 2;
              final isActive = lineIndex < currentStep;
              return Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: isActive ? (isDark ? const Color(0xFF06BEE1) : primary) : (isDark ? const Color(0xFF374151) : Colors.grey[300]),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              );
            } else {
              final stepIndex = i ~/ 2;
              final isCurrent = stepIndex == currentStep;
              final isCompleted = stepIndex < currentStep;

              Color circleColor;
              Color textColor;
              if (isCompleted) {
                circleColor = const Color(0xFF06BEE1);
                textColor = Colors.white;
              } else if (isCurrent) {
                circleColor = isDark ? const Color(0xFF06BEE1) : primary;
                textColor = Colors.white;
              } else {
                circleColor = isDark ? const Color(0xFF2D3748) : Colors.grey[300]!;
                textColor = isDark ? const Color(0xFF9CA3AF) : Colors.grey[600]!;
              }

              return Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor,
                  border: isCurrent ? Border.all(color: isDark ? const Color(0xFF38BDF8) : primary, width: 2) : null,
                  boxShadow: (isCurrent || isCompleted)
                      ? [
                    BoxShadow(
                      color: (isDark ? const Color(0xFF06BEE1) : primary).withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : Text('${stepIndex + 1}', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              );
            }
          }),
        ),
        const SizedBox(height: 16),
        Row(
          children: List.generate(totalSteps, (index) {
            return Expanded(
              child: Text(
                titles[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: index == currentStep ? FontWeight.w600 : FontWeight.w400,
                  color: index <= currentStep
                      ? Theme.of(context).textTheme.bodyLarge?.color
                      : Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}