import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

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
  bool _respondingReassignment = false;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getById(widget.reservationId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Reservation details'),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Tải lại',
        ),
      ],
    ),
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
            if (r.pendingUnitChange != null)
              _ReassignmentProposalCard(
                reservation: r,
                submitting: _respondingReassignment,
                onRespond: _respondUnitChange,
              ),
            if (r.unitChangeHistory.isNotEmpty) ...[
              const SizedBox(height: 8),
              _UnitChangeHistory(reservation: r),
            ],
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

  Future<void> _refresh() async {
    setState(() => _future = widget.repository.getById(widget.reservationId));
    try {
      final latest = await _future;
      if (mounted) widget.onReservationChanged?.call();
      if (latest.id.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không tìm thấy đơn đặt kho.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tải đơn đặt kho. Hãy thử lại.'),
          ),
        );
      }
    }
  }

  Future<void> _respondUnitChange(String action, String? rejectReason) async {
    if (_respondingReassignment) return;
    final current = await _future;
    if (current.pendingUnitChange == null) return;
    setState(() {
      _respondingReassignment = true;
    });
    String? outcomeError;
    try {
      final updated = await widget.repository.respondUnitReassign(
        current.id,
        action: action,
        rejectReason: rejectReason,
      );
      if (mounted) setState(() => _future = Future.value(updated));
      widget.onReservationChanged?.call();
    } catch (error) {
      try {
        final latest = await widget.repository.getById(current.id);
        if (mounted) {
          setState(() => _future = Future.value(latest));
          if (latest.pendingUnitChange != null) {
            outcomeError = _reassignError(error);
          }
        }
        widget.onReservationChanged?.call();
      } catch (_) {
        outcomeError = 'Chưa xác định được kết quả. Không tự gửi lại yêu cầu; hãy tải lại trạng thái trước khi thử tiếp.';
      }
    } finally {
      if (mounted) {
        setState(() => _respondingReassignment = false);
        if (outcomeError != null) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(outcomeError)));
        }
      }
    }
  }

  String _reassignError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (status == 403) {
        return 'Bạn không có quyền phản hồi đề xuất này.';
      }
      if (status == 404) {
        return 'Đề xuất hoặc đơn đặt kho không còn tồn tại.';
      }
      if (status == 409) {
        return 'Đề xuất đã thay đổi hoặc hết hiệu lực. Trạng thái mới nhất đã được tải.';
      }
      if (status == 400) {
        return 'Máy chủ không thể xử lý đề xuất ở trạng thái hiện tại.';
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        return 'Kết nối bị gián đoạn. Trạng thái đã được tải lại; không tự gửi lại yêu cầu.';
      }
    }
    return 'Không thể phản hồi đề xuất. Trạng thái mới nhất đã được tải.';
  }

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

class _ReassignmentProposalCard extends StatelessWidget {
  const _ReassignmentProposalCard({
    required this.reservation,
    required this.submitting,
    required this.onRespond,
  });
  final Reservation reservation;
  final bool submitting;
  final Future<void> Function(String action, String? reason) onRespond;

