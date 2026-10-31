import 'package:flutter/material.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';

class ReservationDetailScreen extends StatefulWidget {
  const ReservationDetailScreen({
    super.key,
    required this.reservationId,
    required this.repository,
    this.onPayment,
    this.onReservationChanged,
  });
  final String reservationId;
  final ReservationRepository repository;
  final ValueChanged<Reservation>? onPayment;
  final VoidCallback? onReservationChanged;
  @override
  State<ReservationDetailScreen> createState() =>
      _ReservationDetailScreenState();
}

class _ReservationDetailScreenState extends State<ReservationDetailScreen> {
  late Future<Reservation> _future;
  bool _cancelling = false;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getById(widget.reservationId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reservation details')),
    body: FutureBuilder<Reservation>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _future = widget.repository.getById(widget.reservationId),
              ),
              child: const Text('Could not load. Try again'),
            ),
          );
        }
        final r = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              r.reservationCode,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Chip(label: Text(r.status)),
            const SizedBox(height: 8),
            _ReservationStatusProcessLine(status: r.status),
            _DetailRow(
              label: 'Check-in date',
              value: MaterialLocalizations.of(context)
                  .formatMediumDate(r.checkInDate.toLocal()),
            ),
            _DetailRow(label: 'Time slot', value: r.checkInTimeSlot),
            _DetailRow(
              label: 'Rental starts',
              value: MaterialLocalizations.of(context)
                  .formatMediumDate(r.startDate.toLocal()),
            ),
            _DetailRow(
              label: 'Duration',
              value: '${r.rentalDuration} ${r.billingUnit}',
            ),
            _DetailRow(
              label: 'Deposit',
              value: '${r.depositAmount.toStringAsFixed(0)} VND',
            ),
            if (r.expiresAt != null)
              _DetailRow(
                label: 'Hold expires',
                value: r.expiresAt!.toLocal().toString(),
              ),
            if (r.lastPaymentError != null) Text(r.lastPaymentError!),
            if (r.status == 'pending_payment' ||
                r.status == 'payment_failed') ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: widget.onPayment == null
                    ? null
                    : () => widget.onPayment!(r),
                child: const Text('Continue to payment'),
              ),
            ],
            if (const {
              'pending',
              'pending_payment',
              'payment_failed',
            }.contains(r.status)) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _cancelling ? null : () => _cancel(r),
                child: _cancelling
                    ? const CircularProgressIndicator()
                    : const Text('Cancel reservation'),
              ),
            ],
          ],
        );
      },
    ),
  );

  Future<void> _cancel(Reservation reservation) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Cancel reservation?'),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason (at least 3 characters)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Cancel reservation'),
            ),
          ],
        );
      },
    );
    if (reason == null || reason.trim().length < 3 || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final result = await widget.repository.cancel(reservation.id, reason);
      if (mounted) {
        setState(() => _future = Future.value(result));
        widget.onReservationChanged?.call();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancellation failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

class _ReservationStatusProcessLine extends StatelessWidget {
  const _ReservationStatusProcessLine({required this.status});

  final String status;

  static const _steps = [
    ('pending', 'Request received'),
    ('received', 'Reservation reviewed'),
    ('pending_payment', 'Payment pending'),
    ('payment_successful', 'Payment confirmed'),
    ('confirmed', 'Reservation confirmed'),
    ('completed', 'Completed'),
  ];

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status.trim().toLowerCase();
    final isPaymentFailed = normalizedStatus == 'payment_failed';
    final terminalMessage = switch (normalizedStatus) {
      'cancelled' => 'This reservation was cancelled.',
      'expired' => 'This reservation has expired.',
      'rejected' => 'This reservation was rejected.',
      _ => null,
    };
    final currentIndex = _steps.indexWhere(
      (step) => step.$1 == normalizedStatus,
    );
    final progressIndex = isPaymentFailed ? 2 : currentIndex;
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reservation progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (terminalMessage != null || isPaymentFailed)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  terminalMessage ??
                      'Payment failed. Please review the payment details.',
                  style: TextStyle(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (currentIndex < 0 && !isPaymentFailed)
              Text('Current status: $status')
            else
              for (var index = 0; index < _steps.length; index++)
                _ProcessLineStep(
                  title: _steps[index].$2,
                  isLast: index == _steps.length - 1,
                  isComplete:
                      index < progressIndex || normalizedStatus == 'completed',
                  isCurrent: index == progressIndex,
                  isFailed: isPaymentFailed && index == progressIndex,
                ),
          ],
        ),
      ),
    );
  }
}

class _ProcessLineStep extends StatelessWidget {
  const _ProcessLineStep({
    required this.title,
    required this.isLast,
    required this.isComplete,
    required this.isCurrent,
    required this.isFailed,
  });

  final String title;
  final bool isLast;
  final bool isComplete;
  final bool isCurrent;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isFailed
        ? colors.error
        : isComplete || isCurrent
        ? colors.primary
        : colors.outlineVariant;

    return SizedBox(
      height: isLast ? 32 : 44,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(
                  isFailed
                      ? Icons.error
                      : isComplete
                      ? Icons.check_circle
                      : isCurrent
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 20,
                  color: color,
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              title,
              style: TextStyle(
                color: isCurrent || isComplete || isFailed
                    ? colors.onSurface
                    : colors.onSurfaceVariant,
                fontWeight: isCurrent || isFailed
                    ? FontWeight.w700
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
