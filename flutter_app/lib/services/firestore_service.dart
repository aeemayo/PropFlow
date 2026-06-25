import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/property.dart';
import '../models/user_profile.dart';
import '../models/transaction.dart';

/// Service for all Firestore CRUD operations.
///
/// Manages users, properties, transactions, and rent distributions.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Users ──

  /// Get or create a user profile document.
  Future<UserProfile?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }

  /// Create a new user profile.
  Future<void> createUser(UserProfile user) async {
    await _db.collection('users').doc(user.uid).set(user.toFirestore());
  }

  /// Update user profile fields.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update(data);
  }

  /// Stream a user profile for real-time updates (KYC status changes).
  Stream<UserProfile?> streamUser(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromFirestore(doc);
    });
  }

  /// Submit KYC information.
  Future<void> submitKyc(
    String uid, {
    required String fullName,
    required String nationality,
    required String emiratesId,
  }) async {
    await _db.collection('users').doc(uid).update({
      'fullName': fullName,
      'nationality': nationality,
      'emiratesId': emiratesId,
      'kycStatus': 'pending',
    });
  }

  // ── Admin: KYC Management ──

  /// Get all users with pending KYC status.
  Stream<List<UserProfile>> streamPendingKycUsers() {
    return _db
        .collection('users')
        .where('kycStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList());
  }

  /// Approve a user's KYC.
  Future<void> approveKyc(String uid) async {
    await _db.collection('users').doc(uid).update({
      'kycStatus': 'approved',
    });
  }

  /// Reject a user's KYC.
  Future<void> rejectKyc(String uid) async {
    await _db.collection('users').doc(uid).update({
      'kycStatus': 'rejected',
    });
  }

  // ── Properties ──

  /// Get all active properties.
  Stream<List<Property>> streamProperties() {
    return _db
        .collection('properties')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Property.fromFirestore(doc)).toList());
  }

  /// Get a single property by ID.
  Future<Property?> getProperty(String propertyId) async {
    final doc = await _db.collection('properties').doc(propertyId).get();
    if (!doc.exists) return null;
    return Property.fromFirestore(doc);
  }

  /// Seed the demo property if it doesn't exist.
  Future<void> seedDemoProperty() async {
    final demo = Property.demoProperty();
    final doc = await _db.collection('properties').doc(demo.id).get();
    if (!doc.exists) {
      await _db.collection('properties').doc(demo.id).set(demo.toFirestore());
    }
  }

  // ── Transactions ──

  /// Record a transaction (purchase or rent receipt).
  Future<void> recordTransaction(PropertyTransaction tx) async {
    await _db.collection('transactions').add(tx.toFirestore());
  }

  /// Stream transactions for a specific user.
  Stream<List<PropertyTransaction>> streamUserTransactions(String userId) {
    return _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PropertyTransaction.fromFirestore(doc))
            .toList());
  }

  /// Get total rent earned by a user.
  Future<double> getTotalRentEarned(String userId) async {
    final snapshot = await _db
        .collection('transactions')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'rent')
        .get();

    return snapshot.docs.fold<double>(
      0.0,
      (total, doc) => total + ((doc.data()['amountUSDC'] ?? 0) as num).toDouble(),
    );
  }

  // ── Rent Distributions ──

  /// Record a rent distribution event.
  Future<void> recordRentDistribution({
    required String propertyId,
    required double totalUSDC,
    required double perTokenUSDC,
    required String txHash,
  }) async {
    await _db.collection('rentDistributions').add({
      'propertyId': propertyId,
      'totalUSDC': totalUSDC,
      'perTokenUSDC': perTokenUSDC,
      'txHash': txHash,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream rent distributions for a property.
  Stream<List<Map<String, dynamic>>> streamRentDistributions(
      String propertyId) {
    return _db
        .collection('rentDistributions')
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }
}
