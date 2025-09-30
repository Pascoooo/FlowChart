import 'package:fluent_ui/fluent_ui.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

enum DialogType { info, success, warning, error }

/// 🎨 Professional Dialog System - Web-First Design with Perfect Centering
class GenericDialogs {
  /// 📢 Info Dialog - Perfectly Centered Single-Button Layout
  static Future<void> showInfoDialog(
      BuildContext context, {
        required String title,
        required String message,
        DialogType type = DialogType.info,
        String closeText = 'Ho capito',
      }) {
    final theme = FluentTheme.of(context);

    // 🎯 Semantic Type Mapping with Theme Colors
    final Map<DialogType, (IconData, Color)> typeDetails = {
      DialogType.info: (
      FontAwesomeIcons.circleInfo,
      theme.accentColor.defaultBrushFor(theme.brightness)
      ),
      DialogType.success: (
      FontAwesomeIcons.solidCircleCheck,
      theme.brightness == Brightness.light
          ? const Color(0xFF059669) // AppColors.lightSuccess equivalent
          : const Color(0xFF10B981)  // AppColors.darkSuccess equivalent
      ),
      DialogType.warning: (
      FontAwesomeIcons.triangleExclamation,
      theme.brightness == Brightness.light
          ? const Color(0xFFD97706) // AppColors.lightWarning equivalent
          : const Color(0xFFF59E0B)  // AppColors.darkWarning equivalent
      ),
      DialogType.error: (
      FontAwesomeIcons.circleExclamation,
      theme.brightness == Brightness.light
          ? const Color(0xFFDC2626) // AppColors.lightError equivalent
          : const Color(0xFFEF4444)  // AppColors.darkError equivalent
      ),
    };

    final (icon, iconColor) = typeDetails[type]!;

    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Center(
        child: ContentDialog(
          constraints: const BoxConstraints(
            minWidth: 480,
            maxWidth: 560,
            minHeight: 300,
          ),
          content: Container(
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🎯 Icon Container - Centered
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: FaIcon(
                    icon,
                    size: 32,
                    color: iconColor,
                  ),
                ),

                const SizedBox(height: 24),

                // 🎯 Title - Centered
                Text(
                  title,
                  style: theme.typography.title?.copyWith(
                    color: theme.typography.body?.color,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // 🎯 Message - Centered
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Text(
                    message,
                    style: theme.typography.body?.copyWith(
                      color: theme.typography.body?.color?.withValues(alpha: 0.8),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(height: 32),

                // 🎯 Single Button - Perfectly Centered
                Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      child: Text(closeText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ❓ Confirmation Dialog - Professional Two-Button Layout
  static Future<bool?> showConfirmationDialog(
      BuildContext context, {
        required String title,
        required String message,
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        bool isDestructive = false,
      }) {
    final theme = FluentTheme.of(context);

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        // 🎯 Destructive Action Color Logic
        Color getDestructiveColor() {
          return theme.brightness == Brightness.light
              ? const Color(0xFFDC2626) // AppColors.lightError equivalent
              : const Color(0xFFEF4444); // AppColors.darkError equivalent
        }

        // 🎯 Icon Selection
        final iconData = isDestructive
            ? FontAwesomeIcons.triangleExclamation
            : FontAwesomeIcons.circleQuestion;

        final iconColor = isDestructive
            ? getDestructiveColor()
            : theme.accentColor.defaultBrushFor(theme.brightness);

        return Center(
          child: ContentDialog(
            constraints: const BoxConstraints(
              minWidth: 520,
              maxWidth: 600,
              minHeight: 280,
            ),
            content: Container(
              padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 🎯 Header Section - Centered
                  Column(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: iconColor.withValues(alpha: 0.1),
                          border: Border.all(
                            color: iconColor.withValues(alpha: 0.2),
                            width: 2,
                          ),
                        ),
                        child: FaIcon(
                          iconData,
                          size: 28,
                          color: iconColor,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Title
                      Text(
                        title,
                        style: theme.typography.title?.copyWith(
                          color: theme.typography.body?.color,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 🎯 Divider
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: theme.resources.dividerStrokeColorDefault,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                  ),

                  const SizedBox(height: 20),

                  // 🎯 Message - Centered
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Text(
                      message,
                      style: theme.typography.body?.copyWith(
                        color: theme.typography.body?.color?.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              // 🎯 Actions - Centered Row
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Secondary Action (Cancel)
                    Button(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Text(cancelText),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Primary Action (Confirm)
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: isDestructive
                          ? ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return theme.resources.controlFillColorDisabled;
                          }
                          if (states.contains(WidgetState.pressed)) {
                            return getDestructiveColor().withValues(alpha: 0.9);
                          }
                          if (states.contains(WidgetState.hovered)) {
                            return getDestructiveColor().withValues(alpha: 0.8);
                          }
                          return getDestructiveColor();
                        }),
                        foregroundColor: WidgetStateProperty.all(
                            theme.brightness == Brightness.light
                                ? Colors.white
                                : Colors.black
                        ),
                      )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        child: Text(confirmText),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ✏️ Input Dialog - Professional Text Input with Validation
  static Future<String?> showInputDialog(
      BuildContext context, {
        required String title,
        required String inputLabel,
        String? message,
        String? initialValue,
        String hintText = '',
        String confirmText = 'Conferma',
        String cancelText = 'Annulla',
        String? Function(String?)? validator,
      }) async {
    final controller = TextEditingController(text: initialValue);
    final theme = FluentTheme.of(context);

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // State variables
        String? errorText;
        bool isButtonEnabled = false;

        return StatefulBuilder(
          builder: (statefulContext, setState) {
            void validate(String value) {
              setState(() {
                if (validator != null) {
                  errorText = validator(value);
                  isButtonEnabled = errorText == null && value.trim().isNotEmpty;
                } else {
                  isButtonEnabled = value.trim().isNotEmpty;
                  errorText = null;
                }
              });
            }

            // Initial validation
            WidgetsBinding.instance.addPostFrameCallback((_) {
              validate(controller.text);
            });

            return Center(
              child: ContentDialog(
                constraints: const BoxConstraints(
                  minWidth: 520,
                  maxWidth: 600,
                  minHeight: 320,
                ),
                content: Container(
                  padding: const EdgeInsets.fromLTRB(40, 32, 40, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 🎯 Header Section - Centered
                      Column(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.1),
                              border: Border.all(
                                color: theme.accentColor.defaultBrushFor(theme.brightness).withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: FaIcon(
                              FontAwesomeIcons.penToSquare,
                              size: 28,
                              color: theme.accentColor.defaultBrushFor(theme.brightness),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Title
                          Text(
                            title,
                            style: theme.typography.title?.copyWith(
                              color: theme.typography.body?.color,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 🎯 Divider
                      Container(
                        height: 1,
                        width: double.infinity,
                        color: theme.resources.dividerStrokeColorDefault,
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                      ),

                      const SizedBox(height: 20),

                      // 🎯 Message (if provided)
                      if (message != null) ...[
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Text(
                            message,
                            style: theme.typography.body?.copyWith(
                              color: theme.typography.body?.color?.withValues(alpha: 0.8),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // 🎯 Input Section - Centered Container
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Input Label
                            Text(
                              inputLabel,
                              style: theme.typography.bodyStrong?.copyWith(
                                color: theme.typography.body?.color,
                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Text Input
                            TextBox(
                              controller: controller,
                              autofocus: true,
                              placeholder: hintText,
                              onChanged: validate,
                              style: theme.typography.body?.copyWith(
                                color: theme.typography.body?.color,
                              ),
                                decoration: WidgetStateProperty.all<BoxDecoration>(
                                  BoxDecoration(
                                    color: theme.resources.controlFillColorDefault,
                                    border: Border.all(
                                      color: errorText != null
                                          ? (theme.brightness == Brightness.light
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFEF4444))
                                          : theme.resources.controlStrokeColorDefault,
                                      width: errorText != null ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                            ),
                            // Error Text
                            if (errorText != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    FaIcon(
                                      FontAwesomeIcons.circleExclamation,
                                      size: 14,
                                      color: theme.brightness == Brightness.light
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorText!,
                                        style: theme.typography.caption?.copyWith(
                                          color: theme.brightness == Brightness.light
                                              ? const Color(0xFFDC2626)
                                              : const Color(0xFFEF4444),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // 🎯 Actions - Centered Row
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Secondary Action (Cancel)
                        Button(
                          onPressed: () => Navigator.of(dialogContext).pop(null),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Text(cancelText),
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Primary Action (Confirm)
                        FilledButton(
                          onPressed: isButtonEnabled
                              ? () => Navigator.of(dialogContext).pop(controller.text.trim())
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            child: Text(confirmText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

