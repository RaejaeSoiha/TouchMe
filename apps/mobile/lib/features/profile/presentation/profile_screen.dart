import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/layout/responsive.dart';
import '../data/photo_repository.dart';
import '../data/profile_repository.dart';
import '../domain/user_profile.dart';
import '../../discovery/presentation/discovery_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({this.editing = false, super.key});
  final bool editing;
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final name = TextEditingController();
  final bio = TextEditingController();
  final city = TextEditingController();
  bool seeded = false;
  String gender = 'NON_BINARY';
  final showMe = <String>{'WOMAN', 'MAN', 'NON_BINARY'};
  final selectedInterests = <String>{};
  double minAge = 18;
  double maxAge = 55;
  double distance = 50;
  DateTime birthDate = DateTime(1995, 6, 15);
  bool saving = false;
  bool uploading = false;

  @override
  void dispose() {
    name.dispose();
    bio.dispose();
    city.dispose();
    super.dispose();
  }

  void seed(UserProfile? profile) {
    if (seeded || profile == null) return;
    seeded = true;
    name.text = profile.displayName;
    bio.text = profile.bio ?? '';
    city.text = profile.city ?? '';
    gender = profile.gender;
    showMe
      ..clear()
      ..addAll(profile.showMe);
    selectedInterests
      ..clear()
      ..addAll(profile.interestIds);
    minAge = profile.minAge.toDouble();
    maxAge = profile.maxAge.toDouble();
    distance = profile.maxDistanceKm.toDouble();
    birthDate = profile.birthDate;
  }

  Future<void> pickPhoto(int position) async {
    final existing = ref.read(myProfileProvider).asData?.value;
    if (existing == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save your profile first, then add photos.'),
          ),
        );
      }
      return;
    }
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await ref.read(photoRepositoryProvider).uploadProfilePhotoBytes(
        bytes,
        PhotoRepository.contentTypeForFilename(picked.name),
        position,
      );
      ref.invalidate(myProfileProvider);
      setState(() => seeded = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded!')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error.toString().contains('401')
            ? 'Session expired. Sign out and sign in again.'
            : 'Photo upload failed: $error';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate,
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
    );
    if (picked != null) setState(() => birthDate = picked);
  }

  String _interestLabel(Map<String, Object?> item) =>
      (item['label'] ?? item['name'] ?? 'Interest') as String;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final interests = ref.watch(interestsProvider);
    final isEditing = widget.editing || profile.asData?.value == null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Set up your profile' : 'My profile'),
        actions: [
          if (!isEditing)
            IconButton(
              onPressed: () => context.go('/profile/edit'),
              icon: const Icon(Icons.edit),
            ),
        ],
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load profile: $error')),
        data: (data) {
          seed(data);
          if (!isEditing && data != null) {
            return ResponsiveBody(
              child: ListView(
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundImage: data.photos.isEmpty
                        ? null
                        : NetworkImage(data.photos.first.url),
                    child: data.photos.isEmpty
                        ? Text(
                            data.displayName.characters.first.toUpperCase(),
                            style: const TextStyle(fontSize: 42),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  data.displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (data.bio != null && data.bio!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(data.bio!, textAlign: TextAlign.center),
                  ),
                ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: Text('Born ${data.birthDate.toLocal().toString().split(' ').first}'),
                ),
                ListTile(
                  leading: const Icon(Icons.location_city),
                  title: Text(data.city ?? 'Add your city'),
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: Text(
                    '${data.minAge}–${data.maxAge} years · ${data.maxDistanceKm} km',
                  ),
                ),
                if (data.photos.length > 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          data.photos[index].url,
                          width: 80,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            );
          }

          return ResponsiveBody(
            child: ListView(
            children: [
              if (data == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Welcome to TouchMe! Add your details so people nearby can find you.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              if (data != null && data.photos.isNotEmpty)
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.photos.length + (data.photos.length < 9 ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index >= data.photos.length) {
                        return OutlinedButton(
                          onPressed: uploading ? null : () => pickPhoto(index),
                          child: const Icon(Icons.add),
                        );
                      }
                      final photo = data.photos[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photo.url,
                              width: 80,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () async {
                                await ref
                                    .read(photoRepositoryProvider)
                                    .deletePhoto(photo.id);
                                ref.invalidate(myProfileProvider);
                                setState(() => seeded = false);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: uploading ? null : () => pickPhoto(0),
                  icon: const Icon(Icons.add_a_photo),
                  label: Text(uploading ? 'Uploading…' : 'Add a photo'),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'Required — e.g. Alex',
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Birthday'),
                subtitle: Text(birthDate.toLocal().toString().split(' ').first),
                trailing: TextButton(
                  onPressed: pickBirthDate,
                  child: const Text('Change'),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: bio,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Bio'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: city,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER']
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text(value.replaceAll('_', ' ')),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => gender = value);
                },
              ),
              const SizedBox(height: 20),
              Text('Looking for', style: Theme.of(context).textTheme.titleMedium),
              Wrap(
                spacing: 8,
                children: ['WOMAN', 'MAN', 'NON_BINARY', 'OTHER']
                    .map(
                      (value) => FilterChip(
                        label: Text(value.replaceAll('_', ' ')),
                        selected: showMe.contains(value),
                        onSelected: (selected) => setState(
                          () => selected ? showMe.add(value) : showMe.remove(value),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              Text('Interests', style: Theme.of(context).textTheme.titleMedium),
              interests.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
                error: (_, _) => const Text('Could not load interests'),
                data: (items) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items
                      .map(
                        (item) => FilterChip(
                          label: Text(_interestLabel(item)),
                          selected: selectedInterests.contains(item['id'] as String?),
                          onSelected: (selected) {
                            final id = item['id'] as String?;
                            if (id == null) return;
                            setState(
                              () => selected
                                  ? selectedInterests.add(id)
                                  : selectedInterests.remove(id),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text('Age range ${minAge.round()}–${maxAge.round()}'),
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
              Text('Maximum distance ${distance.round()} km'),
              Slider(
                value: distance,
                min: 1,
                max: 200,
                divisions: 199,
                onChanged: (value) => setState(() => distance = value),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final displayName = name.text.trim();
                        if (displayName.length < 2) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a display name (at least 2 characters).'),
                            ),
                          );
                          return;
                        }
                        if (showMe.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Select at least one gender preference.')),
                          );
                          return;
                        }
                        setState(() => saving = true);
                        try {
                          await ref.read(profileRepositoryProvider).save(
                            UserProfile(
                              displayName: displayName,
                              birthDate: birthDate,
                              gender: gender,
                              showMe: showMe.toList(),
                              bio: bio.text.trim().isEmpty ? null : bio.text.trim(),
                              city: city.text.trim().isEmpty ? null : city.text.trim(),
                              minAge: minAge.round(),
                              maxAge: maxAge.round(),
                              maxDistanceKm: distance.round(),
                              discoverable: data?.discoverable ?? true,
                              photos: data?.photos ?? [],
                              interestIds: selectedInterests.toList(),
                            ),
                          );
                          ref.invalidate(myProfileProvider);
                          ref.invalidate(discoveryControllerProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Profile saved!')),
                            );
                            context.go('/profile');
                          }
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not save profile: $error')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => saving = false);
                        }
                      },
                child: Text(saving ? 'Saving…' : 'Save profile'),
              ),
            ],
          ),
          );
        },
      ),
    );
  }
}
