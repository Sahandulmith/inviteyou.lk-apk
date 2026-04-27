import 'package:flutter/material.dart';
import '../models/guest_model.dart';
import '../models/table_model.dart';
import '../theme/app_theme.dart';

class GuestCard extends StatelessWidget {
  final GuestModel guest;
  final TableModel? table;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onSendWhatsApp;
  final VoidCallback onCopyLink;
  final VoidCallback onShare;

  const GuestCard({
    super.key,
    required this.guest,
    this.table,
    required this.onEdit,
    required this.onDelete,
    required this.onSendWhatsApp,
    required this.onCopyLink,
    required this.onShare,
  });

  Color get _statusColor {
    switch (guest.status) {
      case 'Attending':
        return AppTheme.attending;
      case 'Declined':
        return AppTheme.declined;
      default:
        return AppTheme.pending;
    }
  }

  String get _statusEmoji {
    switch (guest.status) {
      case 'Attending':
        return '✅';
      case 'Declined':
        return '❌';
      default:
        return '⏳';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          InkWell(
            onTap: () => _showDetails(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: guest.side == 'Groom'
                            ? [AppTheme.groomBlue, AppTheme.groomBlue.withOpacity(0.7)]
                            : [AppTheme.bridePink, AppTheme.bridePink.withOpacity(0.7)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        guest.displayName.isNotEmpty ? guest.displayName[0].toUpperCase() : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          guest.displayName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 12, color: AppTheme.textMid),
                            const SizedBox(width: 4),
                            Text(guest.whatsapp,
                                style: Theme.of(context).textTheme.bodyMedium,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(width: 8),
                            Icon(Icons.group_outlined,
                                size: 12, color: AppTheme.textMid),
                            const SizedBox(width: 2),
                            Text(
                              '${guest.rsvpGuests}/${guest.numberOfGuests}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _statusBadge(),
                            if (table != null && table!.id.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              _tableBadge(context),
                            ],
                            if (guest.clickCount > 0) ...[
                              const SizedBox(width: 6),
                              _openedBadge(),
                            ],
                          ],
                        ),
                        if (guest.rsvpMessage != null && guest.rsvpMessage!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '💬 "${guest.rsvpMessage}"',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Actions
                  Column(
                    children: [
                      _actionBtn(
                        icon: Icons.send_rounded,
                        color: const Color(0xFF25D366),
                        onTap: onSendWhatsApp,
                        tooltip: 'Send WhatsApp',
                      ),
                      const SizedBox(height: 4),
                      _actionBtn(
                        icon: Icons.link_rounded,
                        color: Colors.blue,
                        onTap: onCopyLink,
                        tooltip: 'Copy Link',
                      ),
                      const SizedBox(height: 4),
                      _actionBtn(
                        icon: Icons.share_rounded,
                        color: Colors.teal,
                        onTap: onShare,
                        tooltip: 'Share',
                      ),
                      const SizedBox(height: 4),
                      _actionBtn(
                        icon: Icons.edit_outlined,
                        color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.rosePrimary,
                        onTap: onEdit,
                        tooltip: 'Edit',
                      ),
                      const SizedBox(height: 4),
                      _actionBtn(
                        icon: Icons.delete_outline,
                        color: AppTheme.declined,
                        onTap: onDelete,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: _sideBadge(),
          ),
        ],
      ),
    );
  }

  Widget _sideBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: guest.side == 'Groom' ? AppTheme.groomBlue : AppTheme.bridePink,
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        guest.side.toUpperCase(),
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _statusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$_statusEmoji ${guest.displayStatus}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _statusColor,
        ),
      ),
    );
  }

  Widget _tableBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.rosePrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '🪑 ${table!.name}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).brightness == Brightness.dark ? AppTheme.gold : AppTheme.rosePrimary,
        ),
      ),
    );
  }

  Widget _openedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '👁 ${guest.clickCount}x',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.blueAccent,
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Tooltip(
        message: tooltip,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(guest.displayName,
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 12),
            if (guest.title.isNotEmpty)
              _detailRow(context, '🎩 Title', guest.title),
            _detailRow(context, '📱 WhatsApp', guest.whatsapp),
            _detailRow(context, '👥 Side', guest.side),
            _detailRow(context, '📊 Status', guest.displayStatus),
            _detailRow(context, '🧑‍🤝‍🧑 Guests',
                '${guest.rsvpGuests} / ${guest.numberOfGuests}'),
            if (table != null && table!.id.isNotEmpty)
              _detailRow(context, '🪑 Table', table!.name),
            if (guest.rsvpName != null && guest.rsvpName!.isNotEmpty)
              _detailRow(context, '✍️ RSVP Name', guest.rsvpName!),
            if (guest.rsvpMessage != null && guest.rsvpMessage!.isNotEmpty)
              _detailRow(context, '💬 Message', guest.rsvpMessage!),
            if (guest.rsvpDate != null)
              _detailRow(context, '📅 RSVP Date',
                  guest.rsvpDate!.substring(0, 10)),
            _detailRow(context, '👁 Invitation Opens',
                '${guest.clickCount} times'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
