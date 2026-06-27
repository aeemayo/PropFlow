import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/firestore_service.dart';
import '../models/property.dart';
import '../models/user_profile.dart';
import 'kyc_screen.dart';
import 'buy_shares_screen.dart';

class PropertyListingScreen extends StatelessWidget {
  const PropertyListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            backgroundColor: AppTheme.background,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Propflow',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            actions: [
              // KYC status indicator
              _KycStatusBadge(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.logout_rounded, size: 22),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'LIVE',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.success,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Investment Opportunities',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Property cards
          StreamBuilder<List<Property>>(
            stream: firestoreService.streamProperties(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppTheme.primary),
                  ),
                );
              }

              // Use demo property if Firestore is empty
              final properties = snapshot.data?.isNotEmpty == true
                  ? snapshot.data!
                  : [Property.demoProperty()];

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _PropertyCard(property: properties[index]),
                      );
                    },
                    childCount: properties.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// KYC status indicator in the app bar.
class _KycStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final firestoreService = context.read<FirestoreService>();

    return StreamBuilder<UserProfile?>(
      stream: firestoreService.streamUser(uid),
      builder: (context, snapshot) {
        final user = snapshot.data;
        final status = user?.kycStatus ?? KycStatus.pending;

        Color badgeColor;
        String label;
        IconData icon;

        switch (status) {
          case KycStatus.approved:
            badgeColor = AppTheme.success;
            label = 'KYC ✓';
            icon = Icons.verified_rounded;
            break;
          case KycStatus.pending:
            badgeColor = AppTheme.warning;
            label = 'KYC';
            icon = Icons.pending_rounded;
            break;
          case KycStatus.rejected:
            badgeColor = AppTheme.error;
            label = 'KYC ✗';
            icon = Icons.cancel_rounded;
            break;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KycScreen()),
            );
          },
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: badgeColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Premium property card with glass effect.
class _PropertyCard extends StatelessWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.glassCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image area
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A3A5C),
                  Color(0xFF0D2240),
                  Color(0xFF162D4A),
                ],
              ),
            ),
            child: Stack(
              children: [
                // Building illustration (placeholder)
                Center(
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 64,
                    color: AppTheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                // Location badge
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          property.location,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // RERA badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: AppTheme.secondary.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      property.reraNumber,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.name,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                // Stats row
                Row(
                  children: [
                    _StatChip(
                      label: 'Valuation',
                      value:
                          '\$${_formatNumber(property.valuationUSD)}',
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'Monthly Rent',
                      value:
                          '\$${_formatNumber(property.monthlyRent)}',
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(width: 10),
                    _StatChip(
                      label: 'Yield',
                      value:
                          '${property.annualYieldPercent.toStringAsFixed(1)}%',
                      color: AppTheme.success,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Price & shares info
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price per Share',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${property.pricePerShare.toStringAsFixed(0)} USDC',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Shares',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatNumber(
                                property.totalShares.toDouble()),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Buy button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BuySharesScreen(property: property),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.shopping_cart_outlined,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Buy Shares',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K';
    return n.toStringAsFixed(n == n.roundToDouble() ? 0 : 2);
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
