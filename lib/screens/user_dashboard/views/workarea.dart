import 'package:flutter/material.dart';

class WorkArea extends StatelessWidget {
  static final GlobalKey workareaKey = GlobalKey();

  const WorkArea({super.key});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: workareaKey,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                "Area di lavoro attiva",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Il tuo diagramma apparirà qui",
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}