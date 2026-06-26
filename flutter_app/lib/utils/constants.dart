class AppConstants {
  AppConstants._();

  // ── Arc Testnet ──
  static const String arcTestnetRpc = 'https://rpc.testnet.arc.network';
  static const int arcChainId = 5042002;
  static const String arcExplorerBase = 'https://testnet.arcscan.app';

  // ── USDC on Arc (ERC-20 interface, 6 decimals) ──
  static const String usdcAddress =
      '0x3600000000000000000000000000000000000000';
  static const int usdcDecimals = 6;

  // ── Deployed Contract Addresses (UPDATE AFTER REMIX DEPLOYMENT) ──
  static const String kycRegistryAddress =
      '0x0000000000000000000000000000000000000000';
  static const String propTokenAddress =
      '0x0000000000000000000000000000000000000000';
  static const String rentDistributorAddress =
      '0x0000000000000000000000000000000000000000';
  static const String propertyRegistryAddress =
      '0x0000000000000000000000000000000000000000';

  // ── Circle API (placeholder — configure after console.circle.com signup) ──
  static const String circleApiBaseUrl = 'https://api.circle.com';
  static const String circleApiKey = 'YOUR_CIRCLE_API_KEY';

  // ── Demo Property ──
  static const String demoPropertyName = 'Marina Studio — Dubai';
  static const String demoReraNumber = 'RERA-DXB-2024-00142';
  static const String demoLocation = 'Dubai Marina, UAE';
  static const double demoValuation = 200000;
  static const int demoTotalShares = 100000;
  static const double demoPricePerShare = 2.0;
  static const double demoMonthlyRent = 1200;

  // ── Cloud Functions base URL (update after Firebase deploy) ──
  static const String cloudFunctionsBaseUrl =
      'https://us-central1-propflow-aeem-26.cloudfunctions.net';
}
