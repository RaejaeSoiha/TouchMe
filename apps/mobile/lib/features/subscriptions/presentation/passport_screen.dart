import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/layout/responsive.dart';
import '../../profile/data/profile_repository.dart';

class PassportScreen extends ConsumerStatefulWidget {
  const PassportScreen({super.key});

  @override
  ConsumerState<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends ConsumerState<PassportScreen> {
  final city = TextEditingController();
  double? latitude;
  double? longitude;
  bool saving = false;

  @override
  void dispose() {
    city.dispose();
    super.dispose();
  }

  Future<void> useCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get your location. Try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore another city', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ResponsiveBody(
        child: ListView(
        children: [
          const Text(
            'Appear on the nearby list in another city. TouchMe Plus subscribers can explore anywhere in the world.',
          ),
          const SizedBox(height: 24),
          TextField(
            controller: city,
            decoration: const InputDecoration(
              labelText: 'City name (display only)',
              hintText: 'Paris, Tokyo, New York…',
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Use GPS coordinates'),
          ),
          if (latitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Selected: ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}'),
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: saving || latitude == null
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      await ref.read(profileRepositoryProvider).passport(
                        latitude!,
                        longitude!,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Explore location updated')),
                        );
                        Navigator.pop(context);
                      }
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update location. Try again.'),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
            child: Text(saving ? 'Saving…' : 'Update location'),
          ),
        ],
      ),
      ),
    );
  }
}