  @override
  Widget build(BuildContext context) {
    final proposal = reservation.pendingUnitChange!;
    final eligible = const {
      'confirmed',
      'payment_successful',
      'overdue',
    }.contains(reservation.status);
    final oldUnit = reservation.storageUnit ?? const <String, dynamic>{};
    final newUnit = proposal.newStorageUnit ?? const <String, dynamic>{};
    final facility = reservation.facility ?? const <String, dynamic>{};
    final oldName = _unitLabel(oldUnit);
    final newName = _unitLabel(newUnit);
    return Card(
      color: const Color(0xFFE7F5EF),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đề xuất đổi phòng kho',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _DetailRow(
              label: 'Cơ sở',
              value: '${facility['name'] ?? 'Theo đơn đặt kho'}',
            ),
            _DetailRow(label: 'Phòng hiện tại', value: oldName),
            _DetailRow(label: 'Phòng được đề xuất', value: newName),
            if (proposal.priceDifference != null)
              _DetailRow(
                label: 'Chênh lệch tiền thuê theo máy chủ',
                value:
                    _money(proposal.priceDifference!.abs()) +
                    (proposal.priceDifference! > 0
                        ? ' tăng'
                        : proposal.priceDifference! < 0
                        ? ' giảm'
                        : ''),
              ),
            _DetailRow(
              label: 'Đơn giá mới theo máy chủ',
              value:
                  '${_money(proposal.newPricePerUnit)} / ${_billingLabel(proposal.newOffering?['billingUnit'])}',
            ),
            _DetailRow(label: 'Lý do', value: proposal.reason),
            if (proposal.proposedAt != null)
              _DetailRow(label: 'Gửi lúc', value: _date(proposal.proposedAt!)),
            if (!eligible)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Đề xuất không thể phản hồi ở trạng thái đơn hiện tại.',
                ),
              ),
            if (eligible) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting
                      ? null
                      : () => _confirm(context, 'accept', null),
                  child: Text(submitting ? 'Đang xử lý…' : 'Chấp nhận đổi kho'),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: submitting ? null : () => _reject(context),
                  child: const Text('Từ chối đề xuất'),
                ),
              ),
            ],
            if (submitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _reject(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Từ chối đề xuất đổi kho'),
        content: TextField(
          controller: controller,
          maxLength: 500,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Lý do (không bắt buộc)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tiếp tục'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!context.mounted || reason == null) return;
    await _confirm(context, 'reject', reason.isEmpty ? null : reason);
  }

  Future<void> _confirm(
    BuildContext context,
    String action,
    String? reason,
  ) async {
    final accept = action == 'accept';
    final consequence = accept
        ? 'Khi được xác nhận, máy chủ sẽ chuyển đơn sang phòng mới và cập nhật đơn giá thuê theo đề xuất. Lịch nhận kho hiện tại giữ theo dữ liệu máy chủ.'
        : 'Từ chối sẽ hủy đơn đặt kho theo quy trình máy chủ và tạo yêu cầu hoàn tiền toàn bộ tiền cọc. Tiến độ hoàn tiền sẽ được cập nhật riêng.';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept ? 'Xác nhận đổi kho?' : 'Xác nhận từ chối?'),
        content: Text(consequence),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Xem lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(accept ? 'Chấp nhận' : 'Từ chối'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    await onRespond(action, reason);
  }
}

class _UnitChangeHistory extends StatelessWidget {
  const _UnitChangeHistory({required this.reservation});
  final Reservation reservation;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lịch sử đổi phòng',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final entry in reservation.unitChangeHistory.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${_changeStatus(entry.status)} · ${_unitLabel(entry.fromUnit ?? const {})} → ${_unitLabel(entry.toUnit ?? const {})}${entry.decisionAt == null ? '' : ' · ${_date(entry.decisionAt!)}'}',
              ),
            ),
        ],
      ),
    ),
  );
}

String _unitLabel(Map<String, dynamic> unit) {
  final number = unit['unitNumber']?.toString();
  if (number == null || number.isEmpty) return 'Thông tin phòng đang cập nhật';
  final floor = unit['floor'];
  final zone = unit['zone']?.toString();
  return 'Phòng $number${floor == null ? '' : ' · Tầng $floor'}${zone == null || zone.isEmpty ? '' : ' · Khu $zone'}';
}

String _money(num value) => NumberFormat.currency(
  locale: 'vi_VN',
  symbol: '₫',
  decimalDigits: 0,
).format(value);
String _date(DateTime value) =>
    DateFormat('dd/MM/yyyy HH:mm')
        .format(value.toUtc().add(const Duration(hours: 7)));
String _billingLabel(Object? value) => switch ('$value') {
  'day' => 'ngày',
  'week' => 'tuần',
  'month' => 'tháng',
  'year' => 'năm',
  _ => 'kỳ',
};
String _changeStatus(String value) => switch (value) {
  'pending' => 'Đang chờ phản hồi',
  'accepted' => 'Đã chấp nhận',
  'rejected' => 'Đã từ chối',
  _ => 'Đã cập nhật',
};

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
