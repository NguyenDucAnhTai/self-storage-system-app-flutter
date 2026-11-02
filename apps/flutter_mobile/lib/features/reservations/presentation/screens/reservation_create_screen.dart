import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/widgets/app_ui.dart';
import '../../../explore/data/models/facility.dart';
import '../../../explore/data/repositories/facility_repository.dart';
import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';
import '../../../amenities/amenity_repository.dart';

class ReservationCreateScreen extends StatefulWidget {
  const ReservationCreateScreen({
    super.key,
    required this.facilityId,
    required this.offeringId,
    required this.unitTypeId,
    required this.minRentalDays,
    required this.repository,
    this.facilityRepository,
    this.amenityRepository,
    required this.onCreated,
  });
  final String facilityId, offeringId, unitTypeId;
  final int minRentalDays;
  final ReservationRepository repository;
  final FacilityRepository? facilityRepository;
  final AmenityRepository? amenityRepository;
  final ValueChanged<Reservation> onCreated;
  @override
  State<ReservationCreateScreen> createState() =>
      _ReservationCreateScreenState();
}

class _ReservationCreateScreenState extends State<ReservationCreateScreen> {
  late final TextEditingController _durationController;
  DateTime? _date;
  String? _slotId;
  Map<String, dynamic>? _unit;
  List<Map<String, dynamic>> _units = [];
  List<AvailableTimeSlot> _slots = [];
  late int _duration;
  bool _loadingSlots = false;
  bool _loadingUnits = false;
  bool _submitting = false;
  bool _termsAccepted = false;
  String? _slotError;
  String? _unitError;
  String? _submitError;
  String? _durationError;
  int? _submitErrorStatus;
  bool _submissionOutcomeUnknown = false;
  late Future<List<FacilityAmenityOffering>>? _amenityFuture;
  final Map<String, int> _selectedAmenities = {};
  int _availabilityRequest = 0;
  late final Future<FacilityDetail>? _facilityDetail = widget.facilityRepository
      ?.getDetail(widget.facilityId);

  @override
  void initState() {
    super.initState();
    _duration = widget.minRentalDays;
    _durationController = TextEditingController(text: '$_duration');
    _amenityFuture = widget.amenityRepository?.availableAt(widget.facilityId);
  }

  @override
  void dispose() {
    _durationController.dispose();
    super.dispose();
  }

  bool get _loading => _loadingSlots || _loadingUnits || _submitting;
  List<AvailableTimeSlot> get _selectableSlots => _slots
      .where(
        (s) =>
            s.isAvailable && s.availableCapacity > 0 && s.slotName.isNotEmpty,
      )
      .toList();
  AvailableTimeSlot? get _selectedSlot =>
      _selectableSlots.where((slot) => slot.slotName == _slotId).firstOrNull;
  bool get _hasValidSlot =>
      _slotId != null && _selectableSlots.any((s) => s.slotName == _slotId);
  bool get _hasValidUnit {
    final id = _unit?['id']?.toString();
    return id != null &&
        id.isNotEmpty &&
        _units.any(
          (u) => u['id']?.toString() == id && u['status'] == 'available',
        );
  }

  bool get _hasValidDate {
    final date = _date;
    if (date == null) return false;
    final chosen = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    return !chosen.isBefore(DateTime(today.year, today.month, today.day));
  }

