import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flowchart_thesis/config/constants/theme_switch.dart';
import 'dart:js' as js;

import '../../../blocs/auth_bloc/authentication_bloc.dart';
import '../../../blocs/auth_bloc/authentication_event.dart';

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

class _SidebarSection {
  final IconData icon;
  final String title;
  final List<_SidebarItem> children;

  _SidebarSection(
      {required this.icon, required this.title, required this.children});
}

class _SidebarItem {
  final String title;
  final IconData? icon;

  _SidebarItem({required this.title, this.icon});
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isSidebarCollapsed = false;
  bool _projectActive = false;
  bool _drawingMode = false;
  bool _eraserMode = false;
  bool _editingMode = false;
  String? _projectListType; // "recenti", "i miei progetti", "preferiti"

  void _openProject() {
    setState(() {
      _projectActive = true;
      _projectListType = null;
      _drawingMode = false;
      _eraserMode = false;
    });
  }

  void _showProjectList(String type) {
    setState(() {
      _projectActive = false;
      _projectListType = type;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isSidebarCollapsed ? 80 : 280,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
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
                              Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.7),
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
                            "uniChart",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Macroaree a menù a tendina
                Expanded(
                  child: _SidebarMacroareas(
                    isCollapsed: _isSidebarCollapsed,
                    onProjectSelected: _openProject,
                    onProjectListRequested: _showProjectList,
                  ),
                ),

                const Divider(height: 1),

                // Bottom actions (solo Impostazioni)
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
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Stack(
              children: [
                // Ambiente di lavoro o lista progetti
                _projectActive
                    ? Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    margin: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Barra strumenti
                        Container(
                          height: 60,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: _editingMode
                                ? [
                              // Barra degli strumenti per la modalità disegno
                              IconButton(
                                icon: Container(
                                  decoration: BoxDecoration(
                                    border: _drawingMode
                                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.edit),
                                ),
                                tooltip: "Matita",
                                onPressed: () {
                                  setState(() {
                                    _drawingMode = true;
                                    _eraserMode = false;
                                  });
                                },
                              ),
                              IconButton(
                                icon: Container(
                                  decoration: BoxDecoration(
                                    border: _eraserMode
                                        ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                                        : null,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.auto_fix_normal),
                                ),
                                tooltip: "Gomma",
                                onPressed: () {
                                  setState(() {
                                    _drawingMode = false;
                                    _eraserMode = true;
                                  });
                                },
                              ),
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Torna al foglio principale"),
                                onPressed: () {
                                  setState(() {
                                    _editingMode = false;
                                    _drawingMode = false;
                                    _eraserMode = false;
                                  });
                                },
                              ),
                            ]
                                : [
                              // Barra degli strumenti normale con solo il bottone edit
                              const Spacer(),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.edit),
                                label: const Text("Edit"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () {
                                  final baseUrl = Uri.base.toString().split('#')[0];
                                  // Utilizzo parametri window features per forzare una finestra separata
                                  js.context.callMethod('open', [
                                    '${baseUrl}#/drawing-editor',
                                    '_blank',
                                    'width=1200,height=800,left=100,top=100,resizable=yes,scrollbars=yes,status=yes'
                                  ]);
                                },
                              ),
                            ],
                          ),
                        ),
                        // Ambiente lavoro
                        Expanded(
                          child: _editingMode
                              ? WorkArea(
                            drawingMode: _drawingMode,
                            eraserMode: _eraserMode,
                          )
                              : Container(
                            color: Colors.white,
                            child: const Center(
                              child: Text(
                                "Clicca su Edit per iniziare a disegnare",
                                style: TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : _projectListType != null
                    ? _ProjectListView(
                    type: _projectListType!,
                    onOpenProject: _openProject)
                    : Container(color: Colors.white),

                // Icona utente sempre in alto a destra, fuori dal riquadro
                Positioned(
                  top: 24,
                  right: 32,
                  child: PopupMenuButton<String>(
                    offset: const Offset(0, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == "logout") {
                        context
                            .read<AuthenticationBloc>()
                            .add(const AuthenticationLogoutRequested());
                      } else if (value == "account") {
                        // vai ad account
                      } else if (value == "supporto") {
                        // vai a supporto
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: "account", child: Text("Account")),
                      const PopupMenuItem(
                          value: "supporto", child: Text("Supporto")),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: "logout",
                        child:
                        Text("Logout", style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    child: Container(
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
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBottomMenuItem({
    required IconData icon,
    required IconData activeIcon,
    required String title,
    required VoidCallback onTap,
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
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                size: 20,
              ),
              if (!_isSidebarCollapsed) ...[
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------- Sidebar -------------------

class _SidebarMacroareas extends StatefulWidget {
  final bool isCollapsed;
  final VoidCallback onProjectSelected;
  final void Function(String type) onProjectListRequested;
  const _SidebarMacroareas({
    required this.isCollapsed,
    required this.onProjectSelected,
    required this.onProjectListRequested,
  });

  @override
  State<_SidebarMacroareas> createState() => _SidebarMacroareasState();
}

class _SidebarMacroareasState extends State<_SidebarMacroareas> {
  int? _expandedSection;
  bool _projectCreated = false;

  final _progettiSection = _SidebarSection(
    icon: Icons.folder,
    title: "Progetti",
    children: [
      _SidebarItem(title: "Recenti"),
      _SidebarItem(title: "I miei progetti"),
      _SidebarItem(title: "Preferiti"),
    ],
  );

  final _inserisciSection = _SidebarSection(
    icon: Icons.add_box,
    title: "Inserisci",
    children: [
      _SidebarItem(title: "Cerchio", icon: Icons.circle),
      _SidebarItem(title: "Rettangolo", icon: Icons.crop_square),
      _SidebarItem(title: "Parallelogramma", icon: Icons.change_history),
      _SidebarItem(title: "Rombo", icon: Icons.diamond),
    ],
  );

  final _esecuzioneSection = _SidebarSection(
    icon: Icons.play_arrow,
    title: "Esecuzione",
    children: [
      _SidebarItem(title: "Simula"),
      _SidebarItem(title: "Debug"),
    ],
  );

  @override
  Widget build(BuildContext context) {
    List<_SidebarSection> sections;
    if (!_projectCreated) {
      sections = [_progettiSection];
    } else {
      sections = [_inserisciSection, _esecuzioneSection];
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sections.length,
            itemBuilder: (context, sectionIndex) {
              final section = sections[sectionIndex];
              final expanded = _expandedSection == sectionIndex;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: Icon(section.icon,
                        color: Theme.of(context).colorScheme.primary),
                    title: widget.isCollapsed
                        ? null
                        : Text(section.title,
                        style:
                        const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: widget.isCollapsed
                        ? null
                        : Icon(
                      expanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7),
                    ),
                    onTap: () {
                      setState(() {
                        _expandedSection = expanded ? null : sectionIndex;
                      });
                    },
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: widget.isCollapsed ? 8 : 16),
                  ),
                  if (expanded)
                    ...section.children.map((item) {
                      return Padding(
                        padding: EdgeInsets.only(
                            left: widget.isCollapsed ? 16 : 32.0),
                        child: ListTile(
                          leading: item.icon != null
                              ? Icon(item.icon,
                              color: Theme.of(context).colorScheme.primary)
                              : null,
                          title: widget.isCollapsed ? null : Text(item.title),
                          dense: true,
                          contentPadding:
                          const EdgeInsets.symmetric(horizontal: 0),
                          onTap: !_projectCreated
                              ? () {
                            widget.onProjectListRequested(item.title);
                          }
                              : null,
                        ),
                      );
                    }).toList(),
                ],
              );
            },
          ),
        ),
        if (_projectCreated)
          Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ListTile(
              leading: const Icon(Icons.arrow_back),
              title: widget.isCollapsed ? null : const Text("Indietro"),
              onTap: () {
                setState(() {
                  _projectCreated = false;
                  _expandedSection = null;
                });
                // Torna alla schermata iniziale
                widget.onProjectListRequested(
                    ""); // oppure chiama una callback dedicata
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              tileColor: Colors.grey.withOpacity(0.1),
            ),
          ),
        if (!_projectCreated)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 32),
                label: const Text(
                  "Nuovo progetto",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                onPressed: () {
                  setState(() {
                    _projectCreated = true;
                    _expandedSection = null;
                  });
                  widget.onProjectSelected();
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ------------------- Lista Progetti -------------------

class _ProjectListView extends StatelessWidget {
  final String type;
  final VoidCallback onOpenProject;
  const _ProjectListView({required this.type, required this.onOpenProject});

  @override
  Widget build(BuildContext context) {
    // Sostituisci con la tua logica di caricamento progetti
    final List<String> projects = [
      "Progetto 1",
      "Progetto 2",
      "Progetto 3",
    ];
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Progetti $type",
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...projects.map((p) => Card(
            child: ListTile(
              title: Text(p),
              trailing: ElevatedButton(
                child: const Text("Apri"),
                onPressed: onOpenProject,
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class WorkArea extends StatefulWidget {
  final bool drawingMode;
  final bool eraserMode;
  const WorkArea({required this.drawingMode, required this.eraserMode, Key? key}) : super(key: key);

  @override
  State<WorkArea> createState() => _WorkAreaState();
}

class _WorkAreaState extends State<WorkArea> {
  List<Offset?> points = [];
  List<Offset?> erasedPoints = [];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRect(
        child: SizedBox(
          width: 1000,
          height: 3000,
          child: Stack(
            children: [
              // Sfondo bianco
              Container(color: Colors.white),

              // Layer di disegno
              GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    if (widget.drawingMode && !widget.eraserMode) {
                      points.add(details.localPosition);
                    } else if (widget.eraserMode && !widget.drawingMode) {
                      erasedPoints.add(details.localPosition);
                    }
                  });
                },
                onPanEnd: (_) {
                  setState(() {
                    if (widget.drawingMode && !widget.eraserMode) points.add(null);
                    if (widget.eraserMode && !widget.drawingMode) erasedPoints.add(null);
                  });
                },
                child: CustomPaint(
                  painter: SketchPainter(points, erasedPoints),
                  size: const Size(1000, 3000),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SketchPainter extends CustomPainter {
  final List<Offset?> points;
  final List<Offset?> erasedPoints;
  SketchPainter(this.points, this.erasedPoints);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
    final eraser = Paint()
      ..color = Colors.white
      ..strokeWidth = 16.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < erasedPoints.length - 1; i++) {
      if (erasedPoints[i] != null && erasedPoints[i + 1] != null) {
        canvas.drawLine(erasedPoints[i]!, erasedPoints[i + 1]!, eraser);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}