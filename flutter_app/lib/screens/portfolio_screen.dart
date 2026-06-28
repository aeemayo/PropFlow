import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/contract_service.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';
import '../models/transaction.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  BigInt _tokenBalance = BigInt.zero;
  BigInt _usdcBalance = BigInt.zero;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final firestoreService = context.read<FirestoreService>();
      final contractService = context.read<ContractService>();

      final user = await firestoreService.getUser(uid);

      if (user?.walletAddress != null && user!.walletAddress!.isNotEmpty) {
        try {
          _tokenBalance = await contractService.getTokenBalance(
            user.walletAddress!,
          );
          _usdcBalance = await contractService.getUsdcBalance(
            user.walletAddress!,
          );
        } catch (e) {
          debugPrint('Contract call failed: $e');
        }
      }

      // Rent earned is loaded via real-time stream inside build
    } catch (e) {
      debugPrint('Portfolio load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadPortfolio,
        color: AppTheme.primary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 80,
              floating: true,
              pinned: true,
              backgroundColor: AppTheme.background,
              title: Text(
                'Portfolio',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance overview card
                    _buildBalanceCard(uid, firestoreService),

                    const SizedBox(height: 20),

                    // Stats grid
                    _buildStatsGrid(),

                    const SizedBox(height: 24),

                    // Wallet info
                    StreamBuilder<UserProfile?>(
                      stream: firestoreService.streamUser(uid),
                      builder: (context, snapshot) {
                        final user = snapshot.data;
                        if (user?.walletAddress == null) {
                          return const SizedBox.shrink();
                        }
                        return _buildWalletCard(user!);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Transaction history
                    Text(
                      'Recent Activity',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    StreamBuilder<List<PropertyTransaction>>(
                      stream: firestoreService.streamUserTransactions(uid),
                      builder: (context, snapshot) {
                        final txs = snapshot.data ?? [];

                        if (txs.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(32),
                            decoration: AppTheme.glassCard,
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    color: AppTheme.textMuted,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No transactions yet',
                                    style: GoogleFonts.inter(
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Buy property shares to get started',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: txs
                              .map((tx) => _TransactionTile(tx: tx))
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(String uid, FirestoreService firestoreService) {
    final tokenDisplay = ContractService.fromWei(_tokenBalance);
    final usdcDisplay = ContractService.fromUsdc(_usdcBalance);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2A2A), Color(0xFF0D1B2F)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.1),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Holdings',
            style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 8),
          _isLoading
              ? Container(
                  width: 150,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
              : Text(
                  '${tokenDisplay.toStringAsFixed(0)} PROP',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
          const SizedBox(height: 4),
          _isLoading
              ? const SizedBox.shrink()
              : Text(
                  '≈ ${(tokenDisplay * 2).toStringAsFixed(2)} USDC',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF2A3352)),
          const SizedBox(height: 12),
          StreamBuilder<List<PropertyTransaction>>(
            stream: firestoreService.streamUserTransactions(uid),
            builder: (context, snapshot) {
              final txs = snapshot.data ?? [];
              final rentEarned = txs
                  .where((t) => t.type == TransactionType.rent)
                  .fold<double>(0.0, (sum, t) => sum + t.amountUSDC);

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _BalanceStat(
                    label: 'USDC Balance',
                    value: usdcDisplay.toStringAsFixed(2),
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                  _BalanceStat(
                    label: 'Rent Earned',
                    value: '${rentEarned.toStringAsFixed(2)} USDC',
                    icon: Icons.payments_outlined,
                    color: AppTheme.secondary,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.trending_up_rounded,
            label: 'Annual Yield',
            value: '7.2%',
            color: AppTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_month_rounded,
            label: 'Next Rent',
            value: 'Monthly',
            color: AppTheme.info,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletCard(UserProfile user) {
    final address = user.walletAddress ?? '';
    final shortAddress = address.length > 10
        ? '${address.substring(0, 6)}...${address.substring(address.length - 4)}'
        : address;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Arc Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shortAddress,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Connected',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _BalanceStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final PropertyTransaction tx;

  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isPurchase = tx.type == TransactionType.purchase;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.glassCard,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isPurchase ? AppTheme.primary : AppTheme.secondary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPurchase
                  ? Icons.shopping_cart_outlined
                  : Icons.payments_outlined,
              color: isPurchase ? AppTheme.primary : AppTheme.secondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPurchase ? 'Shares Purchased' : 'Rent Received',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPurchase ? '${tx.shares} shares' : 'Distribution',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPurchase ? '-' : '+'} ${tx.amountUSDC.toStringAsFixed(2)} USDC',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPurchase ? AppTheme.error : AppTheme.success,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${tx.txHash.substring(0, 8)}...',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
