import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  final List<DashboardItem> _menuItems = [
    DashboardItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      title: "Chat",
      subtitle: "Inizia una nuova conversazione",
    ),
    DashboardItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history,
      title: "Cronologia",
      subtitle: "Visualizza chat precedenti",
    ),
    DashboardItem(
      icon: Icons.bookmark_border,
      activeIcon: Icons.bookmark,
      title: "Preferiti",
      subtitle: "Chat salvate",
    ),
    DashboardItem(
      icon: Icons.folder_outlined,
      activeIcon: Icons.folder,
      title: "Progetti",
      subtitle: "I tuoi progetti",
    ),
    DashboardItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      title: "Analytics",
      subtitle: "Statistiche utilizzo",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF7F9FC),
      body: Row(
        children: [
          // Sidebar
          // Sostituisci la sidebar originale con questa versione

          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarCollapsed ? 80 : 280,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "FlowChart AI",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSidebarCollapsed = !_isSidebarCollapsed;
                          });
                        },
                        icon: Icon(
                          _isSidebarCollapsed ? Icons.menu_open : Icons.menu,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Macroaree a menù a tendina
                Expanded(
                  child: _SidebarMacroareas(
                    isCollapsed: _isSidebarCollapsed,
                  ),
                ),

                const Divider(height: 1),

                // Bottom actions
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _buildBottomMenuItem(
                        icon: Icons.settings_outlined,
                        activeIcon: Icons.settings,
                        title: "Impostazioni",
                        onTap: () {
                          context.go('/settings');
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildBottomMenuItem(
                        icon: Icons.brightness_6_outlined,
                        activeIcon: Icons.brightness_6,
                        title: "Tema",
                        onTap: () {
                          Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildBottomMenuItem(
                        icon: Icons.logout_outlined,
                        activeIcon: Icons.logout,
                        title: "Esci",
                        onTap: () {
                          context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
                        },
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Column(
              children: [
                // Top Bar
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF161B22) : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        _menuItems[_selectedIndex].title,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Search bar
                      Container(
                        width: 300,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0D1117)
                              : const Color(0xFFF6F8FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey.withOpacity(0.3)
                                : Colors.grey.withOpacity(0.2),
                          ),
                        ),
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: "Cerca...",
                            prefixIcon: Icon(
                              Icons.search,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Profile
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),

                // Content Area
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(int index) {
    final item = _menuItems[index];
    final isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarCollapsed ? 16 : 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                  : Theme.of(context).colorScheme.primary.withOpacity(0.1))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.activeIcon : item.icon,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  size: 22,
                ),
                if (!_isSidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        if (item.subtitle != null)
                          Text(
                            item.subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isSidebarCollapsed ? 16 : 12,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive
                    ? Colors.red
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 20,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDestructive
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0:
        return _buildChatContent();
      case 1:
        return _buildHistoryContent();
      case 2:
        return _buildFavoritesContent();
      case 3:
        return _buildProjectsContent();
      case 4:
        return _buildAnalyticsContent();
      default:
        return _buildChatContent();
    }
  }

  Widget _buildChatContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Inizia una nuova conversazione",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Chiedi qualsiasi cosa e inizieremo a chattare insieme",
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 40),
            // Quick actions
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildQuickAction(
                  "Scrivi codice",
                  Icons.code,
                  "Aiutami a programmare",
                ),
                _buildQuickAction(
                  "Spiega concetti",
                  Icons.lightbulb_outline,
                  "Spiegami qualcosa",
                ),
                _buildQuickAction(
                  "Risolvi problemi",
                  Icons.psychology,
                  "Ho un problema da risolvere",
                ),
                _buildQuickAction(
                  "Creatività",
                  Icons.brush,
                  "Aiutami a essere creativo",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(String title, IconData icon, String description) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Implementa l'azione
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryContent() {
    return const Center(
      child: Text(
        "Cronologia Chat",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildFavoritesContent() {
    return const Center(
      child: Text(
        "Preferiti",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildProjectsContent() {
    return const Center(
      child: Text(
        "I tuoi Progetti",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return const Center(
      child: Text(
        "Analytics",
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
      ),
    );
  }
}

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

class _SidebarMacroareas extends StatefulWidget {
  final bool isCollapsed;
  const _SidebarMacroareas({required this.isCollapsed});

  @override
  State<_SidebarMacroareas> createState() => _SidebarMacroareasState();
}

class _SidebarMacroareasState extends State<_SidebarMacroareas> {
  int? _expandedSection;

  final List<_SidebarSection> _sections = [
    _SidebarSection(
      icon: Icons.folder,
      title: "Progetti",
      children: [
        _SidebarItem(title: "Recenti"),
        _SidebarItem(title: "I miei progetti"),
        _SidebarItem(title: "Preferiti"),
      ],
    ),
    _SidebarSection(
      icon: Icons.add_box,
      title: "Inserisci",
      children: [
        _SidebarItem(title: "Rettangolo", icon: Icons.crop_16_9),
        _SidebarItem(title: "Cerchio", icon: Icons.circle),
        _SidebarItem(title: "Parallelogramma", icon: Icons.change_history),
        _SidebarItem(title: "Rombo", icon: Icons.diamond),
      ],
    ),
    _SidebarSection(
      icon: Icons.play_arrow,
      title: "Esecuzione",
      children: [
        _SidebarItem(title: "Simula"),
        _SidebarItem(title: "Debug"),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _sections.length,
      itemBuilder: (context, sectionIndex) {
        final section = _sections[sectionIndex];
        final expanded = _expandedSection == sectionIndex;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(section.icon, color: Theme.of(context).colorScheme.primary),
              title: widget.isCollapsed ? null : Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: widget.isCollapsed
                  ? null
                  : Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
              onTap: () {
                setState(() {
                  _expandedSection = expanded ? null : sectionIndex;
                });
              },
              contentPadding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 8 : 16),
            ),
            if (expanded)
              ...section.children.map((item) {
                if (section.title == "Inserisci") {
                  // Drag & Drop per le forme
                  return Padding(
                    padding: EdgeInsets.only(left: widget.isCollapsed ? 16 : 32.0),
                    child: Draggable<String>(
                      data: item.title,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(item.icon, size: 28, color: Theme.of(context).colorScheme.primary),
                            if (!widget.isCollapsed) ...[
                              const SizedBox(width: 8),
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ),
                      child: ListTile(
                        leading: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
                        title: widget.isCollapsed ? null : Text(item.title),
                        dense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 0),
                      ),
                    ),
                  );
                } else {
                  return Padding(
                    padding: EdgeInsets.only(left: widget.isCollapsed ? 16 : 32.0),
                    child: ListTile(
                      title: widget.isCollapsed ? null : Text(item.title),
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 0),
                      onTap: () {
                        // Azione per ogni voce
                      },
                    ),
                  );
                }
              }).toList(),
          ],
        );
      },
    );
  }
}

class _SidebarSection {
  final IconData icon;
  final String title;
  final List<_SidebarItem> children;

  _SidebarSection({required this.icon, required this.title, required this.children});
}

class _SidebarItem {
  final String title;
  final IconData? icon;

  _SidebarItem({required this.title, this.icon});
}

//avvia l'applicazione con il DashboardPage
