import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../payments/data/models/payment.dart';
import '../../payments/data/repositories/payment_repository.dart';
import '../data/contract_repository.dart';

class ContractDetailScreen extends StatefulWidget {
  const ContractDetailScreen({
    super.key,
    required this.contract,
    required this.repository,
    required this.paymentRepository,
    required this.onViewPayment,
    this.onManageRenewal,
    this.onContractChanged,
    this.onOpenSettlement,
  });
  final Map<String, dynamic> contract;
  final ContractRepository repository;
  final PaymentRepository paymentRepository;
  final Future<void> Function(Payment payment) onViewPayment;
  final VoidCallback? onManageRenewal;
  final VoidCallback? onContractChanged;
  final VoidCallback? onOpenSettlement;

  @override
  State<ContractDetailScreen> createState() => _ContractDetailScreenState();
}

class _ContractDetailScreenState extends State<ContractDetailScreen> {
  late Map<String, dynamic> _contract = Map<String, dynamic>.from(
    widget.contract,
  );
  bool _submitting = false;
  bool _refreshing = false;
  bool _loadingTerms = false;
  bool _paymentLoading = false;
  Payment? _firstPeriodPayment;
  String? _paymentError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPeriodPayment();
  }

  String? get _id => _read(_contract, ['id']);
  bool get _canSign =>
      _contract['status'] == 'draft' &&
      _contract['customerSigned'] != true &&
      _hasTerms;
  bool get _hasTerms =>
      _read(_contract, [
        'terms',
        'contractTerms',
        'termsContent',
        'termsText',
      ]) !=
      null;

  Future<void> _refresh({bool reportError = true}) async {
    final id = _id;
    if (id == null) return;
    setState(() => _refreshing = true);
    try {
      final latest = await widget.repository.detail(id);
      if (mounted) {
        setState(() {
          _contract = latest;
          _error = null;
        });
        widget.onContractChanged?.call();
      }
    } catch (_) {
      if (mounted && reportError) {
        setState(
          () => _error = 'Chưa thể đồng bộ trạng thái mới nhất từ máy chủ. Hãy thử tải lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
    await _loadFirstPeriodPayment();
  }

  Future<void> _loadFirstPeriodPayment() async {
    if (_paymentLoading) return;
    setState(() {
      _paymentLoading = true;
      _paymentError = null;
    });
    try {
      final payment = await _fetchFirstPeriodPayment();
      if (mounted) setState(() => _firstPeriodPayment = payment);
    } catch (_) {
      if (mounted) {
        setState(
          () => _paymentError =
              'Không thể tải khoản thanh toán. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _paymentLoading = false);
    }
  }

  Future<Payment?> _fetchFirstPeriodPayment() async {
    final contractId = _id;
    if (contractId == null ||
        !RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(contractId)) {
      throw const FormatException('Invalid contract ID.');
    }
    final payments = await widget.paymentRepository.listFirstPeriodForContract(
      contractId,
    );
    if (payments.isNotEmpty) return _preferredPayment(payments);

    // Backend only guarantees firstPeriodPaymentId after the payment is marked paid.
    final settledId = _read(_contract, ['firstPeriodPaymentId']);
    if (settledId != null && RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(settledId)) {
      final payment = await widget.paymentRepository.getById(settledId);
      if (payment.contractId == contractId &&
          payment.purpose == 'rent_first_period') {
        return payment;
      }
      throw const FormatException(
        'Contract payment did not match the contract.',
      );
    }
    return null;
  }

  Payment _preferredPayment(List<Payment> payments) {
    final now = DateTime.now();
    final sorted = [...payments]
      ..sort((a, b) {
        int rank(Payment payment) {
          final unexpired =
              payment.expiresAt == null || payment.expiresAt!.isAfter(now);
          if ((payment.status == 'pending' ||
                  payment.status == 'partially_paid') &&
              unexpired) {
            return 0;
          }
          if (payment.status == 'paid') {
            return 1;
          }
          if (payment.status == 'expired') {
            return 2;
          }
          if (payment.status == 'cancelled') {
            return 3;
          }
          return 4;
        }

        final byStatus = rank(a).compareTo(rank(b));
        if (byStatus != 0) return byStatus;
        return (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
    return sorted.first;
  }

  Future<void> _openPayment(Payment payment) async {
    await widget.onViewPayment(payment);
    if (mounted) await _refresh();
  }

  Future<void> _loadTerms() async {
    final id = _id;
    if (id == null || _loadingTerms) return;
    setState(() {
      _loadingTerms = true;
      _error = null;
    });
    try {
      final terms = await widget.repository.draftTerms(id);
      if (mounted) setState(() => _contract['terms'] = terms);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa thể tải điều khoản hợp đồng từ máy chủ. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingTerms = false);
    }
  }

  Future<void> _beginSign() async {
    if (!_canSign || _submitting || _id == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _TermsConfirmationDialog(
        terms: _read(_contract, [
          'terms',
          'contractTerms',
          'termsContent',
          'termsText',
        ])!,
      ),
    );
    if (accepted != true || !mounted || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    var postSucceeded = false;
    try {
      await widget.repository.acceptTerms(_id!);
      postSucceeded = true;
    } catch (_) {
      // The POST outcome may be ambiguous. Reconcile with a safe GET; never resend automatically.
    }
    try {
      final latest = await widget.repository.detail(_id!);
      if (!mounted) return;
      setState(() {
        _contract = latest;
        _error = latest['customerSigned'] == true
            ? null
            : postSucceeded
            ? 'Máy chủ đã nhận yêu cầu nhưng chưa xác nhận trạng thái ký. Vui lòng tải lại để kiểm tra.'
            : 'Không xác định được kết quả ký. Trạng thái đã được tải lại; vui lòng kiểm tra trước khi thử lại.';
      });
      if (latest['customerSigned'] == true) {
        Navigator.of(context).pop(true);
        return;
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Không thể xác nhận kết quả ký. Không tự gửi lại yêu cầu; hãy tải lại trạng thái hợp đồng.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final facility = _asMap(_contract['facility']);
    final unit = _asMap(_contract['storageUnit']);
    final facilityName = _read(facility ?? const {}, ['name']);
    final unitName = _read(unit ?? const {}, ['unitNumber', 'code']);
    final code = _read(_contract, ['contractCode']) ?? 'Hợp đồng kho';
    final status = '${_contract['status'] ?? ''}'.toLowerCase();
    final customerSigned = _contract['customerSigned'] == true;
    final staffSigned = _contract['staffSigned'] == true;
    final active = status == 'active';
    final storageUnitStatus = _statusText(unit?['status']);
    final payment = _paymentSummary(
      _contract,
      _firstPeriodPayment,
      loading: _paymentLoading,
      error: _paymentError,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết hợp đồng'),
        actions: [
          IconButton(
            onPressed: _refreshing || _paymentLoading ? null : _refresh,
            tooltip: 'Tải lại trạng thái',
            icon: _refreshing || _paymentLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
          children: [
            _HeaderCard(
              code: code,
              status: status,
              facility: facilityName,
              unit: unitName,
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Thông tin lưu trữ',
              icon: Icons.warehouse_outlined,
              children: [
                _InfoLine(label: 'Cơ sở', value: facilityName),
                _InfoLine(
                  label: 'Kho',
                  value: unitName == null ? null : 'Kho $unitName',
                ),
                _InfoLine(label: 'Tình trạng kho', value: storageUnitStatus),
                _InfoLine(
                  label: 'Thời hạn',
                  value: _dateRange(
                    _contract['startDate'],
                    _contract['endDate'],
                  ),
                ),
                _InfoLine(
                  label: 'Tiền thuê',
                  value: _money(
                    _contract['rentalPrice'],
                    _contract['billingUnit'],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Tiến trình hợp đồng',
              icon: Icons.route_outlined,
              children: [
                _TimelineStep(
                  title: 'Đặt cọc',
                  detail: payment.depositDetail,
                  complete: payment.depositPaid,
                  missing: payment.depositMissing,
                ),
                _TimelineStep(
                  title: 'Bạn đã ký hợp đồng',
                  detail: customerSigned
                      ? _dateDetail(_contract, [
                              'customerSignedAt',
                              'customerSignatureDate',
                              'signedAt',
                            ]) ??
                            'Máy chủ xác nhận đã ký'
                      : 'Chưa có xác nhận ký từ máy chủ',
                  complete: customerSigned,
                ),
                _TimelineStep(
                  title: 'Nhân viên ký hợp đồng',
                  detail: staffSigned
                      ? _dateDetail(_contract, [
                              'staffSignedAt',
                              'staffSignatureDate',
                            ]) ??
                            'Máy chủ xác nhận nhân viên đã ký'
                      : 'Chờ nhân viên hoàn tất thủ tục nhận kho',
                  complete: staffSigned,
                ),
                _TimelineStep(
                  title: 'Thanh toán tiền thuê kỳ đầu',
                  detail: payment.rentDetail,
                  complete: payment.rentPaid,
                  missing: payment.rentMissing,
                ),
                _TimelineStep(
                  title: 'Nhận kho thực tế',
                  detail: _checkInDetail(_contract),
                  complete: _isCheckedIn(_contract),
                ),
                _TimelineStep(
                  title: 'Hợp đồng hoạt động',
                  detail: active
                      ? 'Máy chủ xác nhận hợp đồng đang hoạt động'
                      : 'Chỉ hoàn tất khi trạng thái máy chủ xác nhận',
                  complete: active,
                  last: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _FirstPeriodPaymentCard(
              payment: _firstPeriodPayment,
              loading: _paymentLoading,
              error: _paymentError,
              contractPaidAt: _read(_contract, ['firstPeriodPaidAt']),
              onRetry: _loadFirstPeriodPayment,
              onViewPayment: _openPayment,
            ),
            const SizedBox(height: 16),
            _NextActionCard(
              contract: _contract,
              active: active,
              hasTerms: _hasTerms,
            ),
            if (widget.onManageRenewal != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onManageRenewal,
                icon: const Icon(Icons.event_repeat_outlined),
                label: const Text('Gia hạn & phụ lục hợp đồng'),
              ),
            ],
            if (status == 'completed' && widget.onOpenSettlement != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.onOpenSettlement,
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Xem quyết toán tiền cọc'),
              ),
            ],
            if (!_hasTerms && !customerSigned && status == 'draft') ...[
              const SizedBox(height: 12),
              const _Notice(
                text: 'Máy chủ chưa cung cấp nội dung điều khoản trong dữ liệu hợp đồng. Chưa thể yêu cầu xác nhận ký.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _loadingTerms ? null : _loadTerms,
                icon: _loadingTerms
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.description_outlined),
                label: Text(
                  _loadingTerms
                      ? 'Đang tải điều khoản…'
                      : 'Tải điều khoản từ máy chủ',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _Notice(
                text: _error!,
                error: true,
                action: TextButton.icon(
                  onPressed: _refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải lại'),
                ),
              ),
            ],
            const SizedBox(height: 18),
            if (customerSigned)
              const _SignedBanner()
            else if (_canSign)
              FilledButton.icon(
                onPressed: _submitting ? null : _beginSign,
                icon: _submitting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.draw_outlined),
                label: Text(
                  _submitting ? 'Đang xác nhận…' : 'Xem điều khoản và ký',
                ),
              ),
            if (customerSigned && !staffSigned && !active) ...[
              const SizedBox(height: 10),
              const _Notice(text: 'Chờ nhân viên hoàn tất thủ tục nhận kho.'),
            ],
          ],
        ),
      ),
    );
  }
}

class _TermsConfirmationDialog extends StatefulWidget {
  const _TermsConfirmationDialog({required this.terms});
  final String terms;
  @override
  State<_TermsConfirmationDialog> createState() =>
      _TermsConfirmationDialogState();
}

class _TermsConfirmationDialogState extends State<_TermsConfirmationDialog> {
  bool _accepted = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Xác nhận ký hợp đồng'),
    content: SizedBox(
      width: 440,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Điều khoản do máy chủ cung cấp:'),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(child: SelectableText(widget.terms)),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _accepted,
            onChanged: (value) => setState(() => _accepted = value ?? false),
            title: const Text('Tôi đã đọc và đồng ý với điều khoản hợp đồng.'),
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Quay lại'),
      ),
      FilledButton(
        onPressed: _accepted ? () => Navigator.pop(context, true) : null,
        child: const Text('Xác nhận ký'),
      ),
    ],
  );
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.code,
    required this.status,
    this.facility,
    this.unit,
  });
  final String code;
  final String status;
  final String? facility;
  final String? unit;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.primaryDarkGreen, AppTheme.primaryEmerald],
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.description_outlined,
          color: AppTheme.secondaryMint,
          size: 28,
        ),
        const SizedBox(height: 14),
        Text(
          code,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          [facility, if (unit != null) 'Kho $unit']
                  .whereType<String>()
                  .where((e) => e.isNotEmpty)
                  .join(' · ')
                  .isEmpty
              ? 'Thông tin hợp đồng lưu trữ'
              : [
                  facility,
                  if (unit != null) 'Kho $unit',
                ].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            _statusLabel(status),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryEmerald),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, this.value});
  final String label;
  final String? value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          child: Text(
            value ?? 'Chưa có dữ liệu từ máy chủ',
            style: TextStyle(
              color: value == null
                  ? AppTheme.secondaryText
                  : AppTheme.primaryText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.title,
    required this.detail,
    required this.complete,
    this.missing = false,
    this.last = false,
  });
  final String title;
  final String detail;
  final bool complete;
  final bool missing;
  final bool last;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          child: Column(
            children: [
              Icon(
                complete
                    ? Icons.check_circle
                    : missing
                    ? Icons.error_outline
                    : Icons.radio_button_unchecked,
                size: 19,
                color: complete
                    ? AppTheme.primaryEmerald
                    : missing
                    ? AppTheme.warning
                    : AppTheme.secondaryText,
              ),
              if (!last)
                Expanded(child: Container(width: 2, color: AppTheme.border)),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: complete
                        ? AppTheme.primaryDarkGreen
                        : AppTheme.primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(detail, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _FirstPeriodPaymentCard extends StatelessWidget {
  const _FirstPeriodPaymentCard({
    required this.payment,
    required this.loading,
    required this.error,
    required this.contractPaidAt,
    required this.onRetry,
    required this.onViewPayment,
  });
  final Payment? payment;
  final bool loading;
  final String? error;
  final String? contractPaidAt;
  final Future<void> Function() onRetry;
  final Future<void> Function(Payment) onViewPayment;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: AppTheme.primaryEmerald,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Thanh toán tiền thuê kỳ đầu',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            const Row(
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('Đang tải khoản thanh toán…')),
              ],
            )
          else if (error != null)
            _Notice(
              text: error!,
              error: true,
              action: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Thử lại'),
              ),
            )
          else if (payment == null && contractPaidAt != null)
            _paymentStatusLine(
              context,
              label: 'Đã thanh toán',
              detail:
                  'Hợp đồng ghi nhận đã thanh toán ngày ${_formatDate(contractPaidAt!)}. Không có mã giao dịch trong danh sách thanh toán.',
              paid: true,
            )
          else if (payment == null)
            const Text(
              'Chưa có yêu cầu thanh toán kỳ đầu.',
              style: TextStyle(color: AppTheme.secondaryText),
            )
          else ...[
            _paymentStatusLine(
              context,
              label: contractPaidAt == null
                  ? _paymentStatus(payment!)
                  : 'Đã thanh toán',
              detail: contractPaidAt == null
                  ? _paymentDetail(payment!)
                  : 'Hợp đồng ghi nhận thanh toán lúc ${_formatVietnamDateTime(contractPaidAt!)} (giờ Việt Nam).',
              paid: contractPaidAt != null || payment!.status == 'paid',
            ),
            const SizedBox(height: 8),
            if (payment!.amount >= 0)
              _paymentInfo(
                context,
                'Số tiền',
                _money(payment!.amount, null) ?? '—',
              ),
            _paymentInfo(context, 'Mã thanh toán', payment!.paymentCode),
            if (contractPaidAt == null && payment!.expiresAt != null)
              _paymentInfo(
                context,
                'Hết hạn',
                _formatDateTime(payment!.expiresAt!),
              ),
            if (contractPaidAt == null && _canOpen(payment!)) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onViewPayment(payment!),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Xem QR thanh toán'),
                ),
              ),
            ] else if (contractPaidAt == null &&
                payment!.status == 'pending' &&
                payment!.expiresAt?.isBefore(DateTime.now()) == true) ...[
              const SizedBox(height: 8),
              const Text(
                'Thời hạn QR đã qua; không mở lại mã này.',
                style: TextStyle(
                  color: AppTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ],
      ),
    ),
  );

  bool _canOpen(Payment payment) =>
      const {'pending', 'partially_paid'}.contains(payment.status) &&
      (payment.expiresAt == null || payment.expiresAt!.isAfter(DateTime.now()));

  String _paymentStatus(Payment payment) => switch (payment.status) {
    'pending' => 'Chờ thanh toán',
    'partially_paid' => 'Đã thanh toán một phần',
    'paid' => 'Đã thanh toán',
    'expired' => 'Đã hết hạn',
    'cancelled' => 'Đã hủy',
    _ => 'Đang cập nhật',
  };

  String _paymentDetail(Payment payment) {
    if (payment.status == 'paid') {
      final confirmed = payment.paidAt ?? payment.confirmedAt;
      return confirmed == null
          ? 'Máy chủ xác nhận đã thanh toán.'
          : 'Máy chủ xác nhận thanh toán lúc ${_formatDateTime(confirmed)}.';
    }
    return switch (payment.status) {
      'pending' => 'Khoản thanh toán được tạo trên máy chủ và đang chờ xử lý.',
      'partially_paid' => 'Máy chủ ghi nhận khoản thanh toán một phần.',
      'expired' => 'Khoản thanh toán đã hết hạn theo trạng thái máy chủ.',
      'cancelled' => 'Khoản thanh toán đã bị hủy theo trạng thái máy chủ.',
      _ => 'Trạng thái được lấy từ máy chủ.',
    };
  }

  Widget _paymentStatusLine(
    BuildContext context, {
    required String label,
    required String detail,
    required bool paid,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: paid ? AppTheme.lightMint : const Color(0xFFF3F6F4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: paid ? AppTheme.primaryEmerald : AppTheme.primaryText,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(detail, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );

  Widget _paymentInfo(BuildContext context, String label, String value) =>
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

String _formatDateTime(DateTime value) =>
    _formatVietnamDateTime(value.toIso8601String());

class _NextActionCard extends StatelessWidget {
  const _NextActionCard({
    required this.contract,
    required this.active,
    required this.hasTerms,
  });
  final Map<String, dynamic> contract;
  final bool active;
  final bool hasTerms;
  @override
  Widget build(BuildContext context) {
    final customerSigned = contract['customerSigned'] == true;
    final staffSigned = contract['staffSigned'] == true;
    final status = '${contract['status'] ?? ''}'.toLowerCase();
    final message = active
        ? 'Hợp đồng đang hoạt động.'
        : customerSigned && !staffSigned
        ? 'Bạn đã ký hợp đồng. Chờ nhân viên hoàn tất thủ tục nhận kho.'
        : status == 'draft' && !customerSigned && !hasTerms
        ? 'Chưa thể ký vì nội dung điều khoản chưa được cung cấp.'
        : status == 'draft' && !customerSigned
        ? 'Vui lòng xem nội dung điều khoản rồi xác nhận ký.'
        : 'Theo dõi tiến trình được cập nhật từ máy chủ.';
    return _Notice(text: message);
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.error = false, this.action});
  final String text;
  final bool error;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFEEEE) : AppTheme.lightMint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: error ? AppTheme.error : AppTheme.primaryDarkGreen,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (action != null)
          Align(alignment: Alignment.centerLeft, child: action!),
      ],
    ),
  );
}

class _SignedBanner extends StatelessWidget {
  const _SignedBanner();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppTheme.lightMint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Row(
      children: [
        Icon(Icons.verified_outlined, color: AppTheme.primaryEmerald),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Bạn đã ký hợp đồng',
            style: TextStyle(
              color: AppTheme.primaryDarkGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PaymentSummary {
  const _PaymentSummary({
    required this.depositPaid,
    required this.rentPaid,
    required this.depositMissing,
    required this.rentMissing,
    required this.depositDetail,
    required this.rentDetail,
    required this.firstPeriodRentMayBeDue,
  });
  final bool depositPaid;
  final bool rentPaid;
  final bool depositMissing;
  final bool rentMissing;
  final String depositDetail;
  final String rentDetail;
  final bool firstPeriodRentMayBeDue;
}

_PaymentSummary _paymentSummary(
  Map<String, dynamic> c,
  Payment? payment, {
  required bool loading,
  required String? error,
}) {
  final depositPaidAt = _read(c, ['depositPaidAt']);
  final deposit = depositPaidAt != null
      ? true
      : _paid(
          c,
          ['depositPaid', 'isDepositPaid'],
          ['depositPaymentStatus', 'depositStatus'],
          ['depositPayment'],
        );
  final firstPeriodPaidAt = _read(c, ['firstPeriodPaidAt']);
  final contractRentPaid = _paid(
    c,
    ['firstPeriodRentPaid', 'rentFirstPeriodPaid', 'isFirstPeriodRentPaid'],
    ['firstPeriodRentStatus', 'rentFirstPeriodStatus'],
    ['firstPeriodRentPayment', 'rentFirstPeriodPayment'],
  );
  final rent = firstPeriodPaidAt != null
      ? true
      : payment != null
      ? payment.status == 'paid'
      : contractRentPaid;
  final rentDetail = loading
      ? 'Đang tải trạng thái thanh toán kỳ đầu…'
      : error != null
      ? 'Không thể tải trạng thái thanh toán từ máy chủ.'
      : firstPeriodPaidAt != null
      ? 'Máy chủ xác nhận đã thanh toán kỳ đầu lúc ${_formatVietnamDateTime(firstPeriodPaidAt)} (giờ Việt Nam)'
      : payment != null
      ? switch (payment.status) {
          'pending' => 'Máy chủ ghi nhận đang chờ thanh toán',
          'partially_paid' => 'Máy chủ ghi nhận đã thanh toán một phần',
          'paid' => 'Máy chủ xác nhận đã thanh toán kỳ đầu',
          'expired' => 'Khoản thanh toán đã hết hạn',
          'cancelled' => 'Khoản thanh toán đã bị hủy',
          _ => 'Trạng thái thanh toán đang được máy chủ cập nhật.',
        }
      : contractRentPaid == true
      ? 'Máy chủ xác nhận đã thanh toán kỳ đầu'
      : contractRentPaid == false
      ? 'Máy chủ chưa xác nhận đã thanh toán kỳ đầu'
      : 'Chưa có dữ liệu thanh toán kỳ đầu từ máy chủ';
  return _PaymentSummary(
    depositPaid: deposit == true,
    rentPaid: rent == true,
    depositMissing: deposit == null,
    rentMissing: rent == null && payment == null,
    depositDetail: depositPaidAt != null
        ? 'Đã thanh toán tiền cọc${_moneyAmount(c['depositAmount']) == null ? '' : ' · ${_moneyAmount(c['depositAmount'])}'}\nLúc ${_formatVietnamDateTime(depositPaidAt)} (giờ Việt Nam)'
        : deposit == true
        ? 'Máy chủ xác nhận đã thanh toán tiền cọc'
        : deposit == false
        ? 'Máy chủ chưa xác nhận đã thanh toán tiền cọc'
        : 'Chưa có dữ liệu tiền cọc từ máy chủ',
    rentDetail: rentDetail,
    firstPeriodRentMayBeDue: rent != true,
  );
}

bool? _paid(
  Map<String, dynamic> c,
  List<String> flags,
  List<String> statuses,
  List<String> nested,
) {
  for (final key in flags) {
    if (c[key] is bool) return c[key] as bool;
  }
  for (final key in statuses) {
    final value = '${c[key] ?? ''}'.toLowerCase();
    if (value == 'paid') return true;
    if (value.isNotEmpty &&
        {
          'pending',
          'partially_paid',
          'expired',
          'cancelled',
          'failed',
          'unpaid',
        }.contains(value)) {
      return false;
    }
  }
  for (final key in nested) {
    final value = c[key];
    if (value is Map<String, dynamic>) {
      final status = '${value['status'] ?? ''}'.toLowerCase();
      if (status == 'paid') return true;
      if (status.isNotEmpty) return false;
    }
  }
  return null;
}

bool _isCheckedIn(Map<String, dynamic> c) {
  final checkIn = _read(c, [
    'actualCheckInDate',
    'actualCheckInAt',
    'checkedInAt',
    'checkInCompletedAt',
  ]);
  if (checkIn != null) {
    final parsed = _vietnamDateTime(checkIn);
    return parsed != null &&
        !parsed.isAfter(DateTime.now().toUtc().add(const Duration(hours: 7)));
  }
  return c['checkedIn'] == true || c['isCheckedIn'] == true;
}

String _checkInDetail(Map<String, dynamic> c) {
  final actual = _read(c, [
    'actualCheckInDate',
    'actualCheckInAt',
    'checkedInAt',
    'checkInCompletedAt',
  ]);
  if (actual != null) {
    final parsed = _vietnamDateTime(actual);
    if (parsed == null) return 'Máy chủ ghi nhận thời điểm nhận kho';
    final time = _formatVietnamDateTime(actual);
    if (parsed.isAfter(DateTime.now().toUtc().add(const Duration(hours: 7)))) {
      return 'Máy chủ ghi nhận thời điểm nhận kho lúc $time (giờ Việt Nam). Chưa thể xác nhận đã bàn giao thực tế.';
    }
    return 'Máy chủ xác nhận nhận kho lúc $time (giờ Việt Nam)';
  }
  if (c['checkedIn'] == true || c['isCheckedIn'] == true) {
    return 'Máy chủ xác nhận đã nhận kho';
  }
  final expected = _read(c, ['expectedCheckInDate', 'checkInDate']);
  return expected == null
      ? 'Chưa có xác nhận nhận kho thực tế từ máy chủ'
      : 'Dự kiến ${_formatDate(expected)} · Chưa xác nhận đã nhận kho';
}

String? _dateDetail(Map<String, dynamic> c, List<String> keys) {
  final date = _read(c, keys);
  return date == null
      ? null
      : 'Đã xác nhận lúc ${_formatVietnamDateTime(date)} (giờ Việt Nam)';
}

String _formatDate(String value) {
  final date = _vietnamDateTime(value);
  if (date == null) return value;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

DateTime? _vietnamDateTime(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return parsed.toUtc().add(const Duration(hours: 7));
}

String _formatVietnamDateTime(String value) {
  final date = _vietnamDateTime(value);
  if (date == null) return value;
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String? _moneyAmount(Object? value) {
  final amount = value is num ? value : num.tryParse('$value');
  return amount == null
      ? null
      : '${NumberFormat.decimalPattern('vi_VN').format(amount)} ₫';
}

String? _statusText(Object? value) => switch ('$value'.toLowerCase()) {
  'occupied' => 'Đang có khách thuê',
  'available' => 'Còn trống',
  'reserved' => 'Đã được giữ chỗ',
  'maintenance' => 'Đang bảo trì',
  _ => null,
};

String? _dateRange(Object? start, Object? end) {
  final a = _date(start);
  final b = _date(end);
  if (a == null && b == null) return null;
  if (a == null) return 'Đến $b';
  if (b == null) return 'Từ $a';
  return '$a – $b';
}

String? _date(Object? value) {
  if (value == null) return null;
  final date = DateTime.tryParse('$value');
  return date == null ? null : _formatDate('$value');
}

String? _money(Object? amount, Object? unit) {
  if (amount is! num) return null;
  final formatted = amount.round().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]}.',
  );
  final billing = switch ('$unit'.toLowerCase()) {
    'month' || 'monthly' => '/ tháng',
    'day' || 'daily' => '/ ngày',
    'year' || 'yearly' => '/ năm',
    _ => '',
  };
  return '$formatted ₫ $billing'.trim();
}

Map<String, dynamic>? _asMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;
String? _read(Map<String, dynamic> object, List<String> keys) {
  for (final key in keys) {
    final value = object[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') return text;
  }
  return null;
}

String _statusLabel(String status) => switch (status) {
  'draft' => 'Bản nháp',
  'active' => 'Đang hoạt động',
  'overdue' => 'Quá hạn',
  'completed' => 'Đã hoàn tất',
  'cancelled' => 'Đã hủy',
  'terminated' => 'Đã chấm dứt',
  _ => 'Đang xử lý',
};
