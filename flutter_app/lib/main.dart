import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'utils/theme.dart';
import 'services/firestore_service.dart';
import 'services/contract_service.dart';
import 'services/circle_wallet_service.dart';
import 'services/cloud_function_service.dart';
import 'screens/login_screen.dart';
import 'screens/property_listing_screen.dart';
import 'screens/kyc_screen.dart';
import 'screens/buy_shares_screen.dart';
import 'screens/portfolio_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PropFlowApp());
}

class PropFlowApp extends StatelessWidget {
  const PropFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<ContractService>(create: (_) => ContractService()),
        Provider<CircleWalletService>(create: (_) => CircleWalletService()),
        Provider<CloudFunctionService>(create: (_) => CloudFunctionService()),
      ],
      child: MaterialApp(
        title: 'Propflow',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/kyc': (context) => const KycScreen(),
          '/properties': (context) => const PropertyListingScreen(),
          '/buy': (context) => const BuySharesScreen(),
          '/portfolio': (context) => const PortfolioScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}

/// Gate that routes to login or home based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),
          );
        }

        if (snapshot.hasData) {
          return const MainNavigation();
        }

        return const LoginScreen();
      },
    );
  }
}

/// Bottom navigation shell for the main app.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    PropertyListingScreen(),
    PortfolioScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Color(0xFF2A3352), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.apartment_rounded),
              activeIcon: Icon(Icons.apartment_rounded),
              label: 'Properties',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.pie_chart_outline_rounded),
              activeIcon: Icon(Icons.pie_chart_rounded),
              label: 'Portfolio',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
