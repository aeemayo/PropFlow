import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/firestore_service.dart';
import '../services/circle_wallet_service.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = '';
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: AppConstants.googleWebClientId,
      );
      final googleUser = await GoogleSignIn.instance.authenticate();
      final googleAuth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && mounted) {
        final firestoreService = context.read<FirestoreService>();

        // Check if user profile exists
        var profile = await firestoreService.getUser(user.uid);

        if (profile == null) {
          // First-time user — create profile
          profile = UserProfile(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? '',
          );
          await firestoreService.createUser(profile);
        }

        // Blocking wallet creation if not already set
        if (profile.walletAddress == null || profile.walletAddress!.isEmpty) {
          setState(() => _statusMessage = 'Setting up your Arc wallet...');
          await _createWalletBlocking(user.uid);
        }

        // Seed demo property
        await firestoreService.seedDemoProperty();
      }
    } catch (e) {
      if (mounted) {
        final errorStr = e.toString();
        if (!errorStr.contains('canceled') && !errorStr.contains('cancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sign-in failed: $e'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });
      }
    }
  }

  Future<void> _createWalletBlocking(String uid) async {
    setState(() => _statusMessage = 'Creating your Arc wallet...');
    final walletService = context.read<CircleWalletService>();
    final firestoreService = context.read<FirestoreService>();
    try {
      final walletResult = await walletService.createWallet(uid);
      if (walletResult != null) {
        await firestoreService.updateUser(uid, {
          'walletId': walletResult['walletId'],
          'walletAddress': walletResult['walletAddress'],
        });
      }
    } catch (e) {
      debugPrint('Circle wallet creation failed: $e');
      // Non-fatal — user can still proceed; wallet creation retried on next login
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0A0E17),
              Color(0xFF0D1B2F),
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    // Logo / Brand
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF0A0E17),
                        size: 40,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Propflow',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Tokenized Nigerian Real Estate on Arc',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppTheme.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Chain badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Arc Testnet • USDC',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Feature highlights
                    _FeatureRow(
                      icon: Icons.token_outlined,
                      text: 'Buy fractional property shares',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.payments_outlined,
                      text: 'Monthly USDC rent distribution',
                    ),
                    const SizedBox(height: 12),
                    _FeatureRow(
                      icon: Icons.verified_user_outlined,
                      text: 'KYC-compliant onchain transfers',
                    ),

                    const Spacer(),

                    // Sign in button
                    SizedBox(
                      width: double.infinity,
                      height: _statusMessage.isNotEmpty ? 80 : 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1A1A2E),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF1A1A2E),
                                    ),
                                  ),
                                  if (_statusMessage.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _statusMessage,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Google "G" icon (text fallback)
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'G',
                                        style: GoogleFonts.inter(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF4285F4),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Powered by Circle & Arc',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),

                    const Spacer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}
