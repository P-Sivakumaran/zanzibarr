import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Chat commands only. Editing keys fall through to Flutter's text editor.
class ChatShortcuts extends StatelessWidget {
  const ChatShortcuts({
    super.key,
    required this.child,
    required this.onSend,
    required this.onNewLine,
    required this.canSend,
    required this.composerFocused,
    required this.isComposing,
    required this.onFocusComposer,
    required this.onHelp,
    required this.onSwitchTab,
    this.onNewChat,
    this.onConnections,
    this.onCancel,
  });

  final Widget child;
  final VoidCallback onSend, onNewLine, onFocusComposer, onHelp;
  final VoidCallback? onNewChat, onConnections, onCancel;
  final bool Function() canSend, composerFocused, isComposing;
  final void Function(int tab) onSwitchTab;

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: true,
    skipTraversal: true,
    onKeyEvent: (_, event) {
      if (event is KeyUpEvent || ModalRoute.of(context)?.isCurrent == false) {
        return KeyEventResult.ignored;
      }
      final keyboard = HardwareKeyboard.instance;
      final key = event.logicalKey;
      final primary = keyboard.isControlPressed || keyboard.isMetaPressed;
      final shift = keyboard.isShiftPressed;
      if (keyboard.isAltPressed) return KeyEventResult.ignored;

      // An IME must be able to commit its current word without sending it.
      if (key == LogicalKeyboardKey.enter && composerFocused()) {
        if (isComposing()) return KeyEventResult.ignored;
        if (shift) {
          if (primary) return KeyEventResult.ignored;
          onNewLine();
        } else if (event is KeyDownEvent && canSend()) {
          onSend();
        }
        return KeyEventResult.handled;
      }

      VoidCallback? action;
      if (key == LogicalKeyboardKey.escape && !primary && !shift) {
        action = onCancel;
      } else if (key == LogicalKeyboardKey.f1 && !primary && !shift) {
        action = onHelp;
      } else if (primary && !shift) {
        action = switch (key) {
          LogicalKeyboardKey.keyN => onNewChat,
          LogicalKeyboardKey.keyL => onFocusComposer,
          LogicalKeyboardKey.comma => onConnections,
          LogicalKeyboardKey.slash => onHelp,
          LogicalKeyboardKey.digit1 => () => onSwitchTab(0),
          LogicalKeyboardKey.digit2 => () => onSwitchTab(1),
          _ => null,
        };
      }
      if (action == null) return KeyEventResult.ignored;
      if (event is KeyDownEvent) action();
      return KeyEventResult.handled;
    },
    child: child,
  );
}

Future<void> showChatShortcutHelp(BuildContext context) {
  final modifier = Theme.of(context).platform == TargetPlatform.macOS
      ? '⌘'
      : 'Ctrl';
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard shortcuts'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final shortcut in [
                ('Enter or $modifier+Enter', 'Send your request'),
                ('Shift+Enter', 'Insert a new line'),
                ('Escape', 'Stop a reply or connection check'),
                ('$modifier+N', 'New chat (keeps your draft)'),
                ('$modifier+L', 'Focus the message box'),
                ('$modifier+1 / $modifier+2', 'Chat / Playlists'),
                ('$modifier+,', 'AI connection settings'),
                ('$modifier+/ or F1', 'Show this help'),
                ('$modifier+A / C / X / V', 'Select all / copy / cut / paste'),
                ('$modifier+Z', 'Undo'),
                (
                  modifier == '⌘' ? '⌘+Shift+Z' : 'Ctrl+Y / Ctrl+Shift+Z',
                  'Redo',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          shortcut.$1,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(shortcut.$2)),
                    ],
                  ),
                ),
              const Divider(height: 24),
              const Text(
                'Select all, copy, cut, paste, undo and redo use the standard shortcuts for your operating system. '
                'Enter commits an active input-method composition without sending.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
