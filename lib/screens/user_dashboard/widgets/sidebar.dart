import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import 'sidebar_menu.dart';

class Sidebar extends StatefulWidget {
  final bool isCollapsed;
  final bool projectActive;
  final void Function(bool projectIsActive) onProjectStateChanged;
  final void Function(String type) onProjectListRequested;

  const Sidebar({
    super.key,
    required this.isCollapsed,
    required this.projectActive,
    required this.onProjectStateChanged,
    required this.onProjectListRequested,
  });

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _shimmerController;
  late Animation<double> _floatingAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _floatingController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _floatingAnimation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(
      parent: _floatingController,
      curve: Curves.easeInOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -1,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    _floatingController.repeat(reverse: true);
    _shimmerController.repeat();
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: widget.isCollapsed ? 80 : 280,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            theme.colorScheme.surface.withOpacity(0.95),
            theme.colorScheme.surfaceVariant.withOpacity(0.1),
          ],
        ),
        border: Border(
          right: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(4, 0),
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.03),
            blurRadius: 40,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          _buildDivider(context),
          Expanded(
            child: SidebarMenu(
              isCollapsed: widget.isCollapsed,
              projectActive: widget.projectActive,
              onProjectSelected: () => widget.onProjectStateChanged(true),
              onProjectListRequested: widget.onProjectListRequested,
            ),
          ),
          _buildDivider(context),
          _buildBottomActions(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 100,
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCollapsed ? 16 : 24,
        vertical: 20,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnimation.value),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                        theme.colorScheme.secondary.withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Shimmer effect
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedBuilder(
                            animation: _shimmerAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shimmerAnimation.value * 30, 0),
                                child: Container(
                                  width: 20,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        Colors.white.withOpacity(0.3),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const Center(
                        child: FaIcon(
                          FontAwesomeIcons.diagramProject,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (!widget.isCollapsed) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "uniChart",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 1,
      margin: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            theme.colorScheme.outline.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildModernMenuItem(
            context,
            icon: FontAwesomeIcons.user,
            title: "Account",
            onTap: () => _showAccountSettings(context),
          ),
          const SizedBox(height: 8),
          _buildModernMenuItem(
            context,
            icon: FontAwesomeIcons.gear,
            title: "Impostazioni",
            onTap: () => context.go('/settings'),
          ),
          const SizedBox(height: 8),
          _buildModernMenuItem(
            context,
            icon: FontAwesomeIcons.rightFromBracket,
            title: "Logout",
            onTap: () {
              context.read<AuthenticationBloc>().add(
                const AuthenticationLogoutRequested(),
              );
            },
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  void _showAccountSettings(BuildContext context) {
    // Implementa navigazione verso impostazioni account
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Account"),
        content: const Text("Impostazioni account in arrivo..."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Chiudi"),
          ),
        ],
      ),
    );
  }

  Widget _buildModernMenuItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
        bool isDestructive = false,
      }) {
    final theme = Theme.of(context);

    return _ModernMenuItem(
      icon: icon,
      title: title,
      onTap: onTap,
      isCollapsed: widget.isCollapsed,
      isDestructive: isDestructive,
      theme: theme,
    );
  }
}

class _ModernMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isCollapsed;
  final bool isDestructive;
  final ThemeData theme;

  const _ModernMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isCollapsed,
    required this.isDestructive,
    required this.theme,
  });

  @override
  State<_ModernMenuItem> createState() => _ModernMenuItemState();
}

class _ModernMenuItemState extends State<_ModernMenuItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = widget.isDestructive
        ? ColorScheme.fromSeed(seedColor: Colors.red)
        : widget.theme.colorScheme;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: GestureDetector(
              onTapDown: (_) {
                setState(() => _isPressed = true);
                _scaleController.forward();
              },
              onTapUp: (_) {
                setState(() => _isPressed = false);
                _scaleController.reverse();
                widget.onTap();
              },
              onTapCancel: () {
                setState(() => _isPressed = false);
                _scaleController.reverse();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: widget.isCollapsed ? 56 : 52,
                decoration: BoxDecoration(
                  gradient: _isPressed || _isHovered
                      ? LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.1),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  border: _isPressed
                      ? Border.all(
                    color: colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  )
                      : null,
                  boxShadow: _isPressed
                      ? [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                      : null,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isCollapsed ? 0 : 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: widget.isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (_isPressed || _isHovered)
                              ? colorScheme.primary.withOpacity(0.15)
                              : colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: FaIcon(
                          widget.icon,
                          color: (_isPressed || _isHovered)
                              ? colorScheme.primary
                              : colorScheme.onSurface.withOpacity(0.7),
                          size: 16,
                        ),
                      ),
                      if (!widget.isCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: widget.theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: (_isPressed || _isHovered)
                                  ? colorScheme.primary
                                  : widget.theme.colorScheme.onSurface.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}