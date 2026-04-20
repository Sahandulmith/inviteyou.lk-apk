import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/guest_model.dart';
import '../models/table_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ──────────────────── GUESTS ────────────────────

  Stream<List<GuestModel>> guestsStream() {
    return _db.collection('wedding_guests').snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => GuestModel.fromFirestore(doc.data(), doc.id))
          .toList();
      list.sort((a, b) {
        final dateA = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(0);
        final dateB = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(0);
        return dateB.compareTo(dateA);
      });
      return list;
    });
  }

  Future<void> addGuest(Map<String, dynamic> data) async {
    await _db.collection('wedding_guests').add({
      ...data,
      'createdAt': DateTime.now().toIso8601String(),
      'invitationSent': false,
      'invitationStatus': 'pending',
      'clickCount': 0,
    });
  }

  Future<void> updateGuest(String id, Map<String, dynamic> data) async {
    await _db.collection('wedding_guests').doc(id).update(data);
  }

  Future<void> deleteGuest(String id) async {
    await _db.collection('wedding_guests').doc(id).delete();
  }

  Future<void> markInvitationSent(String id) async {
    await _db.collection('wedding_guests').doc(id).update({
      'invitationStatus': 'sent',
      'invitationSentAt': DateTime.now().toIso8601String(),
      'invitationSent': true,
    });
  }

  // ──────────────────── TABLES ────────────────────

  Stream<List<TableModel>> tablesStream() {
    return _db.collection('wedding_tables').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => TableModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  Future<void> addTable(String name, int capacity) async {
    final tableName = name.trim().startsWith('Table ')
        ? name.trim()
        : 'Table ${name.trim()}';
    await _db.collection('wedding_tables').add({
      'name': tableName,
      'capacity': capacity,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteTable(String id) async {
    await _db.collection('wedding_tables').doc(id).delete();
  }

  Future<void> assignGuestToTable(String guestId, String? tableId) async {
    await _db.collection('wedding_guests').doc(guestId).update({
      'tableId': tableId,
    });
  }

  // ──────────────────── STATS ────────────────────

  Map<String, dynamic> computeStats(List<GuestModel> guests) {
    int totalInvited = 0;
    int totalConfirmed = 0;
    int groomInvited = 0;
    int groomConfirmed = 0;
    int brideInvited = 0;
    int brideConfirmed = 0;

    for (var g in guests) {
      totalInvited += g.numberOfGuests;
      totalConfirmed += g.rsvpGuests;

      if (g.side == 'Groom') {
        groomInvited += g.numberOfGuests;
        groomConfirmed += g.rsvpGuests;
      } else if (g.side == 'Bride') {
        brideInvited += g.numberOfGuests;
        brideConfirmed += g.rsvpGuests;
      }
    }

    return {
      'total': guests.length,
      'attending': guests.where((g) => g.status == 'Attending').length,
      'pending': guests.where((g) => g.status == 'Invited').length,
      'declined': guests.where((g) => g.status == 'Declined').length,
      'groomSide': guests.where((g) => g.side == 'Groom').length,
      'brideSide': guests.where((g) => g.side == 'Bride').length,
      'sentCount': guests.where((g) => g.invitationSent).length,
      'totalPeopleInvited': totalInvited,
      'totalPeopleConfirmed': totalConfirmed,
      'groomPeopleInvited': groomInvited,
      'groomPeopleConfirmed': groomConfirmed,
      'bridePeopleInvited': brideInvited,
      'bridePeopleConfirmed': brideConfirmed,
    };
  }

  // ──────────────────── NOTIFICATIONS ────────────────────
  Future<void> saveAdminToken(String token) async {
    final query = await _db
        .collection('admin_tokens')
        .where('token', isEqualTo: token)
        .get();

    if (query.docs.isEmpty) {
      await _db.collection('admin_tokens').add({
        'token': token,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // ──────────────────── AUTH & USERS ────────────────────

  Future<Map<String, dynamic>?> signIn(String email, String password) async {
    final query = await _db
        .collection('dashboard_users')
        .where('email', isEqualTo: email)
        .where('password', isEqualTo: password)
        .get();

    if (query.docs.isEmpty) return null;
    
    final data = query.docs.first.data();
    return {
      'uid': query.docs.first.id,
      ...data,
    };
  }

  Future<void> signUp(String email, String password, String role) async {
    // Check if email exists
    final query = await _db
        .collection('dashboard_users')
        .where('email', isEqualTo: email)
        .get();

    if (query.docs.isNotEmpty) {
      throw Exception('Email already registered');
    }

    // Check if first user of this ROLE
    final roleSnapshot = await _db
        .collection('dashboard_users')
        .where('role', isEqualTo: role)
        .where('status', isEqualTo: 'approved')
        .limit(1)
        .get();
    final bool isFirstOfRole = roleSnapshot.docs.isEmpty;

    await _db.collection('dashboard_users').add({
      'email': email,
      'password': password,
      'role': role,
      'status': isFirstOfRole ? 'approved' : 'pending',
      'isPrimary': isFirstOfRole,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Stream<List<Map<String, dynamic>>> pendingUsersStream() {
    return _db
        .collection('dashboard_users')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  Future<void> approveUser(String userId) async {
    await _db.collection('dashboard_users').doc(userId).update({
      'status': 'approved',
    });
  }

  Future<void> rejectUser(String userId) async {
    await _db.collection('dashboard_users').doc(userId).delete();
  }

  Stream<List<Map<String, dynamic>>> allUsersStream() {
    return _db.collection('dashboard_users').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> deleteUser(String userId) async {
    await _db.collection('dashboard_users').doc(userId).delete();
  }

  // ──────────────────── APP SETTINGS ────────────────────
  Stream<String> baseUrlStream() {
    return _db
        .collection('app_settings')
        .doc('global')
        .snapshots()
        .map((doc) => doc.data()?['baseUrl'] ?? 'https://inviteyoulk.netlify.app/');
  }

  Future<void> updateBaseUrl(String url) async {
    await _db.collection('app_settings').doc('global').set({
      'baseUrl': url,
      'updatedAt': DateTime.now().toIso8601String(),
    }, SetOptions(merge: true));
  }
}
