import 'package:file_repository/file_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';
import '../../../blocs/file_bloc/file_system_bloc.dart';
import '../../../blocs/file_bloc/file_system_event.dart';
import '../../../blocs/file_bloc/file_system_state.dart';

class ProjectSidebar extends StatefulWidget {

  const ProjectSidebar({
    super.key,
  });

  @override
  State<ProjectSidebar> createState() => _ProjectSidebarState();
}

class _ProjectSidebarState extends State<ProjectSidebar>
    with TickerProviderStateMixin {
  late AnimationController _floatingController;
  late AnimationController _shimmerController;
  late Animation<double> _floatingAnimation;

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

    return BlocListener<FileSystemBloc, FileSystemState>(
      listener: (context, state) {
        if (state is FileSystemLoaded) {
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: theme.colorScheme.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }

          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: theme.colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else if (state is FileSystemError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        width: 320,
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
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildDivider(context),
            _buildCreateProjectButton(context),
            _buildDivider(context),
            Expanded(child: _buildFileSystemView()),
            _buildDivider(context),
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _floatingAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatingAnimation.value),
                child: child,
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Unichart",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    "AI-Powered Diagrams",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }

  Widget _buildCreateProjectButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: _buildModernMenuItem(
        context,
        icon: FontAwesomeIcons.plus,
        title: "Nuovo File",
        onTap: () => _showCreateDialog(context, false, null),
        isPrimaryAction: true,
      ),
    );
  }

  Widget _buildFileSystemView() {
    return BlocBuilder<FileSystemBloc, FileSystemState>(
      builder: (context, state) {
        if (state is FileSystemLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is FileSystemError) {
          return _buildErrorView(state.message);
        }

        if (state is FileSystemLoaded) {
          final projects = state.files;

          if (projects.isEmpty) {
            return _buildEmptyProjectsView();
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              return _buildProjectTile(project);
            },
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildErrorView(String message) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Errore',
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onErrorContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProjectsView() {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: theme.colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Nessun File',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea il tuo primo file per iniziare',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectTile(MyFile project) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.read<FileSystemBloc>().add(
              OpenFile(fileId: project.fileId, fileName: project.name),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    project.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
              context.read<AuthenticationBloc>().add(const AuthenticationLogoutRequested());
            },
            isDestructive: true,
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
        bool isPrimaryAction = false,
      }) {
    final theme = Theme.of(context);

    return _ModernMenuItem(
      icon: icon,
      title: title,
      onTap: onTap,
      isDestructive: isDestructive,
      isPrimaryAction: isPrimaryAction,
      theme: theme,
    );
  }

  void _showCreateDialog(BuildContext context, bool isDirectory, String? parentId) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isDirectory ? 'Nuova Cartella' : 'Nuovo File'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: isDirectory ? 'Nome cartella' : 'Nome file',
            border: const OutlineInputBorder(),
            hintText: isDirectory ? 'Es. Documenti' : 'Es. diagramma.draw',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                context
                    .read<FileSystemBloc>()
                    .add(CreateNewFile(fileName: nameController.text));
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Crea'),
          ),
        ],
      ),
    );
  }
}

class _ModernMenuItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isPrimaryAction;
  final ThemeData theme;

  const _ModernMenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.isDestructive,
    required this.isPrimaryAction,
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
    final baseColorScheme = widget.theme.colorScheme;
    final colorScheme = widget.isDestructive
        ? ColorScheme.fromSeed(seedColor: Colors.red, brightness: widget.theme.brightness)
        : baseColorScheme;

    final bool isHighlighted = _isHovered || _isPressed;

    final Color iconColor;
    final Color textColor;
    final Gradient? backgroundGradient;
    final List<BoxShadow>? boxShadow;

    if (widget.isPrimaryAction) {
      iconColor = baseColorScheme.onPrimary;
      textColor = baseColorScheme.onPrimary;
      backgroundGradient = LinearGradient(
        colors: [
          baseColorScheme.primary,
          baseColorScheme.secondary,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      boxShadow = [
        BoxShadow(
          color: baseColorScheme.primary.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];
    } else {
      iconColor = isHighlighted
          ? colorScheme.primary
          : colorScheme.onSurface.withOpacity(0.7);
      textColor = isHighlighted
          ? colorScheme.primary
          : baseColorScheme.onSurface.withOpacity(0.8);
      backgroundGradient = isHighlighted
          ? LinearGradient(colors: [
        colorScheme.primary.withOpacity(0.1),
        colorScheme.primary.withOpacity(0.05),
      ])
          : null;
      boxShadow = null;
    }

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  gradient: backgroundGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: boxShadow,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    FaIcon(widget.icon, size: 18, color: iconColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: widget.theme.textTheme.labelLarge?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

