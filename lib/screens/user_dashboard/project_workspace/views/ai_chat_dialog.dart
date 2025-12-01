import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../../../../blocs/ai_chat_bloc/ai_chat_bloc.dart';
import '../../../../blocs/ai_chat_bloc/ai_chat_event.dart';
import '../../../../blocs/ai_chat_bloc/ai_chat_state.dart';
import '../../../../blocs/flowchart_bloc/flowchart_bloc.dart';
import '../../../../blocs/flowchart_bloc/flowchart_state.dart';

/// Pannello chat floating laterale per l'assistente AI
class AiChatPanel extends StatefulWidget {
  final VoidCallback onClose;

  const AiChatPanel({super.key, required this.onClose});

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 220),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Inizializza la chat con messaggio di benvenuto
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AiChatBloc>().add(const InitializeChat());
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // Ottieni il JSON del flowchart corrente come contesto
    String? flowchartContext;
    try {
      final flowchartBloc = context.read<FlowchartBloc>();
      final flowchartState = flowchartBloc.state;
      if (flowchartState is FlowchartLoaded) {
        flowchartContext = flowchartState.toJson();
      }
    } catch (e) {
      // Ignora errori nel recupero del contesto
    }

    context.read<AiChatBloc>().add(SendMessageToAi(message, context: flowchartContext));
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _handleClose() async {
    if (!mounted) return;
    await _animationController.reverse();
    if (mounted) {
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final size = MediaQuery.of(context).size;

    // Pannello: 380px larghezza, metà altezza finestra
    final double panelWidth = 380;
    final double panelHeight = size.height * 0.5;

    return IgnorePointer(
      ignoring: false,
      child: Align(
        alignment: Alignment.centerRight,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            width: panelWidth,
            height: panelHeight,
            margin: const EdgeInsets.only(right: 16, top: 16, bottom: 16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(-4, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(theme),
                Expanded(child: _buildMessages(theme)),
                _buildInputArea(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.accentColor,
            theme.accentColor.withValues(alpha: 0.85),
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.robot, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'AI Assistant',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.chrome_close, color: Colors.white, size: 14),
            onPressed: _handleClose,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(FluentThemeData theme) {
    return BlocConsumer<AiChatBloc, AiChatState>(
      listener: (context, state) {
        if (state is AiChatReady && !state.isLoading) {
          _scrollToBottom();
        }
      },
      builder: (context, state) {
        List<ChatMessage> messages = [];
        bool isLoading = false;

        if (state is AiChatReady) {
          messages = state.messages;
          isLoading = state.isLoading;
        } else if (state is AiChatError) {
          messages = state.messages;
        }

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.robot,
                  size: 32,
                  color: theme.resources.textFillColorTertiary,
                ),
                const SizedBox(height: 6),
                Text(
                  'Scrivi un messaggio',
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(8),
          child: ListView.builder(
            controller: _scrollController,
            itemCount: messages.length + (isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == messages.length && isLoading) {
                return _buildLoadingIndicator(theme);
              }
              return _buildMessageBubble(messages[index], theme);
            },
          ),
        );
      },
    );
  }

  Widget _buildInputArea(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.4),
        border: Border(
          top: BorderSide(
            color: theme.resources.cardStrokeColorDefault,
          ),
        ),
      ),
      child: BlocBuilder<AiChatBloc, AiChatState>(
        builder: (context, state) {
          final isLoading = state is AiChatReady && state.isLoading;

          return Row(
            children: [
              Expanded(
                child: TextBox(
                  controller: _messageController,
                  placeholder: 'Messaggio...',
                  maxLines: 2,
                  minLines: 1,
                  enabled: !isLoading,
                  onSubmitted: (_) => _sendMessage(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: Icon(
                  FluentIcons.send,
                  color: isLoading
                      ? theme.resources.textFillColorDisabled
                      : theme.accentColor,
                  size: 16,
                ),
                onPressed: isLoading ? null : _sendMessage,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLoadingIndicator(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 6),
          Text(
            'Pensando...',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, FluentThemeData theme) {
    final Color userTextColor = Colors.white;
    final Color aiTextColor = Colors.black;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Icon(
              FluentIcons.robot,
              size: 14,
              color: theme.accentColor,
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: message.isUser
                    ? theme.accentColor.withValues(alpha: 0.9)
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: !message.isUser
                    ? Border.all(
                        color: theme.resources.cardStrokeColorDefault,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isUser)
                    Text(
                      message.content,
                      style: TextStyle(
                        fontSize: 12,
                        color: userTextColor,
                      ),
                    )
                  else
                    MarkdownWidget(
                      data: message.content,
                      shrinkWrap: true,
                      config: MarkdownConfig(
                        configs: [
                          PConfig(
                            textStyle: TextStyle(
                              fontSize: 12,
                              color: aiTextColor,
                            ),
                          ),
                          H1Config(
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: aiTextColor,
                            ),
                          ),
                          H2Config(
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: aiTextColor,
                            ),
                          ),
                          const CodeConfig(
                            style: TextStyle(
                              fontFamily: 'Consolas',
                              fontSize: 11,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(message.timestamp),
                    style: theme.typography.caption?.copyWith(
                      color: message.isUser
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.6),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Ora';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m fa';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h fa';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
