import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Service for calling Firebase Cloud Functions that perform on-chain
/// write operations. All transactions are signed server-side by the
/// platform wallet (ADMIN_PRIVATE_KEY in Cloud Functions .env).
///
/// Users never handle private keys.
class CloudFunctionService {
  final String _base = AppConstants.cloudFunctionsBaseUrl;

  /// Purchase PropToken shares on behalf of the investor.
  ///
  /// The Cloud Function uses the platform wallet to call
  /// PropToken.purchaseFor(recipientAddress, amount).
  ///
  /// [userId]  — Firebase UID (used to look up walletAddress in Firestore)
  /// [shares]  — number of whole shares to purchase
  ///
  /// Returns the transaction hash on success.
  Future<String> purchaseShares({
    required String userId,
    required int shares,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/purchaseShares'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId, 'shares': shares}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'purchaseShares failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['txHash'] as String;
  }

  /// Approve a user's KYC on-chain via KYCRegistry.approve().
  ///
  /// [walletAddress] — the investor's Arc wallet address
  ///
  /// Returns the transaction hash on success.
  Future<String> approveKycOnChain(String walletAddress) async {
    final response = await http.post(
      Uri.parse('$_base/approveKycOnChain'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'walletAddress': walletAddress}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'approveKycOnChain failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['txHash'] as String;
  }

  /// Trigger RentDistributor.distributeRent() from the platform wallet.
  ///
  /// Returns the transaction hash on success.
  Future<String> distributeRentOnChain() async {
    final response = await http.post(
      Uri.parse('$_base/distributeRentOnChain'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({}),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['error'] ?? 'distributeRentOnChain failed');
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['txHash'] as String;
  }
}
