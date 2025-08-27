import 'package:flutter/material.dart';
import 'dashboard_item.dart';

class SidebarMenu extends StatefulWidget {
  final bool isCollapsed;
  final bool projectActive;
  final VoidCallback onProjectSelected;
  final void Function(String type) onProjectListRequested;

  const SidebarMenu({
    super.key,
    required this.isCollapsed,
    required this.projectActive,
    required this.onProjectSelected,
    required this.onProjectListRequested,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {

  @override
  Widget build(BuildContext context) {
    return Container();
  }

}