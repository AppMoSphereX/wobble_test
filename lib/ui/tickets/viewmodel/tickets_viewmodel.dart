import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/ticket.dart';
import '../../chat/viewmodel/chat_viewmodel.dart';

class TicketsViewModel extends ChangeNotifier {
  final ChatViewModel _chatViewModel;

  TicketsViewModel(this._chatViewModel) {
    // Listen to chat view model for ticket updates
    _chatViewModel.addListener(_onTicketsChanged);
  }

  void _onTicketsChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _chatViewModel.removeListener(_onTicketsChanged);
    super.dispose();
  }

  // Expose ticket data
  List<Ticket> get allTickets => _chatViewModel.tickets;
  List<Ticket> get openTickets => _chatViewModel.openTickets;
  List<Ticket> get resolvedTickets => _chatViewModel.resolvedTickets;

  // Delegate ticket operations
  Future<void> updateTicketStatus(String ticketId, String newStatus) async {
    await _chatViewModel.updateTicketStatus(ticketId, newStatus);
  }

  Future<void> deleteTicket(String ticketId) async {
    await _chatViewModel.deleteTicket(ticketId);
  }

  Future<void> switchToSession(String sessionId) async {
    await _chatViewModel.switchToSession(sessionId);
  }
}

final ticketsViewModelProvider = ChangeNotifierProvider((ref) {
  final chatViewModel = ref.watch(chatViewModelProvider);
  return TicketsViewModel(chatViewModel);
});

