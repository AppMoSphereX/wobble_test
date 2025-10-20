import 'package:flutter/material.dart';
import '../../../../domain/message.dart';
import '../../../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onRetry;
  final bool showRetry;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.showRetry = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.role == 'user';
    final hasError = message.hasError;
    final bubbleColor = hasError
        ? theme.colorScheme.errorContainer
        : (isUser ? theme.userBubbleColor : theme.assistantBubbleColor);
    final textColor = hasError 
        ? theme.colorScheme.onErrorContainer
        : (isUser ? theme.userBubbleTextColor : theme.assistantBubbleTextColor);
    final align = isUser ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: align,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(14),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.77,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: hasError
                ? Border.all(color: theme.colorScheme.error, width: 1.5)
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: hasError
                    ? theme.colorScheme.error.withValues(alpha: 0.15)
                    : theme.shadowColor.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message.errorMessage ?? 'An error occurred',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              SelectableText(
                message.text,
                style: TextStyle(
                  fontSize: 16.5,
                  color: textColor,
                  fontFamily: 'RobotoMono',
                ),
                textAlign: TextAlign.left,
              ),
              if (hasError && showRetry && onRetry != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Semantics(
                    label: 'Retry sending message',
                    button: true,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onRetry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          foregroundColor: theme.colorScheme.onError,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(double.infinity, 48), // Ensure minimum tap target
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!hasError)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTimestamp(message.timestamp),
                      style: TextStyle(
                        fontSize: 11, 
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                    if (message.latency != null && !isUser && message.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 5.0),
                        child: Text(
                          '⏱ ${message.latency} ms',
                          style: TextStyle(
                            fontSize: 11.5, 
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } else {
      return "${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
  }
}

