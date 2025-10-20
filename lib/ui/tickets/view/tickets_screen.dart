import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodel/tickets_viewmodel.dart';
import 'widgets/empty_tickets_state.dart';
import 'widgets/ticket_card.dart';
import 'widgets/ticket_details_sheet.dart';
import '../../theme/app_theme.dart';

class TicketsScreen extends ConsumerWidget {
  final VoidCallback? onViewConversation;

  const TicketsScreen({super.key, this.onViewConversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(ticketsViewModelProvider);
    final allTickets = viewModel.allTickets;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.chatBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Tickets',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
            Text(
              '${allTickets.length} ${allTickets.length == 1 ? 'ticket' : 'tickets'}',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: allTickets.isEmpty
          ? const EmptyTicketsState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allTickets.length,
              itemBuilder: (context, index) {
                final ticket = allTickets[index];
                return TicketCard(
                  ticket: ticket,
                  onTap: () => _showTicketDetails(context, ticket, viewModel),
                );
              },
            ),
    );
  }

  void _showTicketDetails(
    BuildContext context,
    ticket,
    TicketsViewModel viewModel,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TicketDetailsSheet(
        ticket: ticket,
        viewModel: viewModel,
        onViewConversation: onViewConversation,
      ),
    );
  }
}
