import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/layout/responsive.dart';
import '../../profile/data/photo_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/posts_repository.dart';

enum _ComposerMediaType { photo, video }

enum _ComposerVisibility { friendsOnly, onlyMe }

String _visibilityApiValue(_ComposerVisibility visibility) => switch (visibility) {
  _ComposerVisibility.friendsOnly => 'FRIENDS_ONLY',
  _ComposerVisibility.onlyMe => 'ONLY_ME',
};

bool _isFriendsOnlyVisibility(String visibility) => visibility == 'FRIENDS_ONLY';

String _visibilityLabel(String visibility) => _isFriendsOnlyVisibility(visibility)
    ? 'Friends only'
    : 'Only me';

String _mediaTypeForComposer(_ComposerMediaType type) => switch (type) {
  _ComposerMediaType.photo => 'image',
  _ComposerMediaType.video => 'video',
};

String _contentTypeForPickedMedia(XFile file, _ComposerMediaType type) {
  if (type == _ComposerMediaType.photo) {
    return PhotoRepository.contentTypeForFilename(file.name);
  }
  final lower = file.name.toLowerCase();
  if (lower.endsWith('.webm')) return 'video/webm';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  return 'video/mp4';
}

bool _isVideoMediaType(String? mediaType) {
  final value = mediaType?.toLowerCase() ?? '';
  return value.contains('video');
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final body = TextEditingController();
  XFile? pickedMedia;
  Uint8List? pickedMediaBytes;
  _ComposerMediaType? pickedMediaType;
  _ComposerVisibility visibility = _ComposerVisibility.friendsOnly;
  bool allowComments = true;
  bool loadingMedia = false;
  bool publishing = false;

  @override
  void dispose() {
    body.dispose();
    super.dispose();
  }

  Future<void> refreshFeed() async {
    ref.invalidate(homePostsProvider);
    await ref.read(homePostsProvider.future);
  }

  Future<void> pickPhoto() => _pickMedia(
    mediaType: _ComposerMediaType.photo,
    picker: () =>
        ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85),
  );

  Future<void> pickVideo() => _pickMedia(
    mediaType: _ComposerMediaType.video,
    picker: () => ImagePicker().pickVideo(source: ImageSource.gallery),
  );

  Future<void> _pickMedia({
    required _ComposerMediaType mediaType,
    required Future<XFile?> Function() picker,
  }) async {
    final picked = await picker();
    if (picked == null) return;
    setState(() => loadingMedia = true);
    try {
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        pickedMedia = picked;
        pickedMediaBytes = bytes;
        pickedMediaType = mediaType;
      });
    } finally {
      if (mounted) setState(() => loadingMedia = false);
    }
  }

  Future<void> publish() async {
    final text = body.text.trim();
    if (text.isEmpty && pickedMediaBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add text, a photo, or a video first.')),
      );
      return;
    }

    setState(() => publishing = true);
    try {
      final repo = ref.read(postsRepositoryProvider);
      String? mediaUrl;
      String? mediaType;
      if (pickedMedia != null && pickedMediaBytes != null && pickedMediaType != null) {
        mediaUrl = await repo.uploadMedia(
          pickedMediaBytes!,
          _contentTypeForPickedMedia(pickedMedia!, pickedMediaType!),
        );
        mediaType = _mediaTypeForComposer(pickedMediaType!);
      }
      await repo.create(
        body: text,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        visibility: _visibilityApiValue(visibility),
        allowComments: allowComments,
      );
      if (!mounted) return;
      body.clear();
      setState(() {
        pickedMedia = null;
        pickedMediaBytes = null;
        pickedMediaType = null;
        visibility = _ComposerVisibility.friendsOnly;
        allowComments = true;
      });
      ref.invalidate(homePostsProvider);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not publish post: $error')),
      );
    } finally {
      if (mounted) setState(() => publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider);
    final posts = ref.watch(homePostsProvider);
    final authorName = profile.maybeWhen(
      data: (data) => data?.displayName ?? 'You',
      orElse: () => 'You',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Home',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: refreshFeed,
        child: ResponsiveBody(
          padding: EdgeInsets.zero,
          child: ListView(
            padding: Responsive.pagePadding(context),
            children: [
              _ComposerCard(
                controller: body,
                loadingMedia: loadingMedia,
                publishing: publishing,
                pickedMedia: pickedMedia,
                pickedMediaBytes: pickedMediaBytes,
                pickedMediaType: pickedMediaType,
                visibility: visibility,
                allowComments: allowComments,
                onVisibilityChanged: (value) =>
                    setState(() => visibility = value),
                onAllowCommentsChanged: (value) =>
                    setState(() => allowComments = value),
                onPickPhoto: pickPhoto,
                onPickVideo: pickVideo,
                onClearMedia: () => setState(() {
                  pickedMedia = null;
                  pickedMediaBytes = null;
                  pickedMediaType = null;
                }),
                onPublish: publish,
              ),
              const SizedBox(height: 12),
              posts.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load posts: $error'),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No posts yet. Share what you are up to nearby.',
                      ),
                    );
                  }
                  return Column(
                    children: items
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PostCard(
                              post: post,
                              currentUserName: authorName,
                              onChanged: refreshFeed,
                            ),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.controller,
    required this.loadingMedia,
    required this.publishing,
    required this.onPickPhoto,
    required this.onPickVideo,
    required this.onClearMedia,
    required this.onPublish,
    this.pickedMedia,
    this.pickedMediaBytes,
    this.pickedMediaType,
    required this.visibility,
    required this.allowComments,
    required this.onVisibilityChanged,
    required this.onAllowCommentsChanged,
  });

  final TextEditingController controller;
  final bool loadingMedia;
  final bool publishing;
  final XFile? pickedMedia;
  final Uint8List? pickedMediaBytes;
  final _ComposerMediaType? pickedMediaType;
  final _ComposerVisibility visibility;
  final bool allowComments;
  final ValueChanged<_ComposerVisibility> onVisibilityChanged;
  final ValueChanged<bool> onAllowCommentsChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickVideo;
  final VoidCallback onClearMedia;
  final Future<void> Function() onPublish;

  @override
  Widget build(BuildContext context) {
    final busy = loadingMedia || publishing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Share an activity',
                hintText:
                    'Post what you are doing, planning, or looking for nearby.',
              ),
            ),
            if (pickedMediaBytes != null) ...[
              const SizedBox(height: 12),
              _LocalMediaPreview(
                bytes: pickedMediaBytes!,
                name: pickedMedia?.name ?? 'Selected media',
                type: pickedMediaType ?? _ComposerMediaType.photo,
                onClear: onClearMedia,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_ComposerVisibility>(
                    initialValue: visibility,
                    decoration: const InputDecoration(
                      labelText: 'Who can see this?',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: _ComposerVisibility.friendsOnly,
                        child: Text('Friends only'),
                      ),
                      DropdownMenuItem(
                        value: _ComposerVisibility.onlyMe,
                        child: Text('Only me'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onVisibilityChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Friend comments'),
                    subtitle: Text(allowComments ? 'Enabled' : 'Disabled'),
                    value: allowComments,
                    onChanged: onAllowCommentsChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onPickPhoto,
                  icon: const Icon(Icons.photo_outlined),
                  label: const Text('Photo'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onPickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Video'),
                ),
                FilledButton.icon(
                  onPressed: busy ? null : onPublish,
                  icon: publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    publishing
                        ? 'Posting…'
                        : loadingMedia
                        ? 'Loading…'
                        : 'Post',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends ConsumerStatefulWidget {
  const _PostCard({
    required this.post,
    required this.currentUserName,
    required this.onChanged,
  });

  final FeedPost post;
  final String currentUserName;
  final Future<void> Function() onChanged;

  @override
  ConsumerState<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<_PostCard> {
  final comment = TextEditingController();
  bool commenting = false;
  bool liking = false;
  bool submittingComment = false;

  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  FeedPost get post => widget.post;

  Future<void> sharePost() async {
    final summary = post.body.trim().isNotEmpty
        ? post.body
        : _isVideoMediaType(post.mediaType)
        ? 'Video post from ${post.authorName}'
        : post.mediaUrl != null
        ? 'Photo post from ${post.authorName}'
        : 'Post from ${post.authorName}';
    await Clipboard.setData(ClipboardData(text: summary));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post text copied for sharing.')),
    );
  }

  Future<void> toggleLike() async {
    if (liking) return;
    setState(() => liking = true);
    try {
      await ref.read(postsRepositoryProvider).toggleLike(post.id);
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update like: $error')),
      );
    } finally {
      if (mounted) setState(() => liking = false);
    }
  }

  Future<void> submitComment() async {
    final text = comment.text.trim();
    if (text.isEmpty || submittingComment) return;
    setState(() => submittingComment = true);
    try {
      await ref.read(postsRepositoryProvider).addComment(post.id, text);
      comment.clear();
      setState(() => commenting = false);
      await widget.onChanged();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add comment: $error')),
      );
    } finally {
      if (mounted) setState(() => submittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  child: Text(post.authorName.characters.first.toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: Icon(
                    _isFriendsOnlyVisibility(post.visibility)
                        ? Icons.people_outline
                        : Icons.lock_outline,
                    size: 16,
                  ),
                  label: Text(_visibilityLabel(post.visibility)),
                ),
                Chip(
                  avatar: Icon(
                    post.allowComments
                        ? Icons.chat_bubble_outline
                        : Icons.comments_disabled_outlined,
                    size: 16,
                  ),
                  label: Text(
                    post.allowComments ? 'Friends can comment' : 'Comments off',
                  ),
                ),
              ],
            ),
            if (post.body.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(post.body),
            ],
            if (post.mediaUrl != null) ...[
              const SizedBox(height: 12),
              _FeedMediaPreview(
                url: post.mediaUrl!,
                mediaType: post.mediaType,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: liking ? null : toggleLike,
                  icon: Icon(
                    post.likedByMe ? Icons.favorite : Icons.favorite_border,
                  ),
                  label: Text(
                    post.likeCount == 0 ? 'Like' : 'Like ${post.likeCount}',
                  ),
                ),
                TextButton.icon(
                  onPressed: post.allowComments
                      ? () => setState(() => commenting = !commenting)
                      : null,
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    post.comments.isEmpty
                        ? 'Comment'
                        : 'Comment ${post.comments.length}',
                  ),
                ),
                TextButton.icon(
                  onPressed: sharePost,
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Share'),
                ),
              ],
            ),
            if (post.comments.isNotEmpty) ...[
              const Divider(height: 24),
              ...post.comments.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          item.authorName.characters.first.toUpperCase(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.authorName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(item.body),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (commenting && post.allowComments) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: comment,
                      minLines: 1,
                      maxLines: 3,
                      enabled: !submittingComment,
                      decoration: const InputDecoration(
                        labelText: 'Write a comment',
                      ),
                      onSubmitted: (_) => submitComment(),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: submittingComment ? null : submitComment,
                    icon: submittingComment
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LocalMediaPreview extends StatelessWidget {
  const _LocalMediaPreview({
    required this.bytes,
    required this.name,
    required this.type,
    this.onClear,
  });

  final Uint8List bytes;
  final String name;
  final _ComposerMediaType type;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    if (type == _ComposerMediaType.photo) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              bytes,
              width: double.infinity,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          if (onClear != null)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          const Icon(Icons.movie_outlined),
          const SizedBox(width: 12),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (onClear != null)
            IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _FeedMediaPreview extends StatelessWidget {
  const _FeedMediaPreview({required this.url, this.mediaType});

  final String url;
  final String? mediaType;

  @override
  Widget build(BuildContext context) {
    if (_isVideoMediaType(mediaType)) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Row(
          children: [
            const Icon(Icons.movie_outlined),
            const SizedBox(width: 12),
            const Expanded(child: Text('Video attachment')),
            TextButton(
              onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
              child: const Text('Open'),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: 220,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(
          height: 220,
          child: Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => const SizedBox(
          height: 220,
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      ),
    );
  }
}

String _formatTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.month}/${local.day}/${local.year} $hour:$minute';
}
