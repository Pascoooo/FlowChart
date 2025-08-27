import 'package:flutter/material.dart';
import 'dart:js' as js;

class WorkAreaToolbar extends StatelessWidget {
  const WorkAreaToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
        icon: const Icon(Icons.edit),
        label: const Text("Edit"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        onPressed: () {
          final baseUrl = Uri.base.toString().split('#')[0];
          js.context.callMethod('open', [
            '$baseUrl#/drawing-editor',
            '_blank',
            'width=1200,height=800,left=100,top=100,resizable=yes,scrollbars=yes,status=yes'
          ]);
        });
  }
}
