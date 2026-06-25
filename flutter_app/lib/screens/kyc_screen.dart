import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/theme.dart';
import '../services/firestore_service.dart';
import '../models/user_profile.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _emiratesIdController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _nationalityController.dispose();
    _emiratesIdController.dispose();
    super.dispose();
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final firestoreService = context.read<FirestoreService>();
      await firestoreService.submitKyc(
        uid,
        fullName: _fullNameController.text.trim(),
        nationality: _nationalityController.text.trim(),
        emiratesId: _emiratesIdController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('KYC submitted! Awaiting admin approval.'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('KYC Verification'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: firestoreService.streamUser(uid),
        builder: (context, snapshot) {
          final user = snapshot.data;

          if (user?.kycStatus == KycStatus.approved) {
            return _buildStatusView(
              icon: Icons.verified_rounded,
              iconColor: AppTheme.success,
              title: 'KYC Approved',
              subtitle: 'Your identity has been verified. You can now trade property tokens.',
              showForm: false,
            );
          }

          if (user?.kycStatus == KycStatus.pending && user?.fullName != null) {
            return _buildStatusView(
              icon: Icons.hourglass_top_rounded,
              iconColor: AppTheme.warning,
              title: 'Verification Pending',
              subtitle: 'Your KYC application is under review. This usually takes a few minutes.',
              showForm: false,
            );
          }

          if (user?.kycStatus == KycStatus.rejected) {
            return _buildStatusView(
              icon: Icons.cancel_rounded,
              iconColor: AppTheme.error,
              title: 'KYC Rejected',
              subtitle: 'Your verification was not approved. Please resubmit with correct information.',
              showForm: true,
            );
          }

          // Default: show form
          return _buildForm();
        },
      ),
    );
  }

  Widget _buildStatusView({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool showForm,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          if (showForm) ...[
            const SizedBox(height: 40),
            _buildForm(),
          ],
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Identity Verification',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your KYC to start investing in tokenized real estate.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Full Name
            _buildLabel('Full Legal Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                hintText: 'As per your Emirates ID',
                prefixIcon: Icon(Icons.person_outline_rounded,
                    color: AppTheme.textMuted),
              ),
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 20),

            // Nationality
            _buildLabel('Nationality'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nationalityController,
              decoration: const InputDecoration(
                hintText: 'e.g. UAE, India, UK',
                prefixIcon:
                    Icon(Icons.flag_outlined, color: AppTheme.textMuted),
              ),
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 20),

            // Emirates ID
            _buildLabel('Emirates ID Number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emiratesIdController,
              decoration: const InputDecoration(
                hintText: '784-XXXX-XXXXXXX-X',
                prefixIcon:
                    Icon(Icons.badge_outlined, color: AppTheme.textMuted),
              ),
              style: GoogleFonts.inter(color: AppTheme.textPrimary),
              keyboardType: TextInputType.text,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),

            const SizedBox(height: 12),

            // Info notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.info, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your KYC data is stored securely. Approval grants on-chain access via KYCRegistry.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppTheme.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitKyc,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0A0E17),
                        ),
                      )
                    : const Text('Submit for Verification'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}
