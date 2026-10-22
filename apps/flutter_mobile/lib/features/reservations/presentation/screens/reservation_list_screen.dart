import 'package:flutter/material.dart';

import '../../data/models/reservation.dart';
import '../../data/repositories/reservation_repository.dart';

class ReservationListScreen extends StatefulWidget {
  const ReservationListScreen({
    super.key,
    required this.repository,
    required this.onSelect,
  });
  final ReservationRepository repository;
  final ValueChanged<Reservation> onSelect;
  @override
  State<ReservationListScreen> createState() => _ReservationListScreenState();
}

class _ReservationListScreenState extends State<ReservationListScreen> {
  late Future<List<Reservation>> _reservations;
  @override
  void initState() {
    super.initState();
    _reservations = widget.repository.list();
  }

  void _reload() => setState(() => _reservations = widget.repository.list());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My reservations')),
    body: FutureBuilder<List<Reservation>>(
      future: _reservations,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            message: 'Could not load reservations. Check your connection and try again.',
            onRetry: _reload,
          );
        }
        final items = snapshot.data ?? const [];
        if (items.isEmpty) {
          return const Center(child: Text('No reservations yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                child: ListTile(
                  title: Text(
                    item.reservationCode,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${item.status} · Check-in ${MaterialLocalizations.of(context).formatMediumDate(item.checkInDate.toLocal())} · ${item.checkInTimeSlot}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => widget.onSelect(item),
                ),
              );
            },
          ),
        );
      },
    ),
  );
}

class _MessageState extends StatelessWidget {
  const _MessageState({required this.message, required this.onRetry});
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
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
