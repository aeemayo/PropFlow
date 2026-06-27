class AppConstants {
  AppConstants._();

  // ── Arc Testnet ──
  static const String arcTestnetRpc = 'https://rpc.testnet.arc.network';
  static const int arcChainId = 5042002;
  static const String arcExplorerBase = 'https://testnet.arcscan.app';

  // ── USDC on Arc (ERC-20 interface, 6 decimals) ──
  static const String usdcAddress = String.fromEnvironment(
    'USDC_ADDRESS',
    defaultValue: '0x3600000000000000000000000000000000000000',
  );
  static const int usdcDecimals = 6;

  // ── Deployed Contract Addresses (UPDATE AFTER REMIX DEPLOYMENT) ──
  static const String kycRegistryAddress = String.fromEnvironment(
    'KYC_REGISTRY_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );
  static const String propTokenAddress = String.fromEnvironment(
    'PROP_TOKEN_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );
  static const String rentDistributorAddress = String.fromEnvironment(
    'RENT_DISTRIBUTOR_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );
  static const String propertyRegistryAddress = String.fromEnvironment(
    'PROPERTY_REGISTRY_ADDRESS',
    defaultValue: '0x0000000000000000000000000000000000000000',
  );

  // ── Circle API (placeholder — configure after console.circle.com signup) ──
  static const String circleApiBaseUrl = 'https://api.circle.com';
  static const String circleApiKey = 'YOUR_CIRCLE_API_KEY';

  // ── Demo Property ──
  static const String demoPropertyName = 'Lekki Heights — Lagos';
  static const String demoReraNumber = 'LASRERA-LAG-2024-00891';
  static const String demoLocation = 'Lekki Phase 1, Lagos, Nigeria';
  static const double demoValuation = 200000;
  static const int demoTotalShares = 100000;
  static const double demoPricePerShare = 2.0;
  static const double demoMonthlyRent = 1200;

  // ── Cloud Functions base URL (update after Firebase deploy) ──
  static const String cloudFunctionsBaseUrl =
      'https://us-central1-propflow-aeem-26.cloudfunctions.net';

  // ── Google Sign-In Web Client ID (from google-services.json client_type: 3) ──
  static const String googleWebClientId =
      '51630635889-m7ljb060k8itq48tk2ntvr5s1rasjat7.apps.googleusercontent.com';
}
