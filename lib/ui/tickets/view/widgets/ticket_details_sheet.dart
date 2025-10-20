import 'package:flutter/material.dart';
import '../../../../domain/ticket.dart';
import '../../viewmodel/tickets_viewmodel.dart';
import 'ticket_status_chip.dart';

class TicketDetailsSheet extends StatelessWidget {
  final Ticket ticket;
  final TicketsViewModel viewModel;
  final VoidCallback? onViewConversation;

  const TicketDetailsSheet({
    super.key,
    required this.ticket,
    required this.viewModel,
    this.onViewConversation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(ticket.statusEmoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.ticketId,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TicketStatusChip(status: ticket.status),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    'Product',
                    ticket.product,
                    Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Issue',
                    ticket.issue,
                    Icons.warning_amber_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Priority',
                    '${ticket.urgencyEmoji} ${ticket.urgency.toUpperCase()}',
                    Icons.flag_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(
                    'Created',
                    _formatDetailDate(ticket.createdAt),
                    Icons.access_time,
                  ),
                  if (ticket.resolvedAt != null) ...[
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      'Resolved',
                      _formatDetailDate(ticket.resolvedAt!),
                      Icons.check_circle_outline,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Actions
                  if (ticket.status == 'open') ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          viewModel.updateTicketStatus(
                            ticket.ticketId,
                            'resolved',
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(
                            double.infinity,
                            48,
                          ), // Minimum tap target
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text(
                          'Mark as Resolved',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await viewModel.switchToSession(ticket.sessionId);
                        if (onViewConversation != null) {
                          onViewConversation!();
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: theme.colorScheme.primary),
                        minimumSize: const Size(
                          double.infinity,
                          48,
                        ), // Minimum tap target
                      ),
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text(
                        'View Conversation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Ticket?'),
                            content: Text(
                              'This will permanently delete ticket ${ticket.ticketId}. '
                              'The conversation history will remain.',
                            ),
                            actions: [
                              TextButton(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context, false),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Delete'),
                                onPressed: () => Navigator.pop(context, true),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true && context.mounted) {
                          Navigator.pop(context);
                          await viewModel.deleteTicket(ticket.ticketId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Ticket ${ticket.ticketId} deleted',
                                ),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: theme.colorScheme.error),
                        minimumSize: const Size(
                          double.infinity,
                          48,
                        ), // Minimum tap target
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text(
                        'Delete Ticket',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDetailDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
