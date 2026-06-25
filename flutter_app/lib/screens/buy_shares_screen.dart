import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/theme.dart';
import '../services/contract_service.dart';
import '../services/firestore_service.dart';
import '../models/property.dart';
import '../models/transaction.dart';

class BuySharesScreen extends StatefulWidget {
  final Property? property;

  static String investorPrivateKey = 'YOUR_PRIVATE_KEY';

  const BuySharesScreen({super.key, this.property});

  @override
  State<BuySharesScreen> createState() => _BuySharesScreenState();
}

class _BuySharesScreenState extends State<BuySharesScreen> {
  final _sharesController = TextEditingController();
  final _privateKeyController = TextEditingController(text: BuySharesScreen.investorPrivateKey);
  bool _obscurePrivateKey = true;
  bool _isProcessing = false;
  String? _txHash;
  double _usdcCost = 0;

  late Property _property;

  @override
  void initState() {
    super.initState();
    _property = widget.property ?? Property.demoProperty();
    _sharesController.addListener(_updateCost);
  }

  @override
  void dispose() {
    _sharesController.dispose();
    _privateKeyController.dispose();
    super.dispose();
  }

  void _updateCost() {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    setState(() {
      _usdcCost = shares * _property.pricePerShare;
    });
  }

  Future<void> _purchaseShares() async {
    final shares = int.tryParse(_sharesController.text) ?? 0;
    if (shares <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid number of shares'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final key = BuySharesScreen.investorPrivateKey.trim();
    if (key == 'YOUR_PRIVATE_KEY' || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Signer Private Key to purchase shares.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final cleanedKey = key.startsWith('0x') ? key.substring(2) : key;
    if (cleanedKey.length != 64) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Private Key. Must be a 64-character hex string.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    // Check KYC status
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final firestoreService = context.read<FirestoreService>();
    final contractService = context.read<ContractService>();
    final user = await firestoreService.getUser(uid);

    if (user == null || !user.isKycApproved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC verification required before purchasing'),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      return;
    }

    setState(() => _isProcessing = true);

    try {

      // Convert shares to 18-decimal token units
      final amount = ContractService.toWei(shares.toDouble());

      // NOTE: For hackathon demo, you'd need to provide the private key.
      // In production, this would go through Circle's transaction API.
      // For now, show the tx simulation flow.

      final txHash = await contractService.purchaseTokens(
        privateKey: key,
        amount: amount,
      );

      setState(() => _txHash = txHash);

      // Record transaction in Firestore
      await firestoreService.recordTransaction(
        PropertyTransaction(
          id: '',
          userId: uid,
          propertyId: _property.id,
          type: TransactionType.purchase,
          amountUSDC: _usdcCost,
          shares: shares,
          txHash: txHash,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Purchase successful! 🎉'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaction failed: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Shares'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _txHash != null ? _buildSuccessView() : _buildPurchaseForm(),
      ),
    );
  }

  Widget _buildPurchaseForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Property summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apartment_rounded,
                    color: Color(0xFF0A0E17), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _property.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_property.pricePerShare.toStringAsFixed(0)} USDC per share',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Shares input
        Text(
          'Number of Shares',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _sharesController,
          keyboardType: TextInputType.number,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: '0',
            hintStyle: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
            suffixText: 'shares',
            suffixStyle: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textMuted,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Quick amount buttons
        Row(
          children: [10, 50, 100, 500].map((amount) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                onPressed: () {
                  _sharesController.text = amount.toString();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  side: BorderSide(
                      color: AppTheme.primary.withValues(alpha: 0.3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '$amount',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Cost breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.accentCard,
          child: Column(
            children: [
              _CostRow(
                  label: 'Shares',
                  value:
                      '${int.tryParse(_sharesController.text) ?? 0}'),
              const SizedBox(height: 10),
              _CostRow(
                label: 'Price per share',
                value:
                    '${_property.pricePerShare.toStringAsFixed(2)} USDC',
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: Color(0xFF2A3352)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Cost',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    '${_usdcCost.toStringAsFixed(2)} USDC',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Monthly Rent Earned',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  Text(
                    '≈ ${((int.tryParse(_sharesController.text) ?? 0) * _property.rentPerToken).toStringAsFixed(4)} USDC',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.secondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Private Key input field
        Text(
          'Signer Private Key (Hex)',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _privateKeyController,
          obscureText: _obscurePrivateKey,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Enter 64-character hex private key...',
            hintStyle: GoogleFonts.inter(color: AppTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePrivateKey ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscurePrivateKey = !_obscurePrivateKey);
              },
            ),
          ),
          onChanged: (val) {
            BuySharesScreen.investorPrivateKey = val;
          },
        ),

        const SizedBox(height: 28),

        // Purchase button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed:
                (_isProcessing || _usdcCost <= 0) ? null : _purchaseShares,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.3),
            ),
            child: _isProcessing
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A0E17),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Processing...',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0A0E17),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Confirm Purchase',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 12),

        Center(
          child: Text(
            'Transaction is final on Arc (sub-second finality)',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        const SizedBox(height: 40),

        // Success animation
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child:
              const Icon(Icons.check_circle, color: AppTheme.success, size: 56),
        ),

        const SizedBox(height: 24),

        Text(
          'Purchase Successful!',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '${int.tryParse(_sharesController.text) ?? 0} shares of ${_property.name}',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),

        const SizedBox(height: 32),

        // Transaction hash
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.glassCard,
          child: Column(
            children: [
              Text(
                'Transaction Hash',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  if (_txHash != null) {
                    launchUrl(
                      Uri.parse(
                          ContractService.explorerTxUrl(_txHash!)),
                    );
                  }
                },
                child: Text(
                  _txHash ?? '',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: AppTheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap to view on Arc Explorer',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.accentCard,
          child: Column(
            children: [
              _CostRow(
                label: 'Shares Purchased',
                value: '${int.tryParse(_sharesController.text) ?? 0}',
              ),
              const SizedBox(height: 8),
              _CostRow(
                label: 'Total Paid',
                value: '${_usdcCost.toStringAsFixed(2)} USDC',
              ),
              const SizedBox(height: 8),
              _CostRow(
                label: 'Est. Monthly Rent',
                value:
                    '${((int.tryParse(_sharesController.text) ?? 0) * _property.rentPerToken).toStringAsFixed(4)} USDC',
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Properties'),
          ),
        ),
      ],
    );
  }
}

class _CostRow extends StatelessWidget {
  final String label;
  final String value;

  const _CostRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
