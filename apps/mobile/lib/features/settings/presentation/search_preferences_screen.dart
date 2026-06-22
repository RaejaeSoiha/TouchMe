import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/layout/responsive.dart';
import '../../discovery/presentation/discovery_controller.dart';
import '../../profile/domain/user_profile.dart';
import '../../profile/data/profile_repository.dart';

class SearchPreferencesScreen extends ConsumerStatefulWidget {
  const SearchPreferencesScreen({super.key});

  @override
  ConsumerState<SearchPreferencesScreen> createState() =>
      _SearchPreferencesScreenState();
}

class _SearchPreferencesScreenState extends ConsumerState<SearchPreferencesScreen> {
  final genders = <String>{'WOMAN', 'MAN', 'NON_BINARY'};
  double minAge = 18;
  double maxAge = 55;
  double distance = 50;
  bool seeded = false;
  bool saving = false;

  void _seed(UserProfile? profile) {
    if (seeded || profile == null) return;
    seeded = true;
    genders
      ..clear()
      ..addAll(profile.showMe);
    minAge = profile.minAge.toDouble();
    maxAge = profile.maxAge.toDouble();
    distance = profile.maxDistanceKm.toDouble();
  }

  Future<void> _save() async {
    if (genders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one gender to search for.')),
      );
      return;
    }
    final profile = ref.read(myProfileProvider).asData?.value;
    if (profile == null) {
      if (mounted) context.go('/profile/edit');
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(profileRepositoryProvider).save(
        profile.copyWith(
          showMe: genders.toList(),
          minAge: minAge.round(),
          maxAge: maxAge.round(),
          maxDistanceKm: distance.round(),
        ),
      );
      ref.invalidate(myProfileProvider);
      ref.invalidate(discoveryControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Search preferences saved')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search preferences', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (data) {
          _seed(data);
          if (data == null) {
            return ResponsiveBody(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Set up your profile first.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.go('/profile/edit'),
                    child: const Text('Set up profile'),
                  ),
                ],
              ),
            );
          }
          return ResponsiveBody(
            child: ListView(
              children: [
                const Text(
                  'These are your default filters for the Nearby tab. You can still adjust filters temporarily from Nearby.',
                ),
                const SizedBox(height: 24),
                Text('Looking for', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER'].map((gender) {
                    return FilterChip(
                      label: Text(gender.replaceAll('_', ' ')),
                      selected: genders.contains(gender),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          genders.add(gender);
                        } else if (genders.length > 1) {
                          genders.remove(gender);
                        }
                      }),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Text('Age ${minAge.round()}–${maxAge.round()}'),
                RangeSlider(
                  values: RangeValues(minAge, maxAge),
                  min: 18,
                  max: 80,
                  divisions: 62,
                  onChanged: (value) => setState(() {
                    minAge = value.start;
                    maxAge = value.end;
                  }),
                ),
                Text('Distance ${distance.round()} km'),
                Slider(
                  value: distance,
                  min: 1,
                  max: 200,
                  divisions: 199,
                  label: '${distance.round()} km',
                  onChanged: (value) => setState(() => distance = value),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: saving ? null : _save,
                  child: Text(saving ? 'Saving…' : 'Save preferences'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
