import 'package:flutter/material.dart';

class TicketStatusChip extends StatelessWidget {
  final String status;

  const TicketStatusChip({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'open':
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        label = 'OPEN';
        break;
      case 'resolved':
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        label = 'RESOLVED';
        break;
      case 'closed':
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
        label = 'CLOSED';
        break;
      default:
        bgColor = Colors.grey.shade50;
        textColor = Colors.grey.shade700;
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

