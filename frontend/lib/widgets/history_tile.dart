import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/conversation.dart';

class HistoryTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSpeak;

  const HistoryTile({
    super.key,
    required this.conversation,
    this.onTap,
    this.onDelete,
    this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM d, yyyy');
    final timestamp = conversation.timestamp;
    final isToday =
        timestamp.year == DateTime.now().year &&
        timestamp.month == DateTime.now().month &&
        timestamp.day == DateTime.now().day;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            conversation.source == 'speech' ? Icons.mic : Icons.back_hand,
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          conversation.text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                if (conversation.source != 'speech') ...[
                  Text(
                    'Confidence: ${(conversation.confidence * 100).toStringAsFixed(1)}%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: conversation.source == 'speech'
                        ? theme.colorScheme.secondaryContainer
                        : theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    conversation.source == 'speech' ? 'Speech' : 'Sign',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: conversation.source == 'speech'
                          ? theme.colorScheme.onSecondaryContainer
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isToday
                  ? timeFormat.format(timestamp)
                  : dateFormat.format(timestamp),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onSpeak != null) ...[
              const SizedBox(height: 4),
              IconButton(
                icon: Icon(
                  Icons.volume_up,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onSpeak,
                tooltip: 'Speak',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
