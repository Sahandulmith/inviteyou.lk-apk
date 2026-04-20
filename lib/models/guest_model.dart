class GuestModel {
  final String id;
  final String name;
  final String whatsapp;
  final int numberOfGuests;
  final String side;
  final String status;
  final String invitationStatus;
  final int clickCount;
  final String? createdAt;
  final bool invitationSent;
  final String? rsvpName;
  final String? rsvpMessage;
  final int rsvpGuests;
  final String? rsvpDate;
  final String? tableId;
  final String? addedByEmail;
  final String? addedByRole;

  GuestModel({
    required this.id,
    required this.name,
    required this.whatsapp,
    required this.numberOfGuests,
    required this.side,
    required this.status,
    required this.invitationStatus,
    required this.clickCount,
    this.createdAt,
    required this.invitationSent,
    this.rsvpName,
    this.rsvpMessage,
    required this.rsvpGuests,
    this.rsvpDate,
    this.tableId,
    this.addedByEmail,
    this.addedByRole,
  });

  factory GuestModel.fromFirestore(Map<String, dynamic> data, String id) {
    return GuestModel(
      id: id,
      name: data['name'] ?? '',
      whatsapp: data['whatsapp'] ?? '',
      numberOfGuests: (data['numberOfGuests'] ?? 1) is int
          ? data['numberOfGuests'] ?? 1
          : int.tryParse(data['numberOfGuests'].toString()) ?? 1,
      side: data['side'] ?? 'Groom',
      status: data['status'] ?? 'Invited',
      invitationStatus: data['invitationStatus'] ?? 'pending',
      clickCount: (data['clickCount'] ?? 0) is int
          ? data['clickCount'] ?? 0
          : int.tryParse(data['clickCount'].toString()) ?? 0,
      createdAt: data['createdAt'],
      invitationSent: data['invitationSent'] ?? false,
      rsvpName: data['rsvpName'],
      rsvpMessage: data['rsvpMessage'],
      rsvpGuests: (data['rsvpGuests'] ?? 0) is int
          ? data['rsvpGuests'] ?? 0
          : int.tryParse(data['rsvpGuests'].toString()) ?? 0,
      rsvpDate: data['rsvpDate'],
      tableId: data['tableId'],
      addedByEmail: data['addedByEmail'],
      addedByRole: data['addedByRole'],
    );
  }

  String get displayStatus {
    switch (status) {
      case 'Attending':
        return 'RSVP YES';
      case 'Declined':
        return 'RSVP NO';
      default:
        return status;
    }
  }

  bool get hasRsvpd => status == 'Attending' || status == 'Declined';
}
