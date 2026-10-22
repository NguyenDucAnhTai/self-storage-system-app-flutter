import 'package:flutter/material.dart';

import '../../data/models/facility.dart';
import '../../data/repositories/facility_repository.dart';

class FacilityDetailScreen extends StatefulWidget {
  const FacilityDetailScreen({
    super.key,
    required this.facilityId,
    required this.repository,
    required this.onBook,
  });
  final String facilityId;
  final FacilityRepository repository;
  final ValueChanged<({Facility facility, FacilityOffering offering})> onBook;
  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  late Future<FacilityDetail> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.getDetail(widget.facilityId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Facility details')),
    body: FutureBuilder<FacilityDetail>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return Center(
            child: TextButton(
              onPressed: () => setState(
                () => _future = widget.repository.getDetail(widget.facilityId),
              ),
              child: const Text('Could not load. Try again'),
            ),
          );
        }
        final d = s.data!;
        final f = d.facility;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (f.images.isNotEmpty)
              SizedBox(
                height: 210,
                child: PageView(
                  children: f.images
                      .map(
                        (u) => Image.network(
                          u,
                          fit: BoxFit.cover,
                          errorBuilder: (_, e, st) =>
                              const Icon(Icons.warehouse, size: 80),
                        ),
                      )
                      .toList(),
                ),
              ),
            const SizedBox(height: 12),
            Text(f.name, style: Theme.of(context).textTheme.headlineSmall),
            Text('${f.city} · ${f.address}'),
            if (f.description?.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(f.description!),
              ),
            if (f.phone != null) Text('Phone: ${f.phone}'),
            const SizedBox(height: 22),
            Text(
              'Available unit types',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (d.offerings.isEmpty)
              const Text('No available unit types currently.'),
            ...d.offerings.map(
              (o) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${o.area?.toStringAsFixed(1) ?? '—'} m² · ${o.availableUnitsCount} available',
                      ),
                      if (o.dimensions != null)
                        Text(
                          '${o.dimensions!['length']} × ${o.dimensions!['width']} × ${o.dimensions!['height']} m',
                        ),
                      Text(
                        '${o.pricePerUnit.toStringAsFixed(0)} VND / ${o.billingUnit} · deposit × ${o.depositMultiplier}',
                      ),
                      Text('Minimum rental: ${o.minRentalDays} days'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: o.availableUnitsCount > 0
                            ? () => widget.onBook((facility: f, offering: o))
                            : null,
                        child: const Text('Choose this unit type'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
