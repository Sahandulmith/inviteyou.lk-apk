import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/guest_model.dart';
import '../models/table_model.dart';
import '../services/firebase_service.dart';
import '../theme/app_theme.dart';

class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  final FirebaseService _firebase = FirebaseService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _capCtrl = TextEditingController(text: '8');

  List<TableModel> _tables = [];
  List<GuestModel> _guests = [];
  StreamSubscription<List<TableModel>>? _tablesSub;
  StreamSubscription<List<GuestModel>>? _guestsSub;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tablesSub = _firebase.tablesStream().listen((t) {
      setState(() {
        _tables = t;
        _loading = false;
      });
    });
    _guestsSub = _firebase.guestsStream().listen((g) {
      setState(() => _guests = g);
    });
  }

  @override
  void dispose() {
    _tablesSub?.cancel();
    _guestsSub?.cancel();
    _nameCtrl.dispose();
    _capCtrl.dispose();
    super.dispose();
  }

  List<GuestModel> _tableGuests(String tableId) =>
      _guests.where((g) => g.tableId == tableId).toList();

  List<GuestModel> get _unassignedAttending => _guests
      .where((g) => g.tableId == null && g.status == 'Attending')
      .toList();

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.rosePrimary));
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAddTableCard(),
          const SizedBox(height: 16),
          if (_unassignedAttending.isNotEmpty) _buildUnassignedSection(),
          if (_tables.isEmpty)
            _buildEmptyTables()
          else
            ..._tables.map((t) => _buildTableCard(t)),
        ],
      ),
    );
  }

  Widget _buildAddTableCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add New Table',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Table Name / Number',
                      prefixIcon: Icon(Icons.table_restaurant),
                      hintText: 'e.g. 1, VIP, Family',
                    ),
                    keyboardType: TextInputType.text,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _capCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Seats',
                      prefixIcon: Icon(Icons.event_seat_outlined),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Table'),
                onPressed: () async {
                  if (_nameCtrl.text.trim().isEmpty) return;
                  await _firebase.addTable(
                    _nameCtrl.text.trim(),
                    int.tryParse(_capCtrl.text) ?? 8,
                  );
                  _nameCtrl.clear();
                  _capCtrl.text = '8';
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Table added! 🎉'),
                        backgroundColor: AppTheme.attending,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnassignedSection() {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.pending.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_search_rounded,
                      color: AppTheme.pending, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  'Unassigned Guests (${_unassignedAttending.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._unassignedAttending.map((g) => _unassignedGuestRow(g)),
          ],
        ),
      ),
    );
  }

  Widget _unassignedGuestRow(GuestModel guest) {
    String? selectedTableId;
    return StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(guest.name,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            DropdownButton<String>(
              hint: const Text('Assign table', style: TextStyle(fontSize: 12)),
              value: selectedTableId,
              underline: const SizedBox.shrink(),
              items: _tables
                  .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Text(t.name,
                          style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) async {
                setS(() => selectedTableId = v);
                if (v != null) {
                  await _firebase.assignGuestToTable(guest.id, v);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${guest.name} assigned to table ✅'),
                        backgroundColor: AppTheme.attending,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableCard(TableModel table) {
    final seated = _tableGuests(table.id);
    final totalPeople = seated.fold<int>(
        0, (sum, g) => sum + (g.rsvpGuests > 0 ? g.rsvpGuests : g.numberOfGuests));
    final isFull = totalPeople >= table.capacity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isFull
                  ? [AppTheme.declined, const Color(0xFFEF9A9A)]
                  : [AppTheme.rosePrimary, AppTheme.roseLight],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.table_restaurant_rounded,
              color: Colors.white, size: 20),
        ),
        title: Text(table.name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        subtitle: Text(
          '$totalPeople / ${table.capacity} seats • ${seated.length} groups',
          style: TextStyle(
            color: isFull ? AppTheme.declined : AppTheme.textMid,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Capacity bar
            SizedBox(
              width: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: table.capacity > 0
                      ? (totalPeople / table.capacity).clamp(0.0, 1.0)
                      : 0,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                      isFull ? AppTheme.declined : AppTheme.attending),
                  minHeight: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppTheme.declined, size: 20),
              onPressed: () => _confirmDeleteTable(table),
            ),
          ],
        ),
        children: [
          if (seated.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No guests assigned yet.',
                  style: TextStyle(color: AppTheme.textMid)),
            )
          else
            ...seated.map(
              (g) => ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppTheme.rosePrimary.withOpacity(0.15),
                  child: Text(
                    g.name[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppTheme.rosePrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                title: Text(g.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                subtitle: Text(
                    '${g.rsvpGuests > 0 ? g.rsvpGuests : g.numberOfGuests} people',
                    style: const TextStyle(fontSize: 11)),
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle_outline,
                      color: Colors.red.shade300, size: 18),
                  onPressed: () async {
                    await _firebase.assignGuestToTable(g.id, null);
                  },
                  tooltip: 'Remove from table',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyTables() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.table_restaurant_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No tables yet',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 4),
            Text('Add your first table above to start assigning seats.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteTable(TableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Table'),
        content: Text('Delete ${table.name}? Guests will become unassigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.declined),
            onPressed: () async {
              await _firebase.deleteTable(table.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
