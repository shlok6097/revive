import 'package:flutter/material.dart';
import '../../services/recovery_session_client.dart';

/// Customer-facing payment recovery page.
///
/// Designed with a modern, high-trust fintech checkout aesthetic.
/// Allows customers to seamlessly retry a failed transaction or pick an alternative
/// payment method guided by deterministic templates.
class CustomerRecoveryScreen extends StatefulWidget {
  const CustomerRecoveryScreen({
    super.key,
    this.sessionId,
    this.token,
    this.client,
    this.mockValidation,
  });

  final String? sessionId;
  final String? token;
  final RecoverySessionClient? client;
  final CustomerRecoveryValidation? mockValidation;

  @override
  State<CustomerRecoveryScreen> createState() => _CustomerRecoveryScreenState();
}

class _CustomerRecoveryScreenState extends State<CustomerRecoveryScreen> {
  late final RecoverySessionClient _client;
  CustomerRecoveryValidation? _validation;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  bool _isPaymentSuccess = false;
  String? _paymentReference;
  String _selectedMethod = 'UPI';
  bool _showMethodPicker = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? RecoverySessionClient();
    _validateSession();
  }

  Future<void> _validateSession() async {
    final sId = widget.sessionId ?? 'ses_sample';
    final tok = widget.token ?? 'tok_sample';

    if (widget.mockValidation != null) {
      setState(() {
        _validation = widget.mockValidation;
        _selectedMethod = widget.mockValidation!.paymentMethod;
        _isLoading = false;
      });
      return;
    }

    try {
      final res = await _client.validateRecoverySession(
        sessionId: sId,
        token: tok,
      );
      if (mounted) {
        setState(() {
          _validation = res;
          _selectedMethod = res.paymentMethod.isNotEmpty ? res.paymentMethod : 'UPI';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _validation = const CustomerRecoveryValidation(
            valid: false,
            error: 'Failed to connect to recovery service.',
          );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePaymentRetry() async {
    final sId = widget.sessionId ?? _validation?.sessionId ?? 'ses_sample';
    final tok = widget.token ?? 'tok_sample';

    setState(() => _isProcessingPayment = true);

    try {
      final res = await _client.startRecoveryPayment(
        sessionId: sId,
        token: tok,
        paymentMethod: _selectedMethod,
      );

      if (mounted) {
        setState(() {
          _isProcessingPayment = false;
          if (res['success'] == true) {
            _isPaymentSuccess = true;
            _paymentReference = res['paymentId'] as String? ?? 'PAY_REC_OK';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'REVIVE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Secure Payment Recovery',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE2E8F0), height: 1.0),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
            SizedBox(height: 20),
            Text(
              'Verifying secure recovery link...',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ],
        ),
      );
    }

    if (_validation == null || !_validation!.valid) {
      return _buildErrorCard(_validation?.error ?? 'This recovery link has expired or is invalid.');
    }

    if (_isPaymentSuccess) {
      return _buildSuccessCard();
    }

    return _buildRecoveryCard();
  }

  Widget _buildRecoveryCard() {
    final v = _validation!;
    final amountStr = '₹${v.amount.toStringAsFixed(2)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header alert banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFFEF3C7))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        v.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        v.message,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFB45309), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Order Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Due',
                            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          Text(
                            amountStr,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      _buildSummaryRow('Payment Method', _selectedMethod),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Issuing Bank', v.bank),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Transaction ID', v.transactionId ?? 'tx_rv_default'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Method picker
                if (_showMethodPicker || v.strategy == 'ALTERNATIVE_METHOD') ...[
                  const Text(
                    'SELECT ALTERNATIVE PAYMENT METHOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildMethodOption('UPI', 'Google Pay / PhonePe / Paytm / BHIM', Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 8),
                  _buildMethodOption('CARD', 'Credit / Debit Card (Visa, Mastercard, RuPay)', Icons.credit_card_outlined),
                  const SizedBox(height: 8),
                  _buildMethodOption('NETBANKING', 'Direct Bank Transfer (SBI, HDFC, ICICI, Axis)', Icons.account_balance_outlined),
                  const SizedBox(height: 20),
                ],

                // Action Buttons
                ElevatedButton(
                  onPressed: _isProcessingPayment ? null : _handlePaymentRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: _isProcessingPayment
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _showMethodPicker ? 'Pay $amountStr with $_selectedMethod' : v.actionPrompt,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),

                if (!_showMethodPicker && v.allowAlternate && v.strategy != 'ALTERNATIVE_METHOD') ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => setState(() => _showMethodPicker = true),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF334155),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Use Another Method', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],

                const SizedBox(height: 20),

                // Security footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '256-bit Encrypted Session • Powered by REVIVE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodOption(String value, String subtitle, IconData icon) {
    final isSelected = _selectedMethod == value;

    return InkWell(
      onTap: () => setState(() => _selectedMethod = value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? const Color(0xFF3B82F6) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ],
    );
  }

  Widget _buildSuccessCard() {
    final amountStr = '₹${_validation?.amount.toStringAsFixed(2) ?? "0.00"}';

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDF4),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Payment Recovered Successfully!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your payment of $amountStr has been verified and processed.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Reference', _paymentReference ?? 'PAY_REC_12345'),
                const Divider(height: 12),
                _buildSummaryRow('Method', _selectedMethod),
                const Divider(height: 12),
                _buildSummaryRow('Status', 'COMPLETED'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFEF2F2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Recovery Link Expired or Invalid',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
