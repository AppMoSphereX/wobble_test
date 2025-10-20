import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class TicketStatusChip extends StatelessWidget {
  final String status;

  const TicketStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'open':
        bgColor = theme.ticketOpenBackground;
        textColor = theme.ticketOpenText;
        label = 'OPEN';
        break;
      case 'resolved':
        bgColor = theme.ticketResolvedBackground;
        textColor = theme.ticketResolvedText;
        label = 'RESOLVED';
        break;
      case 'closed':
        bgColor = theme.ticketClosedBackground;
        textColor = theme.ticketClosedText;
        label = 'CLOSED';
        break;
      default:
        bgColor = theme.ticketClosedBackground;
        textColor = theme.ticketClosedText;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
