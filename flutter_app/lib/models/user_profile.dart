import 'package:cloud_firestore/cloud_firestore.dart';

/// KYC verification status for an investor.
enum KycStatus { pending, approved, rejected }

/// Model representing a user's profile.
///
/// Maps to Firestore collection: `/users/{uid}`
class UserProfile {
  final String uid;
  final String email;
  final String displayName;
  final KycStatus kycStatus;
  final String? walletId;
  final String? walletAddress;
  final DateTime createdAt;

  // KYC fields
  final String? fullName;
  final String? nin;           // National Identification Number (11 digits)

  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    this.kycStatus = KycStatus.pending,
    this.walletId,
    this.walletAddress,
    DateTime? createdAt,
    this.fullName,
    this.nin,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isKycApproved => kycStatus == KycStatus.approved;
  bool get hasWallet => walletAddress != null && walletAddress!.isNotEmpty;

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      kycStatus: _parseKycStatus(data['kycStatus']),
      walletId: data['walletId'],
      walletAddress: data['walletAddress'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fullName: data['fullName'],
      nin: data['nin'],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'kycStatus': kycStatus.name,
        'walletId': walletId,
        'walletAddress': walletAddress,
        'createdAt': Timestamp.fromDate(createdAt),
        'fullName': fullName,
        'nin': nin,
      };

  UserProfile copyWith({
    KycStatus? kycStatus,
    String? walletId,
    String? walletAddress,
    String? fullName,
    String? nin,
  }) =>
      UserProfile(
        uid: uid,
        email: email,
        displayName: displayName,
        kycStatus: kycStatus ?? this.kycStatus,
        walletId: walletId ?? this.walletId,
        walletAddress: walletAddress ?? this.walletAddress,
        createdAt: createdAt,
        fullName: fullName ?? this.fullName,
        nin: nin ?? this.nin,
      );

  static KycStatus _parseKycStatus(String? status) {
    switch (status) {
      case 'approved':
        return KycStatus.approved;
      case 'rejected':
        return KycStatus.rejected;
      default:
        return KycStatus.pending;
    }
  }
}
