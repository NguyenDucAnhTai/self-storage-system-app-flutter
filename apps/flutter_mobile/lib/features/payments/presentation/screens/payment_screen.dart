import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/payment_status_tracker.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.reservationId,
    required this.repository,
    required this.tracker,
  });
  final String reservationId;
  final PaymentRepository repository;
  final PaymentStatusTracker tracker;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  Payment? _latest;
  StreamSubscription<PaymentPollEvent>? _subscription;
  bool _loading = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    widget.tracker.stop();
    super.dispose();
  }

  Future<void> _createSession() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final payment = await widget.repository.createReservationDeposit(
        widget.reservationId,
      );
      if (!mounted) return;
      setState(() {
        _latest = payment;
        _loading = false;
      });
      _watch(payment);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not start payment. Please try again.';
        });
      }
    }
  }

  void _watch(Payment payment) {
    _subscription?.cancel();
    _subscription = widget.tracker
        .watch(payment.id)
        .listen(
          (event) {
            if (!mounted) return;
            switch (event) {
              case PaymentPollUpdate(:final payment):
                setState(() => _latest = payment);
              case PaymentPollError():
                setState(() => _error = 'Payment status could not be refreshed. Check your connection.');
              case PaymentPollTimeout():
                setState(() => _error = 'Payment status is taking longer than expected. Refresh to check again.');
            }
          },
        );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final payment = _latest;
    if (state == AppLifecycleState.resumed && payment != null) _watch(payment);
    if (state == AppLifecycleState.paused) {
      _subscription?.pause();
      widget.tracker.stop();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reservation deposit')),
    body: _loading && _latest == null
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _latest == null
        ? _RetryState(message: _error!, onRetry: _createSession)
        : _latest == null
        ? _RetryState(
            message: 'Payment session is unavailable.',
            onRetry: _createSession,
          )
        : _paymentContent(_latest!),
  );

  Widget _paymentContent(Payment payment) {
    final paid = payment.status == 'paid';
    final terminal = payment.isTerminal;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          paid
              ? 'Payment confirmed'
              : terminal
              ? 'Payment ${_statusLabel(payment.status).toLowerCase()}'
              : 'Scan to pay',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          '${payment.amount.toStringAsFixed(0)} VND',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 20),
        if (payment.qrUrl case final url? when url.isNotEmpty)
          Center(
            child: Image.network(
              url,
              width: 250,
              height: 250,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) =>
                  const Text('Payment QR could not be loaded.'),
            ),
          )
        else if (!paid)
          const Text(
            'The backend did not return a QR code. Retry creating the payment session or check your reservation status.',
          ),
        if (payment.referenceCode != null)
          _InfoLine(label: 'Reference', value: payment.referenceCode!),
        if (payment.expiresAt != null)
          _InfoLine(
            label: 'Expires',
            value: payment.expiresAt!.toLocal().toString(),
          ),
        _InfoLine(label: 'Status', value: _statusLabel(payment.status)),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!terminal)
          const Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text('Waiting for the backend to confirm your transfer…'),
          ),
        if (payment.status == 'expired' || payment.status == 'cancelled')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: _createSession,
              child: const Text('Try again'),
            ),
          ),
        if (terminal)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              paid
                  ? 'The backend confirmed your transfer.'
                  : 'The backend reported this payment status.',
            ),
          ),
      ],
    );
  }

  String _statusLabel(String status) => switch (status) {
    'paid' => 'Paid',
    'pending' => 'Pending',
    'partially_paid' => 'Partially paid',
    'expired' => 'Expired',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Expanded(child: Text(value, textAlign: TextAlign.end)),
      ],
    ),
  );
}

class _RetryState extends StatelessWidget {
  const _RetryState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
