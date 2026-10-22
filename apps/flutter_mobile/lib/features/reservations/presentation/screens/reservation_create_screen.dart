import 'package:flutter/material.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';

class ReservationCreateScreen extends StatefulWidget {
  const ReservationCreateScreen({
    super.key,
    required this.facilityId,
    required this.offeringId,
    required this.unitTypeId,
    required this.minRentalDays,
    required this.repository,
    required this.onCreated,
  });
  final String facilityId, offeringId, unitTypeId;
  final int minRentalDays;
  final ReservationRepository repository;
  final ValueChanged<Reservation> onCreated;
  @override
  State<ReservationCreateScreen> createState() =>
      _ReservationCreateScreenState();
}

class _ReservationCreateScreenState extends State<ReservationCreateScreen> {
  DateTime? _date;
  String? _slotId;
  Map<String, dynamic>? _unit;
  List<Map<String, dynamic>> _units = [];
  List<AvailableTimeSlot> _slots = [];
  late int _duration = widget.minRentalDays;
  bool _loading = false;
  String? _error;
  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _date ?? DateTime(now.year, now.month, now.day + 1),
    );
    if (value == null) return;
    setState(() => _date = value);
    await _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final date = _date;
    if (date == null) return;
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        widget.repository.getAvailability(widget.facilityId, date),
        widget.repository.getAvailableUnits(
          widget.facilityId,
          unitTypeId: widget.unitTypeId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _slots = values[0] as List<AvailableTimeSlot>;
        _units = values[1] as List<Map<String, dynamic>>;
        _slotId = null;
        _unit = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Availability could not be loaded. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reserve a storage unit')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Check-in date'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _chooseDate,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            _date == null
                ? 'Choose a date'
                : MaterialLocalizations.of(context).formatMediumDate(_date!),
          ),
        ),
        if (_date != null) ...[
          const SizedBox(height: 16),
          const Text('Available check-in time'),
          const SizedBox(height: 8),
          if (_loading) const Center(child: CircularProgressIndicator()),
          RadioGroup<String>(
            groupValue: _slotId,
            onChanged: (value) => setState(() => _slotId = value),
            child: Column(
              children: _slots
                  .where((s) => s.isAvailable && s.availableCapacity > 0)
                  .map(
                    (s) => RadioListTile<String>(
                      value: s.slotName,
                      title: Text(s.slotName),
                      subtitle: Text(
                        '${s.startTime}–${s.endTime} · ${s.availableCapacity} spaces',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_slots
                  .where((s) => s.isAvailable && s.availableCapacity > 0)
                  .isEmpty &&
              !_loading)
            const Text('No time slots are available on this date.'),
          const SizedBox(height: 12),
          const Text('Available physical unit'),
          DropdownButtonFormField<Map<String, dynamic>>(
            initialValue: _unit,
            decoration: const InputDecoration(labelText: 'Select storage unit'),
            items: _units
                .map(
                  (u) => DropdownMenuItem(
                    value: u,
                    child: Text(
                      '${u['unitNumber'] ?? 'Unit'} · Floor ${u['floor'] ?? '—'}',
                    ),
                  ),
                )
                .toList(),
            onChanged: (u) => setState(() => _unit = u),
          ),
          const SizedBox(height: 16),
          TextFormField(
            initialValue: '${widget.minRentalDays}',
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Rental duration (minimum ${widget.minRentalDays})',
            ),
            onChanged: (v) => _duration = int.tryParse(v) ?? 0,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _loading ||
                    _slotId == null ||
                    _unit == null ||
                    _duration < widget.minRentalDays
                ? null
                : _submit,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create reservation'),
          ),
        ],
      ],
    ),
  );
  Future<void> _submit() async {
    final unitId = '${_unit?['id'] ?? ''}';
    final slot = _slots.firstWhere((s) => s.slotName == _slotId);
    setState(() => _loading = true);
    try {
      final reservation = await widget.repository.create(
        facilityId: widget.facilityId,
        storageUnitId: unitId,
        facilityUnitTypeOfferingId: widget.offeringId,
        checkInDate: _date!,
        checkInTimeSlot: slot.slotName,
        rentalDuration: _duration,
      );
      if (mounted) widget.onCreated(reservation);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              e.toString().contains('409') || e.toString().contains('conflict')
              ? 'That unit or time slot was just taken. Refresh availability and choose again.'
              : 'Reservation could not be created. Please review your selection and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