  bool get _hasValidDuration =>
      _durationError == null && _duration >= widget.minRentalDays;
  bool get _canSubmit =>
      !_loading &&
      !_submissionOutcomeUnknown &&
      _hasValidUnit &&
      _hasValidDate &&
      _hasValidSlot &&
      _hasValidDuration &&
      _termsAccepted;
  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _date ?? DateTime(now.year, now.month, now.day + 1),
    );
    if (value == null) return;
    setState(() {
      _date = value;
      _slotId = null;
      _unit = null;
      _slots = [];
      _units = [];
      _submitError = null;
    });
    await _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final date = _date;
    if (date == null) return;
    final request = ++_availabilityRequest;
    setState(() {
      _loadingSlots = true;
      _loadingUnits = true;
      _slotError = null;
      _unitError = null;
      _slots = [];
      _units = [];
      _slotId = null;
      _unit = null;
    });
    await Future.wait([_loadSlots(request, date), _loadUnits(request)]);
  }

  Future<void> _loadSlots(int request, DateTime date) async {
    try {
      final slots = await widget.repository.getAvailability(
        widget.facilityId,
        date,
      );
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _slots = slots);
    } catch (error) {
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _slotError = _availabilityErrorMessage(error));
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _loadingSlots = false);
      }
    }
  }

  Future<void> _loadUnits(int request) async {
    try {
      final units = await widget.repository.getAvailableUnits(
        widget.facilityId,
        unitTypeId: widget.unitTypeId,
      );
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _units = units);
    } catch (error) {
      if (!mounted || request != _availabilityRequest) return;
      setState(() => _unitError = _availabilityErrorMessage(error));
    } finally {
      if (mounted && request == _availabilityRequest) {
        setState(() => _loadingUnits = false);
      }
    }
  }

  String _availabilityErrorMessage(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Yêu cầu đã quá thời gian chờ. Vui lòng kiểm tra kết nối và thử lại.';
      }
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tải tình trạng kho.';
      }
      if (status == 403) {
        return 'Bạn không có quyền xem tình trạng kho.';
      }
      if (status == 404) {
        return 'Không tìm thấy tình trạng kho của cơ sở này.';
      }
      if (status != null && status >= 500) {
        return 'Máy chủ chưa thể tải tình trạng kho. Vui lòng thử lại.';
      }
      if (status == null) {
        return 'Không thể kết nối. Hãy kiểm tra mạng và thử lại.';
      }
    }
    if (error is ApiError) {
      if (error.statusCode == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại để tải tình trạng kho.';
      }
      if (error.statusCode == 403) {
        return 'Bạn không có quyền xem tình trạng kho.';
      }
      if (error.statusCode == 404) {
        return 'Không tìm thấy tình trạng kho của cơ sở này.';
      }
      if ((error.statusCode ?? 0) >= 500) {
        return 'The server could not load availability. Try again.';
      }
      return error.message;
    }
    if (error is FormatException || error is TypeError) {
      return 'Dữ liệu tình trạng kho không đúng định dạng.';
    }
    return 'Không thể tải tình trạng kho. Vui lòng thử lại.';
  }

  Future<void> _showTimeSlots() async {
    if (_loadingSlots || _slotError != null || _slots.isEmpty) return;
    final selected = await showModalBottomSheet<AvailableTimeSlot>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chọn giờ nhận kho',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Các khung giờ do cơ sở cung cấp',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _slots.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final slot = _slots[index];
                    final selectable = _selectableSlots.any(
                      (item) => item.slotName == slot.slotName,
                    );
                    final isSelected = selectable && _slotId == slot.slotName;
                    final secondary = Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant;
                    final muted = secondary.withValues(alpha: .55);
                    final detail = selectable
                        ? '${slot.startTime}–${slot.endTime} · Còn ${slot.availableCapacity} chỗ'
                        : slot.availableCapacity <= 0
                        ? '${slot.startTime}–${slot.endTime} · Hết chỗ'
                        : '${slot.startTime}–${slot.endTime} · Không khả dụng';
                    return Card(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : null,
                      child: ListTile(
                        enabled: selectable,
                        onTap: selectable
                            ? () => Navigator.of(context).pop(slot)
                            : null,
                        leading: Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : selectable
                              ? Icons.schedule_rounded
                              : Icons.block_rounded,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : selectable
                              ? Theme.of(context).colorScheme.secondary
                              : muted,
                        ),
                        title: Text(
                          slot.slotName.isEmpty ? 'Khung giờ' : slot.slotName,
                          style: TextStyle(color: selectable ? null : muted),
                        ),
                        subtitle: Text(
                          detail,
                          style: TextStyle(
                            color: selectable ? secondary : muted,
                          ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_rounded,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _slotId = selected.slotName;
      _submitError = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đặt kho')),
    bottomNavigationBar: SafeArea(
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
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSubmit ? _submit : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_submitting) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(_submitting ? 'Đang xác nhận…' : 'Xác nhận đặt kho'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    body: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReservationProgress(
              currentStep: _termsAccepted
                  ? 3
                  : (_hasValidUnit && _hasValidDate && _hasValidSlot ? 2 : 1),
            ),
            const SizedBox(height: 20),
            if (_facilityDetail != null) ...[
              FutureBuilder<FacilityDetail>(
                future: _facilityDetail,
                builder: (context, snapshot) {
                  if (snapshot.hasError || !snapshot.hasData) {
                    return const SizedBox.shrink();
                  }
                  final detail = snapshot.data!;
                  final offering = detail.offerings
                      .where((item) => item.id == widget.offeringId)
                      .firstOrNull;
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FacilityImage(
                          url: detail.facility.images.isEmpty
                              ? null
                              : detail.facility.images.first,
                          height: 136,
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                detail.facility.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${detail.facility.city} · ${detail.facility.address}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (offering != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.warehouse_outlined),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${offering.name}${offering.area == null ? '' : ' · ${offering.area!.toStringAsFixed(1)} m²'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'Thông tin đặt kho',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Chọn ngày, giờ nhận kho và kho còn trống.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const AppSectionHeader(
              title: 'Ngày nhận kho',
              subtitle: 'Chọn ngày bạn muốn nhận kho',
            ),
            const SizedBox(height: 10),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _loading ? null : _chooseDate,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _date == null
                              ? 'Chọn ngày'
                              : MaterialLocalizations.of(context)
                                    .formatMediumDate(_date!.toLocal()),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            if (_amenityFuture != null) ...[
              const SizedBox(height: 24),
              _amenitySelector(),
              const SizedBox(height: 16),
            ],
            if (_date != null) ...[
              const SizedBox(height: 24),
              AppSectionHeader(
                title: 'Giờ nhận kho',
                trailing: IconButton(
                  tooltip: 'Tải lại tình trạng kho',
                  onPressed: _loadingSlots ? null : _loadAvailability,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingSlots) const LinearProgressIndicator(),
              if (_slotError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _slotError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadingSlots ? null : _loadAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              Card(
                color: _selectedSlot != null
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _loadingSlots || _slotError != null || _slots.isEmpty
                      ? null
                      : _showTimeSlots,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 17,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _selectedSlot == null
                              ? Icons.schedule_rounded
                              : Icons.check_circle_rounded,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _selectedSlot == null
                                ? 'Chọn giờ nhận kho'
                                : '${_selectedSlot!.startTime}–${_selectedSlot!.endTime} · Còn ${_selectedSlot!.availableCapacity} chỗ',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: _selectedSlot == null
                                      ? Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                      : Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                        Icon(
                          _slots.isNotEmpty
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.chevron_right_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_slots.isEmpty && !_loadingSlots && _slotError == null)
                Card(
                  child: AppEmptyState(
                    icon: Icons.schedule_outlined,
                    title: 'Không có khung giờ nhận kho',
                    message: 'Ngày này chưa có khung giờ nhận kho. Hãy chọn ngày khác hoặc tải lại tình trạng.',
                    action: OutlinedButton.icon(
                      onPressed: _loadAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tải lại khung giờ'),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const AppSectionHeader(
                title: 'Kho thực tế',
                subtitle: 'Chọn kho còn trống do cơ sở cung cấp',
              ),
              const SizedBox(height: 10),
              if (_units.where((u) => u['status'] == 'available').isEmpty &&
                  !_loadingUnits &&
                  _unitError == null)
                const AppEmptyState(
                  icon: Icons.warehouse_outlined,
                  title: 'Chưa có kho phù hợp',
                  message: 'Cơ sở chưa trả về kho vật lý còn trống cho loại kho này.',
                ),
              ..._units.where((u) => u['status'] == 'available').map((unit) {
                final selected =
                    _unit?['id']?.toString() == unit['id']?.toString();
                final name = '${unit['unitNumber'] ?? 'Kho'}';
                final floor = unit['floor']?.toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    color: selected
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _loadingUnits || _unitError != null
                          ? null
                          : () => setState(() {
                              _unit = unit;
                              _submitError = null;
                            }),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Row(
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.warehouse_outlined),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    floor == null || floor.isEmpty
                                        ? name
                                        : '$name · Tầng $floor',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Kho vật lý còn trống',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              color: selected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (_loadingUnits) const LinearProgressIndicator(),
              if (_unitError != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _unitError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _loadingUnits ? null : _loadAvailability,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'Thời hạn thuê'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Thời hạn thuê (ngày)',
                      helperText: 'Tối thiểu ${widget.minRentalDays} ngày',
                      errorText: _durationError,
                      suffixIcon: const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Center(widthFactor: 1, child: Text('ngày')),
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      final duration = int.tryParse(value);
                      _duration = duration ?? 0;
                      _durationError = switch (duration) {
                        null => 'Vui lòng nhập thời hạn thuê.',
                        < 1 => 'Thời hạn thuê phải lớn hơn 0 ngày.',
                        _ when duration < widget.minRentalDays =>
                          'Thời hạn thuê tối thiểu là ${widget.minRentalDays} ngày.',
                        _ => null,
                      };
                      _submitError = null;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    CheckboxListTile(
                      value: _termsAccepted,
                      onChanged: _submitting
                          ? null
                          : (accepted) => setState(() {
                              _termsAccepted = accepted == true;
                              _submitError = null;
                              _submitErrorStatus = null;
                            }),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'Tôi đã đọc và đồng ý với các điều khoản đặt kho và chính sách hủy đặt kho.',
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _showReservationTerms,
                        icon: const Icon(Icons.info_outline),
                        label: const Text('Xem điều khoản và chính sách hủy'),
                      ),
                    ),
                  ],
                ),
              ),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _submitError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      if (_submissionOutcomeUnknown)
                        TextButton(
                          onPressed: () => setState(() {
                            _submissionOutcomeUnknown = false;
                            _submitError = null;
                            _submitErrorStatus = null;
                          }),
                          child: const Text(
                            'Tôi đã kiểm tra Đơn đặt kho, cho phép thử lại',
                          ),
                        )
                      else if (_submitErrorStatus == 409)
                        TextButton.icon(
                          onPressed: _loading ? null : _loadAvailability,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tải lại tình trạng kho'),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (_hasValidUnit || _hasValidDate || _hasValidSlot)
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tóm tắt lựa chọn',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        if (_hasValidDate)
                          Text(
                            'Ngày nhận: ${MaterialLocalizations.of(context).formatMediumDate(_date!.toLocal())}',
                          ),
                        if (_hasValidSlot) Text('Khung giờ: $_slotId'),
                        if (_hasValidUnit)
                          Text('Kho: ${_unit!['unitNumber'] ?? _unit!['id']}'),
                        if (_hasValidDuration)
                          Text('Thời hạn: $_duration ngày'),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
  Future<void> _submit() async {
    if (!_canSubmit) return;
    final unitId = '${_unit!['id']}';
    final slot = _selectableSlots.firstWhere((s) => s.slotName == _slotId);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final reservation = await widget.repository.create(
        facilityId: widget.facilityId,
        storageUnitId: unitId,
        facilityUnitTypeOfferingId: widget.offeringId,
        checkInDate: _date!,
        checkInTimeSlot: slot.slotName,
        rentalDuration: _duration,
        termsAccepted: _termsAccepted,
        amenities: _selectedAmenities.entries
            .map(
              (entry) => {
                'facilityAmenityOfferingId': entry.key,
                'quantity': entry.value,
              },
            )
            .toList(),
      );
      if (mounted) widget.onCreated(reservation);
    } catch (e) {
      if (mounted) {
        final failure = _reservationError(e);
        setState(() {
          _submitError = failure.message;
          _submitErrorStatus = failure.statusCode;
          _submissionOutcomeUnknown = failure.outcomeUnknown;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _amenitySelector() => FutureBuilder<List<FacilityAmenityOffering>>(
    future: _amenityFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Expanded(child: Text('Đang tải tiện ích…')),
              ],
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('Không tải được tiện ích'),
            trailing: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(
                () => _amenityFuture = widget.amenityRepository!.availableAt(
                  widget.facilityId,
                ),
              ),
            ),
          ),
        );
      }
      final offerings = snapshot.data ?? const <FacilityAmenityOffering>[];
      if (offerings.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(
            title: 'Tiện ích tùy chọn',
            subtitle: 'Giá và tình trạng do cơ sở cung cấp',
          ),
          const SizedBox(height: 8),
          ...offerings.map((item) {
            final quantity = _selectedAmenities[item.id];
            final available = item.isAvailable;
            return Card(
              color: available
                  ? null
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  CheckboxListTile(
                    value: quantity != null,
                    onChanged: !available || _submitting
                        ? null
                        : (checked) => setState(() {
                            if (checked == true) {
                              _selectedAmenities[item.id] = 1;
                            } else {
                              _selectedAmenities.remove(item.id);
                            }
                          }),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        color: available
                            ? null
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.description?.trim().isNotEmpty == true)
                          Text(item.description!),
                        Text(
                          '${NumberFormat('#,##0', 'vi_VN').format(item.pricePerUnit)} ₫ / ${_amenityBillingUnit(item.billingUnit)}',
                        ),
                        if (item.notes?.trim().isNotEmpty == true)
                          Text(item.notes!),
                        if (available && item.availableQuantity != null)
                          Text('Còn ${item.availableQuantity}'),
                        if (!available) const Text('Hiện không khả dụng'),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  if (quantity != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          const Text('Số lượng'),
                          const Spacer(),
                          IconButton(
                            onPressed: _submitting || quantity <= 1
                                ? null
                                : () => setState(
                                    () => _selectedAmenities[item.id] =
                                        quantity - 1,
                                  ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$quantity'),
                          IconButton(
                            onPressed:
                                _submitting ||
                                    (item.availableQuantity != null &&
                                        quantity >= item.availableQuantity!)
                                ? null
                                : () => setState(
                                    () => _selectedAmenities[item.id] =
                                        quantity + 1,
                                  ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Giá tiện ích là đơn giá máy chủ cung cấp; tổng tiền và thời điểm thu do Backend xác định.',
            ),
          ),
        ],
      );
    },
  );

  String _amenityBillingUnit(String value) => switch (value) {
    'day' => 'ngày',
    'week' => 'tuần',
    'month' => 'tháng',
    'year' => 'năm',
    'one_time' => 'một lần',
    _ => 'đơn vị',
  };

  Future<void> _showReservationTerms() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Điều khoản đặt kho và chính sách hủy'),
      content: const Text(
        'Nội dung điều khoản đặt kho và chính sách hủy chính thức chưa được cung cấp trong ứng dụng. Vui lòng yêu cầu cơ sở cung cấp nội dung áp dụng trước khi xác nhận. Ứng dụng không tự tạo hoặc diễn giải nội dung pháp lý.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  ({String message, int? statusCode, bool outcomeUnknown}) _reservationError(
    Object error,
  ) {
    final dioError = error is DioException ? error : null;
    final apiError = error is ApiError
        ? error
        : dioError?.error is ApiError
        ? dioError!.error! as ApiError
        : null;
    final status = dioError?.response?.statusCode ?? apiError?.statusCode;
    final body = dioError?.response?.data;
    final serverText =
        _safeBackendMessage(body) ?? _safeText(apiError?.message);
    final code = _safeMessageCode(body) ?? _safeText(apiError?.code);

    final codeMessage = _reservationMessageForCode(code);
    if (codeMessage != null) {
      final details = _validationDetails(body);
      return (
        message:
            '$codeMessage${details == null ? '' : '\n$details'}${serverText == null ? '' : '\n$serverText'}${status == null ? '' : '\nHTTP $status'}${code == null ? '' : ' ($code)'}',
        statusCode: status,
        outcomeUnknown: false,
      );
    }

    if (status == 400) {
      final details = _validationDetails(body);
      return (
        message:
            'Thông tin đặt kho chưa hợp lệ${details == null ? '' : ': $details'}${serverText == null ? '' : '\n$serverText'}${status == null ? '' : '\nHTTP $status'}${code == null ? '' : ' ($code)'}',
        statusCode: status,
        outcomeUnknown: false,
      );
    }
    if (status == 401) {
      return (
        message:
            'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại. (HTTP 401)',
        statusCode: status,
        outcomeUnknown: false,
      );
    }
    if (status == 403) {
      return (
        message: 'Bạn không có quyền tạo đơn đặt kho này. (HTTP 403)',
        statusCode: status,
        outcomeUnknown: false,
      );
    }
    if (status == 404) {
      return (
        message: 'Kho, khung giờ hoặc loại kho không còn khả dụng. Vui lòng tải lại tình trạng kho. (HTTP 404)',
        statusCode: status,
        outcomeUnknown: false,
      );
    }
    if (status == 409) {
      return (
        message:
            'Kho hoặc khung giờ vừa được đặt. Hãy tải lại tình trạng kho và chọn lại. (HTTP 409)${serverText == null ? '' : ' $serverText'}${code == null ? '' : ' ($code)'}',
        statusCode: status,
        outcomeUnknown: false,
      );
    }
    final timedOut =
        dioError != null &&
        (dioError.type == DioExceptionType.connectionTimeout ||
            dioError.type == DioExceptionType.receiveTimeout ||
            dioError.type == DioExceptionType.sendTimeout);
    if (timedOut) {
      return (
        message: 'Không nhận được phản hồi đúng hạn; chưa xác định máy chủ đã tạo đơn hay chưa. Vui lòng kiểm tra mục Đơn đặt kho trước khi cho phép thử lại.',
        statusCode: status,
        outcomeUnknown: true,
      );
    }
    if (dioError?.response == null) {
      return (
        message: 'Không thể kết nối đến máy chủ. Nếu yêu cầu đã được gửi, kết quả có thể chưa xác định; hãy kiểm tra mục Đơn đặt kho trước khi thử lại.',
        statusCode: status,
        outcomeUnknown: true,
      );
    }
    return (
      message:
          'Không thể tạo đơn đặt kho${status == null ? '' : ' (HTTP $status)'}.${serverText == null ? '' : ' $serverText'}${code == null ? '' : ' ($code)'}',
      statusCode: status,
      outcomeUnknown: false,
    );
  }

  String? _reservationMessageForCode(String? code) => switch (code) {
    'MESSAGE_CODE_322' =>
      'Bạn cần đồng ý với điều khoản đặt kho trước khi tiếp tục.',
    'MESSAGE_CODE_328' => 'Khung giờ nhận kho cần đủ thời gian chuẩn bị trước giờ hẹn. Vui lòng chọn ngày hoặc khung giờ khác.',
    'MESSAGE_CODE_315' =>
      'Khung giờ nhận kho đã qua. Vui lòng chọn khung giờ khác.',
    'MESSAGE_CODE_310' =>
      'Khung giờ này đã đạt sức chứa tối đa. Vui lòng chọn khung giờ khác.',
    'MESSAGE_CODE_311' => 'Khung giờ nhận kho không hợp lệ hoặc không còn hoạt động. Vui lòng tải lại khung giờ.',
    'MESSAGE_CODE_309' => 'Kho vừa được khách hàng khác đặt. Vui lòng tải lại tình trạng kho và chọn phòng khác.',
    'MESSAGE_CODE_306' => 'Phòng kho đã chọn không thuộc loại kho này. Vui lòng chọn lại phòng phù hợp.',
    'MESSAGE_CODE_313' => 'Ngày nhận kho vượt quá thời hạn đặt trước cho phép.',
    'MESSAGE_CODE_314' => 'Bạn đã đạt giới hạn số đơn đặt kho đang hoạt động. Vui lòng kiểm tra các đơn hiện có.',
    _ => null,
  };

  String? _safeBackendMessage(Object? body) {
    if (body is! Map) return null;
    return _safeText(body['message'] ?? body['error']);
  }

  String? _safeMessageCode(Object? body) =>
      body is Map ? _safeText(body['messageCode']) : null;

  String? _safeText(Object? value) {
    if (value == null) return null;
    final safe = value
        .toString()
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false),
          'Bearer [ẩn]',
        )
        .replaceAll(
          RegExp(
            r'(access[_-]?token|refresh[_-]?token|password|authorization|cookie)\s*[:=]\s*[^,;\s]+',
            caseSensitive: false,
          ),
          '[thông tin nhạy cảm đã ẩn]',
        )
        .trim();
    if (safe.isEmpty || safe.length > 240) return null;
    return safe;
  }

  String? _validationDetails(Object? body) {
    if (body is! Map) return null;
    final details =
        body['errors'] ?? body['details'] ?? body['validationErrors'];
    if (details is List) {
      final messages = details
          .map((item) {
            if (item is Map) {
              final field = _safeText(item['field'] ?? item['path']);
              final message = _safeText(item['message'] ?? item['msg']);
              if (field != null && message != null) return '$field: $message';
              return message ?? field;
            }
            return _safeText(item);
          })
          .whereType<String>()
          .take(4)
          .toList();
      return messages.isEmpty ? null : messages.join('; ');
    }
    if (details is Map) {
      final messages = details.entries
          .take(4)
          .map((entry) {
            final key = _safeText(entry.key);
            final value = entry.value is List
                ? (entry.value as List)
                      .map(_safeText)
                      .whereType<String>()
                      .join(', ')
                : _safeText(entry.value);
            if (key != null && value != null) return '$key: $value';
            return value ?? key;
          })
          .whereType<String>()
          .toList();
      return messages.isEmpty ? null : messages.join('; ');
    }
    return null;
  }
}

class _ReservationProgress extends StatelessWidget {
  const _ReservationProgress({required this.currentStep});
  final int currentStep;

  static const _labels = ['Cơ sở', 'Kho & giờ', 'Thời hạn', 'Xác nhận'];

  @override
  Widget build(BuildContext context) {
    final active = Theme.of(context).colorScheme.primary;
    final inactive = Theme.of(context).colorScheme.outlineVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i <= currentStep ? active : inactive,
                          ),
                        ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: i <= currentStep
                              ? active
                              : Theme.of(context).colorScheme.surface,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: i <= currentStep ? active : inactive,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: i < currentStep
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : Text(
                                '${i + 1}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: i <= currentStep
                                          ? Colors.white
                                          : inactive,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                      ),
                      if (i < _labels.length - 1)
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i < currentStep ? active : inactive,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    _labels[i],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: i <= currentStep
                          ? active
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: i == currentStep
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
