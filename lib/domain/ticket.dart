class Ticket {
  final String ticketId;
  final String sessionId;
  final String product;
  final String issue;
  final String urgency;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String status; // 'open', 'closed', 'resolved'

  Ticket({
    required this.ticketId,
    required this.sessionId,
    required this.product,
    required this.issue,
    required this.urgency,
    required this.createdAt,
    this.resolvedAt,
    this.status = 'open',
  });

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        ticketId: json['ticketId'] as String,
        sessionId: json['sessionId'] as String,
        product: json['product'] as String,
        issue: json['issue'] as String,
        urgency: json['urgency'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] != null
            ? DateTime.parse(json['resolvedAt'] as String)
            : null,
        status: json['status'] as String? ?? 'open',
      );

  Map<String, dynamic> toJson() => {
        'ticketId': ticketId,
        'sessionId': sessionId,
        'product': product,
        'issue': issue,
        'urgency': urgency,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'status': status,
      };

  Ticket copyWith({
    String? ticketId,
    String? sessionId,
    String? product,
    String? issue,
    String? urgency,
    DateTime? createdAt,
    DateTime? resolvedAt,
    String? status,
  }) {
    return Ticket(
      ticketId: ticketId ?? this.ticketId,
      sessionId: sessionId ?? this.sessionId,
      product: product ?? this.product,
      issue: issue ?? this.issue,
      urgency: urgency ?? this.urgency,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      status: status ?? this.status,
    );
  }

  String get urgencyEmoji {
    switch (urgency.toLowerCase()) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      case 'low':
        return '🟢';
      default:
        return '⚪';
    }
  }

  String get statusEmoji {
    switch (status) {
      case 'open':
        return '🎫';
      case 'resolved':
        return '✅';
      case 'closed':
        return '🔒';
      default:
        return '📋';
    }
  }
}

