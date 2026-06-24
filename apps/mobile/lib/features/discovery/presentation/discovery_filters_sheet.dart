import 'package:flutter/material.dart';
import '../data/discovery_repository.dart';

Future<DiscoveryFilters?> showDiscoveryFiltersSheet(
  BuildContext context,
  DiscoveryFilters current,
) {
  var minAge = current.minAge.clamp(18, 99).toDouble();
  var maxAge = current.maxAge.clamp(18, 99).toDouble();
  if (maxAge < minAge) maxAge = minAge;
  var distance = current.maxDistanceKm.clamp(1, 500).toDouble();
  final genders = Set<String>.from(current.genders);

  return showModalBottomSheet<DiscoveryFilters>(
    context: context,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Search filters',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Text('Gender', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'].map((gender) {
                final selected = genders.contains(gender);
                return FilterChip(
                  label: Text(gender.replaceAll('_', ' ')),
                  selected: selected,
                  onSelected: (value) => setState(() {
                    if (value) {
                      genders.add(gender);
                    } else if (genders.length > 1) {
                      genders.remove(gender);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Text('Age ${minAge.round()}–${maxAge.round()}'),
            RangeSlider(
              values: RangeValues(minAge, maxAge),
              min: 18,
              max: 99,
              divisions: 81,
              onChanged: (value) => setState(() {
                minAge = value.start;
                maxAge = value.end;
              }),
            ),
            Text('Distance ${distance.round()} km'),
            Slider(
              value: distance,
              min: 1,
              max: 500,
              divisions: 499,
              label: '${distance.round()} km',
              onChanged: (value) => setState(() => distance = value),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                DiscoveryFilters(
                  minAge: minAge.round(),
                  maxAge: maxAge.round(),
                  maxDistanceKm: distance.round(),
                  genders: genders.toList(),
                ),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      ),
    ),
  );
}
