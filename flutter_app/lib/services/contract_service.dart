import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:wallet/wallet.dart';
import '../utils/constants.dart';

/// Service for interacting with PropFlow smart contracts on Arc Testnet.
///
/// Uses web3dart to make read calls (view functions) and prepare transaction
/// data for write calls. For the hackathon MVP, write transactions require
/// a private key signer (developer-controlled wallet or imported key).
///
/// All contract ABIs are loaded from `assets/abi/`.
class ContractService {
  late Web3Client _client;
  bool _initialized = false;

  // Contract instances
  DeployedContract? _kycRegistry;
  DeployedContract? _propToken;
  DeployedContract? _rentDistributor;
  DeployedContract? _usdcToken;

  ContractService() {
    _client = Web3Client(AppConstants.arcTestnetRpc, http.Client());
  }

  /// Initialize contracts by loading ABIs from assets.
  Future<void> initialize() async {
    if (_initialized) return;

    _kycRegistry = await _loadContract(
      'KYCRegistry',
      AppConstants.kycRegistryAddress,
    );
    _propToken = await _loadContract(
      'PropToken',
      AppConstants.propTokenAddress,
    );
    _rentDistributor = await _loadContract(
      'RentDistributor',
      AppConstants.rentDistributorAddress,
    );
    _usdcToken = await _loadContract(
      'USDC',
      AppConstants.usdcAddress,
    );

    _initialized = true;
  }

  Future<DeployedContract> _loadContract(
      String name, String address) async {
    final abiString =
        await rootBundle.loadString('assets/abi/$name.json');
    final abi = ContractAbi.fromJson(abiString, name);
    return DeployedContract(abi, EthereumAddress.fromHex(address));
  }

  // ══════════════════════════════════════════════
  //  KYCRegistry — Read Operations
  // ══════════════════════════════════════════════

  /// Check if an address is KYC verified.
  Future<bool> isKycVerified(String address) async {
    await initialize();
    final result = await _client.call(
      contract: _kycRegistry!,
      function: _kycRegistry!.function('isVerified'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result.first as bool;
  }

  // ══════════════════════════════════════════════
  //  PropToken — Read Operations
  // ══════════════════════════════════════════════

  /// Get PropToken balance for an address (in wei, 18 decimals).
  Future<BigInt> getTokenBalance(String address) async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('balanceOf'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result.first as BigInt;
  }

  /// Get total supply of PropTokens (in wei).
  Future<BigInt> getTotalSupply() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('totalSupply'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get total shares (max supply).
  Future<BigInt> getTotalShares() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('totalShares'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get available shares for purchase.
  Future<BigInt> getSharesAvailable() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('sharesAvailable'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get price per token in USDC (6-decimal units).
  Future<BigInt> getPricePerToken() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('pricePerToken'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get total USDC raised.
  Future<BigInt> getTotalRaised() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('raised'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get number of unique holders.
  Future<BigInt> getHolderCount() async {
    await initialize();
    final result = await _client.call(
      contract: _propToken!,
      function: _propToken!.function('holderCount'),
      params: [],
    );
    return result.first as BigInt;
  }

  // ══════════════════════════════════════════════
  //  USDC — Read Operations
  // ══════════════════════════════════════════════

  /// Get USDC balance for an address (6-decimal units).
  Future<BigInt> getUsdcBalance(String address) async {
    await initialize();
    final result = await _client.call(
      contract: _usdcToken!,
      function: _usdcToken!.function('balanceOf'),
      params: [EthereumAddress.fromHex(address)],
    );
    return result.first as BigInt;
  }

  // ══════════════════════════════════════════════
  //  RentDistributor — Read Operations
  // ══════════════════════════════════════════════

  /// Get total rent ever claimed.
  Future<BigInt> getTotalClaimed() async {
    await initialize();
    final result = await _client.call(
      contract: _rentDistributor!,
      function: _rentDistributor!.function('totalClaimed'),
      params: [],
    );
    return result.first as BigInt;
  }

  /// Get total claimable rent for a holder in 6-decimal USDC units.
  Future<BigInt> getClaimableRent(String holderAddress) async {
    await initialize();
    final result = await _client.call(
      contract: _rentDistributor!,
      function: _rentDistributor!.function('getClaimableRent'),
      params: [EthereumAddress.fromHex(holderAddress)],
    );
    return result.first as BigInt;
  }

  /// Get total expired rent for a holder in 6-decimal USDC units.
  Future<BigInt> getExpiredRent(String holderAddress) async {
    await initialize();
    final result = await _client.call(
      contract: _rentDistributor!,
      function: _rentDistributor!.function('getExpiredRent'),
      params: [EthereumAddress.fromHex(holderAddress)],
    );
    return result.first as BigInt;
  }

  // ══════════════════════════════════════════════
  //  Write Operations (require credentials)
  // ══════════════════════════════════════════════



  /// Approve a KYC address (admin only).
  Future<String> approveKyc({
    required String privateKey,
    required String investorAddress,
  }) async {
    await initialize();
    final credentials = EthPrivateKey.fromHex(privateKey);

    final tx = Transaction.callContract(
      contract: _kycRegistry!,
      function: _kycRegistry!.function('approve'),
      parameters: [EthereumAddress.fromHex(investorAddress)],
    );

    return await _client.sendTransaction(
      credentials,
      tx,
      chainId: AppConstants.arcChainId,
    );
  }

  /// Revoke KYC for an address (admin only).
  Future<String> revokeKyc({
    required String privateKey,
    required String investorAddress,
  }) async {
    await initialize();
    final credentials = EthPrivateKey.fromHex(privateKey);

    final tx = Transaction.callContract(
      contract: _kycRegistry!,
      function: _kycRegistry!.function('revoke'),
      parameters: [EthereumAddress.fromHex(investorAddress)],
    );

    return await _client.sendTransaction(
      credentials,
      tx,
      chainId: AppConstants.arcChainId,
    );
  }



  // ══════════════════════════════════════════════
  //  Helpers
  // ══════════════════════════════════════════════

  /// Convert BigInt (18 decimals) to human-readable double.
  static double fromWei(BigInt wei) {
    return wei / BigInt.from(10).pow(18);
  }

  /// Convert BigInt (6 decimals) to human-readable double.
  static double fromUsdc(BigInt amount) {
    return amount / BigInt.from(10).pow(6);
  }

  /// Convert human-readable amount to 18-decimal BigInt.
  static BigInt toWei(double amount) {
    return BigInt.from(amount * 1e18);
  }

  /// Convert human-readable USDC to 6-decimal BigInt.
  static BigInt toUsdc(double amount) {
    return BigInt.from(amount * 1e6);
  }

  /// Build an Arc explorer URL for a transaction hash.
  static String explorerTxUrl(String txHash) {
    return '${AppConstants.arcExplorerBase}/tx/$txHash';
  }

  /// Build an Arc explorer URL for an address.
  static String explorerAddressUrl(String address) {
    return '${AppConstants.arcExplorerBase}/address/$address';
  }

  void dispose() {
    _client.dispose();
  }
}
