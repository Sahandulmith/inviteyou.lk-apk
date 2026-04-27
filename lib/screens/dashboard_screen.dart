import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/guest_model.dart';
import '../models/table_model.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import '../widgets/guest_card.dart';
import 'tables_screen.dart';
import 'profile_screen.dart';
class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> currentUser;
  const DashboardScreen({super.key, required this.currentUser});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _baseUrl = "https://inviteyoulk.netlify.app/"; // Reactive URL from Firebase

  final FirebaseService _firebase = FirebaseService();
  final NotificationService _notifications = NotificationService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<GuestModel> _allGuests = [];
  List<GuestModel> _filteredGuests = [];
  List<TableModel> _tables = [];
  List<GuestModel> _prevGuests = [];
  bool _loading = true;
  int _selectedTab = 0;
  StreamSubscription<List<GuestModel>>? _guestsSub;
  StreamSubscription<List<TableModel>>? _tablesSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingSub;
  StreamSubscription<String>? _baseUrlSub;
  List<Map<String, dynamic>> _pendingUsers = [];
  List<Map<String, dynamic>> _prevPendingUsers = [];
  bool _pendingInitialized = false;
  late AnimationController _headerAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _headerAnim, curve: Curves.easeOut);
    _headerAnim.forward();

    bool isFirstGuestsLoad = true;
    _guestsSub = _firebase.guestsStream().listen((guests) {
      if (!isFirstGuestsLoad) {
        _detectNewRsvps(guests);
        _detectNewGuestAdditions(guests);
      }
      if (mounted) {
        setState(() {
          _allGuests = guests;
          _filteredGuests = _applyFilter(guests);
          _loading = false;
        });
      }
      _prevGuests = List.from(guests);
      isFirstGuestsLoad = false;
    });

    _tablesSub = _firebase.tablesStream().listen((tables) {
      setState(() => _tables = tables);
    });

    _pendingSub = _firebase.pendingUsersStream().listen((users) {
      if (!_pendingInitialized) {
        _prevPendingUsers = List.from(users);
        _pendingInitialized = true;
      } else {
        _detectNewUserRequests(users);
      }
      setState(() {
        _pendingUsers = users;
      });
      _prevPendingUsers = List.from(users);
    });

    _searchCtrl.addListener(() {
      setState(() {
        _filteredGuests = _applyFilter(_allGuests);
      });
    });

    _baseUrlSub = _firebase.baseUrlStream().listen((url) {
      if (mounted) setState(() => _baseUrl = url);
    });

    // Ensure background service is running
    _checkBackgroundService();
  }

  Future<void> _checkBackgroundService() async {
    final service = FlutterBackgroundService();
    bool isRunning = await service.isRunning();
    if (!isRunning) {
      debugPrint('Dashboard: Background service not running, starting...');
      await service.startService();
    }

    // Check for battery optimization (Crucial for background persistence)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Enable "Ignore Battery Optimization" to get real-time notifications even when the app is closed.'),
            action: SnackBarAction(
              label: 'Enable',
              onPressed: () => openAppSettings(),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  void _detectNewRsvps(List<GuestModel> newGuests) {
    for (final guest in newGuests) {
      final prev = _prevGuests.firstWhere(
        (g) => g.id == guest.id,
        orElse: () => GuestModel(
          id: '',
          name: '',
          whatsapp: '',
          numberOfGuests: 0,
          side: '',
          status: 'Invited',
          invitationStatus: '',
          clickCount: 0,
          invitationSent: false,
          rsvpGuests: 0,
        ),
      );

      final wasNotRsvpd = prev.status == 'Invited' || prev.id.isEmpty;
      final isNowRsvpd = guest.status == 'Attending' || guest.status == 'Declined';

      if (wasNotRsvpd && isNowRsvpd) {
        _notifications.showRsvpNotification(
          guestName: guest.displayName,
          status: guest.status,
          message: guest.rsvpMessage,
        );
      }
    }
  }

  void _detectNewGuestAdditions(List<GuestModel> newGuests) {
    if (_loading || _prevGuests.isEmpty) return;

    // ONLY notify the primary users (1st registered Groom/Bride)
    if (widget.currentUser['isPrimary'] != true) return;

    for (final guest in newGuests) {
      final bool isNew = _prevGuests.every((g) => g.id != guest.id);
      
      if (isNew) {
        // Only notify if someone else added it
        if (guest.addedByEmail != widget.currentUser['email']) {
          _notifications.showNewGuestNotification(
            guestName: guest.displayName,
            side: guest.side,
            addedByEmail: guest.addedByEmail ?? 'User',
            addedByRole: guest.addedByRole ?? 'Admin',
          );
        }
      }
    }
  }

  void _detectNewUserRequests(List<Map<String, dynamic>> newPending) {
    for (final user in newPending) {
      // Check if this user was already in our previous list
      final isNew = _prevPendingUsers.every((u) => u['id'] != user['id']);
      
      if (isNew) {
        debugPrint('NOTIFYING: New user request from ${user['email']}');
        _notifications.showNewUserRequestNotification(
          email: user['email'] ?? 'New User',
          role: user['role'] ?? 'User',
        );
      }
    }
  }

  List<GuestModel> _applyFilter(List<GuestModel> guests) {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return guests;
    return guests.where((g) {
      return g.name.toLowerCase().contains(q) ||
          g.whatsapp.contains(q) ||
          g.status.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _guestsSub?.cancel();
    _tablesSub?.cancel();
    _pendingSub?.cancel();
    _baseUrlSub?.cancel();
    _searchCtrl.dispose();
    _headerAnim.dispose();
    super.dispose();
  }

  Map<String, dynamic> get stats => _firebase.computeStats(_allGuests);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _loading
          ? _buildLoading()
          : Column(
              children: [
                _buildFixedHeader(),
                Expanded(child: _buildBody()),
              ],
            ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _selectedTab == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddGuestSheet,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add Guest'),
              backgroundColor: AppTheme.rosePrimary,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.rosePrimary),
          const SizedBox(height: 16),
          Text('Loading wedding data...',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildFixedHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.roseDark, AppTheme.rosePrimary, AppTheme.roseLight],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                    Text(
                      'Logged in as: ${widget.currentUser['role'] ?? 'User'}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white70),
                    ),
                  const Spacer(),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${stats['total']} Invitations',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.notifications_rounded,
                        color: Colors.white, size: 24),
                    onPressed: () {
                      _notifications.showStatsNotification(
                        total: stats['total']!,
                        attending: stats['attending']!,
                        pending: stats['pending']!,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Kalana & Chanchala',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'June 11, 2026 • Hotel Sundream',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              if (_pendingUsers.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildPendingApprovalsBanner(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _selectedTab,
      onDestinationSelected: (i) => setState(() => _selectedTab = i),
      backgroundColor: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
      indicatorColor: AppTheme.roseLight.withOpacity(0.4),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people_rounded),
          label: 'Guests',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart_rounded),
          label: 'Stats',
        ),
        NavigationDestination(
          icon: Icon(Icons.table_restaurant_outlined),
          selectedIcon: Icon(Icons.table_restaurant_rounded),
          label: 'Tables',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.settings_rounded),
          label: 'Settings',
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_selectedTab == 0) return _buildGuestsTab();
    if (_selectedTab == 1) return _buildStatsTab();
    if (_selectedTab == 2) return const TablesScreen();
    return ProfileScreen(currentUser: widget.currentUser);
  }

  // ──────────────────── GUESTS TAB ────────────────────

  Widget _buildGuestsTab() {
    return Column(
      children: [
        _buildSearchBar(),
        _buildFilterChips(),
        Expanded(
          child: _filteredGuests.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100),
                  itemCount: _filteredGuests.length,
                  itemBuilder: (ctx, i) => GuestCard(
                    guest: _filteredGuests[i],
                    table: _tables.firstWhere(
                      (t) => t.id == _filteredGuests[i].tableId,
                      orElse: () => TableModel(id: '', name: '', capacity: 0),
                    ),
                    onEdit: () => _showEditGuestSheet(_filteredGuests[i]),
                    onDelete: () => _confirmDelete(_filteredGuests[i]),
                    onSendWhatsApp: () => _sendWhatsApp(_filteredGuests[i]),
                    onCopyLink: () => _copyLink(_filteredGuests[i]),
                    onShare: () => _shareLink(_filteredGuests[i]),
                  ),
                ),
        ),
      ],
    );
  }

  String _activeFilter = 'All';

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Search guests by name, phone...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.rosePrimary),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Attending', 'Invited', 'Declined', 'Groom', 'Bride'];
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: filters.length,
        itemBuilder: (ctx, i) {
          final f = filters[i];
          final selected = _activeFilter == f;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(f),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _activeFilter = f;
                  _filteredGuests = _applyChipFilter(_allGuests, f);
                });
              },
              backgroundColor: Theme.of(context).cardTheme.color,
              selectedColor: AppTheme.rosePrimary.withOpacity(0.15),
              checkmarkColor: AppTheme.rosePrimary,
              labelStyle: TextStyle(
                color: selected ? AppTheme.rosePrimary : AppTheme.textMid,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
              side: BorderSide(
                color: selected ? AppTheme.rosePrimary : Colors.grey.shade200,
              ),
            ),
          );
        },
      ),
    );
  }

  List<GuestModel> _applyChipFilter(List<GuestModel> guests, String filter) {
    final q = _searchCtrl.text.toLowerCase();
    List<GuestModel> base;
    switch (filter) {
      case 'Attending':
        base = guests.where((g) => g.status == 'Attending').toList();
        break;
      case 'Invited':
        base = guests.where((g) => g.status == 'Invited').toList();
        break;
      case 'Declined':
        base = guests.where((g) => g.status == 'Declined').toList();
        break;
      case 'Groom':
        base = guests.where((g) => g.side == 'Groom').toList();
        break;
      case 'Bride':
        base = guests.where((g) => g.side == 'Bride').toList();
        break;
      default:
        base = guests;
    }
    if (q.isEmpty) return base;
    return base.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No guests found',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: Colors.grey)),
        ],
      ),
    );
  }

  // ──────────────────── STATS TAB ────────────────────

  Widget _buildStatsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stat cards grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              StatCard(
                label: 'Total Guests',
                value: '${stats['total']} invites',
                subValue: '${stats['totalPeopleInvited']} people',
                color: Theme.of(context).colorScheme.primary,
                icon: Icons.people_rounded,
              ),
              StatCard(
                label: 'Attending',
                value: stats['attending'].toString(),
                color: AppTheme.attending,
                icon: Icons.check_circle_rounded,
              ),
              StatCard(
                label: 'Pending',
                value: stats['pending'].toString(),
                color: AppTheme.pending,
                icon: Icons.schedule_rounded,
              ),
              StatCard(
                label: 'Declined',
                value: stats['declined'].toString(),
                color: AppTheme.declined,
                icon: Icons.cancel_rounded,
              ),
              StatCard(
                label: 'Groom Side',
                value: '${stats['groomSide']} invites',
                subValue:
                    '${stats['groomPeopleConfirmed']}/${stats['groomPeopleInvited']} people',
                color: isDark ? Colors.blueAccent : AppTheme.roseDark,
                icon: Icons.man_rounded,
              ),
              StatCard(
                label: 'Bride Side',
                value: '${stats['brideSide']} invites',
                subValue:
                    '${stats['bridePeopleConfirmed']}/${stats['bridePeopleInvited']} people',
                color: AppTheme.gold,
                icon: Icons.woman_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildRsvpChart(),
          const SizedBox(height: 16),
          _buildSideChart(),
        ],
      ),
    );
  }

  Widget _buildRsvpChart() {
    final attending = stats['attending']!.toDouble();
    final pending = stats['pending']!.toDouble();
    final declined = stats['declined']!.toDouble();
    final total = attending + pending + declined;
    if (total == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RSVP Overview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: attending,
                      color: AppTheme.attending,
                      title: '${(attending / total * 100).round()}%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: pending,
                      color: AppTheme.pending,
                      title: '${(pending / total * 100).round()}%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      radius: 80,
                    ),
                    PieChartSectionData(
                      value: declined,
                      color: AppTheme.declined,
                      title: '${(declined / total * 100).round()}%',
                      titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      radius: 80,
                    ),
                  ],
                  sectionsSpace: 3,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(AppTheme.attending, 'Attending', stats['attending']!),
                _legendItem(AppTheme.pending, 'Pending', stats['pending']!),
                _legendItem(AppTheme.declined, 'Declined', stats['declined']!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label, int value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label ($value)',
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildSideChart() {
    final groom = stats['groomSide']!.toDouble();
    final bride = stats['brideSide']!.toDouble();
    if (groom + bride == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Groom vs Bride Side',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (groom > bride ? groom : bride) + 5,
                  barGroups: [
                    BarChartGroupData(x: 0, barRods: [
                      BarChartRodData(
                        toY: groom,
                        color: AppTheme.roseDark,
                        width: 40,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ]),
                    BarChartGroupData(x: 1, barRods: [
                      BarChartRodData(
                        toY: bride,
                        color: AppTheme.gold,
                        width: 40,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ]),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (val, meta) {
                          if (val == 0) {
                            return const Text('Groom',
                                style: TextStyle(fontSize: 12));
                          }
                          return const Text('Bride',
                              style: TextStyle(fontSize: 12));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.shade200, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────── CONTACT PICKER ────────────────────
  Future<void> _pickContact(TextEditingController nameCtrl, TextEditingController waCtrl, Function(void Function()) setS) async {
    if (await FlutterContacts.requestPermission()) {
      final contact = await FlutterContacts.openExternalPick();
      if (contact != null) {
        // Fetch full contact details as openExternalPick only returns basic info
        final fullContact = await FlutterContacts.getContact(contact.id);
        if (fullContact != null && fullContact.phones.isNotEmpty) {
          setS(() {
            nameCtrl.text = fullContact.displayName;
            // Pick the first phone number
            String phone = fullContact.phones.first.number.replaceAll(RegExp(r'\D'), '');
            // Simple logic for local numbers (Sri Lanka 94)
            if (phone.startsWith('0')) {
              phone = '94${phone.substring(1)}';
            } else if (!phone.startsWith('94') && phone.length == 9) {
              phone = '94$phone';
            }
            waCtrl.text = phone;
          });
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission denied')),
        );
      }
    }
  }

  // ──────────────────── MODALS ────────────────────

  void _showAddGuestSheet() {
    final nameCtrl = TextEditingController();
    final waCtrl = TextEditingController();
    final guestsCtrl = TextEditingController(text: '1');
    String side = 'Groom';
    String title = 'Mr';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
              Text('Add New Guest',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              // Title Dropdown
              DropdownButtonFormField<String>(
                value: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: ['Mr', 'Ms', 'Miss', 'Mr & Ms', 'Mr & Family']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setS(() => title = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Guest Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waCtrl,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  hintText: '0712552525 or 94771234567',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contact_phone_rounded, color: AppTheme.rosePrimary),
                    onPressed: () => _pickContact(nameCtrl, waCtrl, setS),
                    tooltip: 'Pick from contacts',
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: guestsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Guests Count',
                          prefixIcon: Icon(Icons.group_outlined)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: side,
                      decoration: const InputDecoration(labelText: 'Side'),
                      items: ['Groom', 'Bride']
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setS(() => side = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add Guest'),
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty ||
                        waCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please fill all fields')),
                      );
                      return;
                    }
                    String wa = waCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
                    if (wa.startsWith('0')) wa = '94${wa.substring(1)}';
                    await _firebase.addGuest({
                      'title': title,
                      'name': nameCtrl.text.trim(),
                      'whatsapp': wa,
                      'numberOfGuests':
                          int.tryParse(guestsCtrl.text) ?? 1,
                      'side': side,
                      'status': 'Invited',
                      'addedByEmail': widget.currentUser['email'],
                      'addedByRole': widget.currentUser['role'],
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              '🎉 $title ${nameCtrl.text.trim()} added successfully!'),
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
      ),
    );
  }

  void _showEditGuestSheet(GuestModel guest) {
    final nameCtrl = TextEditingController(text: guest.name);
    final waCtrl = TextEditingController(text: guest.whatsapp);
    final guestsCtrl =
        TextEditingController(text: guest.numberOfGuests.toString());
    String side = guest.side;
    String status = guest.status;
    String title = guest.title.isNotEmpty ? guest.title : 'Mr';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
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
              Text('Edit Guest',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              // Title Dropdown
              DropdownButtonFormField<String>(
                value: title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                items: ['Mr', 'Ms', 'Miss', 'Mr & Ms', 'Mr & Family']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setS(() => title = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Guest Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: waCtrl,
                decoration: InputDecoration(
                  labelText: 'WhatsApp Number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contact_phone_rounded, color: AppTheme.rosePrimary),
                    onPressed: () => _pickContact(nameCtrl, waCtrl, setS),
                    tooltip: 'Pick from contacts',
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: guestsCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Guests Count',
                          prefixIcon: Icon(Icons.group_outlined)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: side,
                      decoration: const InputDecoration(labelText: 'Side'),
                      items: ['Groom', 'Bride']
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setS(() => side = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: ['Invited', 'Attending', 'Declined']
                    .map((s) =>
                        DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setS(() => status = v!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Changes'),
                  onPressed: () async {
                    String wa = waCtrl.text.trim().replaceAll(RegExp(r'\D'), '');
                    if (wa.startsWith('0')) wa = '94${wa.substring(1)}';
                    await _firebase.updateGuest(guest.id, {
                      'title': title,
                      'name': nameCtrl.text.trim(),
                      'whatsapp': wa,
                      'numberOfGuests':
                          int.tryParse(guestsCtrl.text) ?? 1,
                      'side': side,
                      'status': status,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(GuestModel guest) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Guest'),
        content: Text(
            'Are you sure you want to delete ${guest.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.declined),
            onPressed: () async {
              await _firebase.deleteGuest(guest.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${guest.name} deleted'),
                    backgroundColor: AppTheme.declined,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _sendWhatsApp(GuestModel guest) async {
    final String shortId = guest.shortId ?? '';
    final String urlId = shortId.isNotEmpty ? '&id=$shortId' : '';
    final String link = "${_baseUrl}invitation?name=${Uri.encodeComponent(guest.name)}$urlId";
    final String msg =
"Dear ${guest.displayName},\n\nYou're invited to the wedding of\n\n💍 Chanchala & Kalana 💍\n\nNumber of Guests: ${guest.numberOfGuests}\nSunday, July 12, 2026\n\n👇 View Invitation:\n$link";
    
    final Uri url = Uri.parse('https://wa.me/${guest.whatsapp}?text=${Uri.encodeComponent(msg)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await _firebase.markInvitationSent(guest.id);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('WhatsApp opened for ${guest.name}'),
          backgroundColor: AppTheme.attending,
        ),
      );
    }
  }

  void _copyLink(GuestModel guest) {
    final String shortId = guest.shortId ?? '';
    final String urlId = shortId.isNotEmpty ? '&id=$shortId' : '';
    final String link = "${_baseUrl}invitation?name=${Uri.encodeComponent(guest.name)}$urlId";
    Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invitation link copied to clipboard! 📋'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _shareLink(GuestModel guest) {
    final String shortId = guest.shortId ?? '';
    final String urlId = shortId.isNotEmpty ? '&id=$shortId' : '';
    final String link = "${_baseUrl}invitation?name=${Uri.encodeComponent(guest.name)}$urlId";
    Share.share(
      'Dear ${guest.displayName}, you are cordially invited to the wedding of Kalana & Chanchala. Please RSVP via this link: $link',
      subject: 'Wedding Invitation - Kalana & Chanchala',
    );
  }

  Widget _buildPendingApprovalsBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Text(
                'Pending User Approvals (${_pendingUsers.length})',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13, 
                  color: Theme.of(context).textTheme.titleMedium?.color
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._pendingUsers.map((u) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['email'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      Text(u['role'] ?? '', style: TextStyle(fontSize: 11, color: (u['role'] == 'Groom' ? Colors.blue : Colors.pink))),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _firebase.approveUser(u['id']),
                  child: const Text('Approve', style: TextStyle(color: Colors.green, fontSize: 12)),
                ),
                TextButton(
                  onPressed: () => _firebase.rejectUser(u['id']),
                  child: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
