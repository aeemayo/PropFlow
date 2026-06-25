import 'package:cloud_firestore/cloud_firestore.dart';

/// Type of transaction.
enum TransactionType { purchase, rent }

/// Model representing a transaction (purchase or rent receipt).
///
/// Maps to Firestore collection: `/transactions/{txId}`
class PropertyTransaction {
  final String id;
  final String userId;
  final String propertyId;
  final TransactionType type;
  final double amountUSDC;
  final int shares;
  final String txHash;
  final DateTime timestamp;

  PropertyTransaction({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.type,
    required this.amountUSDC,
    this.shares = 0,
    required this.txHash,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Link to the Arc testnet explorer for this transaction.
  String get explorerUrl => 'https://testnet.arcscan.app/tx/$txHash';

  factory PropertyTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PropertyTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      propertyId: data['propertyId'] ?? '',
      type: data['type'] == 'rent'
          ? TransactionType.rent
          : TransactionType.purchase,
      amountUSDC: (data['amountUSDC'] ?? 0).toDouble(),
      shares: data['shares'] ?? 0,
      txHash: data['txHash'] ?? '',
      timestamp:
          (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'propertyId': propertyId,
        'type': type == TransactionType.rent ? 'rent' : 'purchase',
        'amountUSDC': amountUSDC,
        'shares': shares,
        'txHash': txHash,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
