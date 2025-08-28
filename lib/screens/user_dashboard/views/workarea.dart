import 'package:flutter/material.dart';

class WorkArea extends StatelessWidget {
  const WorkArea({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: const Center(
        child: Text("Area di lavoro attiva"),
      ),
    );
  }
}