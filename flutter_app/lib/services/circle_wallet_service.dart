import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';

/// Service for Circle Wallets API integration.
///
/// Creates embedded wallets for investors on Arc Testnet via Circle's
/// Programmable Wallets (user-controlled). All API calls are proxied
/// through Firebase Cloud Functions for security (API key never exposed
/// to the client).
///
/// For the hackathon MVP, this service calls Cloud Functions endpoints.
/// Configure [AppConstants.cloudFunctionsBaseUrl] after Firebase deployment.
class CircleWalletService {
  final String _baseUrl = AppConstants.cloudFunctionsBaseUrl;

  /// Create a Circle user and wallet for a new investor.
  ///
  /// Called on first login after Firebase Auth. The Cloud Function:
  /// 1. Creates a Circle user (POST /v1/w3s/users)
  /// 2. Creates a wallet on ARC_TESTNET (POST /v1/w3s/user/wallets)
  /// 3. Returns { walletId, walletAddress }
  Future<Map<String, String>?> createWallet(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/createWallet'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return {
          'walletId': data['walletId'] as String,
          'walletAddress': data['walletAddress'] as String,
        };
      } else {
        debugPrint('Circle createWallet error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Circle createWallet exception: $e');
      return null;
    }
  }

  /// Get wallet details including balance.
  ///
  /// Returns { walletId, address, balances: [...] }
  Future<Map<String, dynamic>?> getWalletDetails(String walletId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/getWallet?walletId=$walletId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint('Circle getWallet error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Circle getWallet exception: $e');
      return null;
    }
  }

  /// Get USDC balance for a wallet.
  Future<double> getUsdcBalance(String walletId) async {
    final details = await getWalletDetails(walletId);
    if (details == null) return 0.0;

    final balances = details['balances'] as List<dynamic>? ?? [];
    for (final b in balances) {
      if (b is Map && (b['token']?.toString().toUpperCase() == 'USDC')) {
        return double.tryParse(b['amount']?.toString() ?? '0') ?? 0.0;
      }
    }
    return 0.0;
  }
}
