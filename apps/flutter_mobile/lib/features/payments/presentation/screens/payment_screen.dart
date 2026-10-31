import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_ui.dart';
import '../../application/payment_status_tracker.dart';
import '../../data/models/payment.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.reservationId,
    required this.repository,
    required this.tracker,
    this.onPaymentStatusChanged,
  });
  final String reservationId;
  final PaymentRepository repository;
  final PaymentStatusTracker tracker;
  final VoidCallback? onPaymentStatusChanged;
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
      widget.onPaymentStatusChanged?.call();
      _watch(payment);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không thể khởi tạo phiên thanh toán. Vui lòng thử lại.';
        });
      }
    }
  }

  void _watch(Payment payment) {
    _subscription?.cancel();
    _subscription = widget.tracker.watch(payment.id).listen((event) {
      if (!mounted) return;
      switch (event) {
        case PaymentPollUpdate(:final payment):
          final statusChanged = _latest?.status != payment.status;
          setState(() => _latest = payment);
          if (statusChanged) widget.onPaymentStatusChanged?.call();
        case PaymentPollError():
          setState(
            () => _error = 'Chưa thể cập nhật trạng thái thanh toán. Vui lòng kiểm tra kết nối.',
          );
        case PaymentPollTimeout():
          setState(
            () => _error = 'Cập nhật trạng thái đang mất nhiều thời gian. Hãy thử kiểm tra lại.',
          );
      }
    });
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
    appBar: AppBar(title: const Text('Thanh toán tiền cọc đặt kho')),
    bottomNavigationBar: _paymentFooter(context),
    body: _loading && _latest == null
        ? const Center(child: CircularProgressIndicator())
        : _error != null && _latest == null
        ? _RetryState(message: _error!, onRetry: _createSession)
        : _latest == null
        ? _RetryState(
            message: 'Phiên thanh toán hiện không khả dụng.',
            onRetry: _createSession,
          )
        : _paymentContent(_latest!),
  );

  Widget _paymentContent(Payment payment) {
    final paid = payment.status == 'paid';
    final terminal = payment.isTerminal;
    final amount = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(payment.amount);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primary,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      paid
                          ? Icons.check_circle_outline
                          : Icons.payments_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        paid
                            ? 'Đã xác nhận thanh toán'
                            : terminal
                            ? 'Thanh toán ${_statusLabel(payment.status).toLowerCase()}'
                            : 'Thanh toán tiền cọc đặt kho',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(color: Colors.white),
                      ),
                    ),
                    _StatusPill(
                      label: _statusLabel(payment.status),
                      paid: paid,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Số tiền cần thanh toán',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: .78)),
                ),
                const SizedBox(height: 5),
                Text(
                  amount,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 7),
                Text(
                  'Mã thanh toán ${payment.paymentCode}',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withValues(alpha: .8)),
                ),
                if (payment.reservationId?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Mã đơn đặt kho ${payment.reservationId}',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Colors.white.withValues(alpha: .8)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (payment.qrUrl case final url? when url.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 25),
                  const SizedBox(height: 6),
                  Text(
                    paid ? 'Mã QR thanh toán' : 'Quét bằng ứng dụng ngân hàng',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Image.network(
                      url,
                      width: 220,
                      height: 220,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const SizedBox(
                              width: 220,
                              height: 220,
                              child: Center(child: CircularProgressIndicator()),
                            ),
                      errorBuilder: (_, error, stack) => const AppEmptyState(
                        icon: Icons.qr_code_2,
                        title: 'Không tải được mã QR',
                        message: 'Vui lòng kiểm tra kết nối và thử lại.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Thanh toán chỉ được xác nhận khi hệ thống ghi nhận trạng thái đã thanh toán.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          )
        else if (!paid)
          const AppEmptyState(
            icon: Icons.qr_code_2,
            title: 'Chưa có mã QR',
            message: 'Hệ thống chưa cung cấp mã QR thanh toán. Hãy thử lại hoặc kiểm tra trạng thái đơn đặt kho.',
          ),
        if (_bankDetails(payment).isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin chuyển khoản',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ..._bankDetails(payment).entries.map(
                    (entry) => _InfoLine(
                      label: entry.key,
                      value: entry.value,
                      onCopy: () => _copyValue(entry.value),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                _InfoLine(
                  label: 'Mã thanh toán',
                  value: payment.paymentCode,
                  onCopy: () => _copyValue(payment.paymentCode),
                ),
                if (payment.referenceCode?.isNotEmpty == true)
                  _InfoLine(
                    label: 'Nội dung chuyển khoản',
                    value: payment.referenceCode!,
                    onCopy: () => _copyValue(payment.referenceCode!),
                  ),
                if (payment.expiresAt != null)
                  _InfoLine(
                    label: 'Hết hạn lúc',
                    value: DateFormat('dd/MM/yyyy HH:mm')
                        .format(payment.expiresAt!.toLocal()),
                  ),
                _InfoLine(
                  label: 'Trạng thái',
                  value: _statusLabel(payment.status),
                ),
              ],
            ),
          ),
        ),
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
            padding: EdgeInsets.only(top: 10),
            child: Text('Đang chờ hệ thống xác nhận giao dịch…'),
          ),
        if (payment.status == 'expired' || payment.status == 'cancelled')
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton(
              onPressed: _createSession,
              child: const Text('Tạo lại phiên thanh toán'),
            ),
          ),
        if (terminal)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              paid
                  ? 'Hệ thống đã xác nhận giao dịch của bạn.'
                  : 'Trạng thái thanh toán được cập nhật từ hệ thống.',
            ),
          ),
      ],
    );
  }

  Widget? _paymentFooter(BuildContext context) {
    final payment = _latest;
    if (payment == null || payment.isTerminal) return null;
    return SafeArea(
      top: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: const [
            BoxShadow(
              color: Color(0x14003327),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: FilledButton.icon(
            onPressed: _loading ? null : () => _watch(payment),
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
            label: const Text('Kiểm tra trạng thái thanh toán'),
          ),
        ),
      ),
    );
  }

  Future<void> _copyValue(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Đã sao chép thông tin')));
  }

  Map<String, String> _bankDetails(Payment payment) {
    final info = payment.bankInfo;
    if (info == null) return const {};
    const labels = <String, String>{
      'bankName': 'Ngân hàng',
      'accountNumber': 'Số tài khoản',
      'accountName': 'Chủ tài khoản',
      'transferContent': 'Nội dung chuyển khoản',
      'transferNote': 'Nội dung chuyển khoản',
    };
    final details = <String, String>{};
    for (final entry in labels.entries) {
      final value = info[entry.key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        details.putIfAbsent(entry.value, () => value);
      }
    }
    return details;
  }

  String _statusLabel(String status) => switch (status) {
    'paid' => 'Đã thanh toán',
    'pending' => 'Chờ thanh toán',
    'partially_paid' => 'Đã thanh toán một phần',
    'expired' => 'Đã hết hạn',
    'cancelled' => 'Đã hủy',
    _ => status,
  };
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.paid});
  final String label;
  final bool paid;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: paid
          ? const Color(0xFF6FFBBE).withValues(alpha: .22)
          : Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: paid ? const Color(0xFFB8FFDD) : Colors.white,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value, this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.end, softWrap: true)),
        if (onCopy != null) ...[
          const SizedBox(width: 2),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Sao chép',
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 18),
          ),
        ],
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
          FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
