import 'package:flutter/material.dart';

class DashboardItem {
  final IconData icon;
  final IconData activeIcon;
  final String title;
  final String? subtitle;

  DashboardItem({
    required this.icon,
    required this.activeIcon,
    required this.title,
    this.subtitle,
  });
}

class SidebarSection {
  final IconData icon;
  final String title;
  final List<SidebarItem> children;

  SidebarSection({
    required this.icon,
    required this.title,
    required this.children,
  });
}

class SidebarItem {
  final String title;
  final IconData? icon;

  SidebarItem({
    required this.title,
    this.icon,
  });
}