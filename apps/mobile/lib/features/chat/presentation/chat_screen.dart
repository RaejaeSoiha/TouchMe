import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/auth/current_user_id.dart';
import '../../../core/layout/responsive.dart';
import '../../../core/safety/user_actions_sheet.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../data/media_repository.dart';
import '../data/read_path_bytes.dart';
import '../domain/call_signal.dart';
import '../domain/chat_message.dart';
import 'call_screen.dart';

class ChatRouteExtra {
  const ChatRouteExtra({
    this.title,
    this.otherUserId,
    this.otherUserName,
  });

  final String? title;
  final String? otherUserId;
  final String? otherUserName;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.conversationId,
    this.title,
    this.otherUserId,
    this.otherUserName,
    super.key,
  });

  final String conversationId;
  final String? title;
  final String? otherUserId;
  final String? otherUserName;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[];
  final recorder = AudioRecorder();
  final audioPlayer = AudioPlayer();
  StreamSubscription<ChatMessage>? subscription;
  StreamSubscription<IncomingCall>? callSubscription;
  StreamSubscription<TypingEvent>? typingSubscription;
  bool loading = true;
  bool recording = false;
  bool otherUserTyping = false;
  String? playingMessageId;
  DateTime? recordingStarted;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final socket = ref.read(chatSocketProvider);
      await socket.connect();
      socket.joinConversation(widget.conversationId);
      final history = await ref
          .read(chatRepositoryProvider)
          .messages(widget.conversationId);
      if (!mounted) return;
      setState(() {
        messages.addAll(history);
        loading = false;
      });
      subscription = socket.messages
          .where((message) => message.conversationId == widget.conversationId)
          .listen((message) {
        if (!mounted) return;
        setState(() => messages.add(message));
        socket.receipt(message.id, 'READ');
        _scrollDown();
      });
      callSubscription = socket.callOffers
          .where((call) => call.conversationId == widget.conversationId)
          .listen(_showIncomingCall);
      final myId = await ref.read(currentUserIdProvider.future);
      typingSubscription = socket.typingEvents.listen((event) {
        if (!mounted || myId == null) return;
        if (event.userId == myId) return;
        setState(() => otherUserTyping = event.active);
      });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    callSubscription?.cancel();
    typingSubscription?.cancel();
    audioPlayer.dispose();
    recorder.dispose();
    text.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(
          scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void send() {
    final body = text.text.trim();
    if (body.isEmpty) return;
    ref.read(chatSocketProvider).send({
      'conversationId': widget.conversationId,
      'clientId': const Uuid().v4(),
      'type': 'TEXT',
      'body': body,
    });
    text.clear();
    ref.read(chatSocketProvider).typing(widget.conversationId, false);
  }

  Future<void> _startCall({required bool video}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          conversationId: widget.conversationId,
          title: widget.title ?? 'TouchMe call',
          video: video,
        ),
      ),
    );
  }

  Future<void> _showIncomingCall(IncomingCall call) async {
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('${widget.title ?? 'Someone'} is calling'),
        content: Text(call.media == 'VIDEO' ? 'Incoming video call' : 'Incoming voice call'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Answer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (accepted != true) {
      ref.read(chatSocketProvider).busyCall(
            conversationId: call.conversationId,
            callId: call.callId,
          );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          conversationId: widget.conversationId,
          title: widget.title ?? 'TouchMe call',
          video: call.media == 'VIDEO',
          incomingCall: call,
        ),
      ),
    );
  }

  Future<void> sendPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final url = await ref.read(mediaRepositoryProvider).uploadBytes(
      bytes,
      picked.mimeType ?? 'image/jpeg',
    );
    ref.read(chatSocketProvider).send({
      'conversationId': widget.conversationId,
      'clientId': const Uuid().v4(),
      'type': 'IMAGE',
      'mediaUrl': url,
    });
  }

  Future<void> toggleRecording() async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice notes are not supported on web yet')),
        );
      }
      return;
    }
    if (recording) {
      final path = await recorder.stop();
      final started = recordingStarted;
      setState(() => recording = false);
      if (path == null) return;
      final bytes = await readPathBytes(path);
      final url = await ref
          .read(mediaRepositoryProvider)
          .uploadBytes(bytes, 'audio/m4a');
      final seconds = DateTime.now()
          .difference(started ?? DateTime.now())
          .inSeconds
          .clamp(1, 600);
      ref.read(chatSocketProvider).send({
        'conversationId': widget.conversationId,
        'clientId': const Uuid().v4(),
        'type': 'VOICE',
        'mediaUrl': url,
        'mediaSeconds': seconds,
      });
      return;
    }
    if (!await recorder.hasPermission()) return;
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${const Uuid().v4()}.m4a';
    await recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    setState(() {
      recording = true;
      recordingStarted = DateTime.now();
    });
  }

  Future<void> _playVoice(ChatMessage message) async {
    final url = message.mediaUrl;
    if (url == null) return;
    if (playingMessageId == message.id) {
      await audioPlayer.stop();
      setState(() => playingMessageId = null);
      return;
    }
    setState(() => playingMessageId = message.id);
    try {
      await audioPlayer.setUrl(url);
      await audioPlayer.play();
      await audioPlayer.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play voice note')),
        );
      }
    } finally {
      if (mounted && playingMessageId == message.id) {
        setState(() => playingMessageId = null);
      }
    }
  }

  void _showSafetyMenu() {
    final userId = widget.otherUserId;
    final name = widget.otherUserName ?? widget.title ?? 'this user';
    if (userId == null || userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User info unavailable for block/report')),
      );
      return;
    }
    showBlockReportSheet(
      context,
      ref,
      userId: userId,
      displayName: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxWidth = Responsive.contentMaxWidth(context);
    final myId = ref.watch(currentUserIdProvider).asData?.value;
    return Scaffold(
    appBar: AppBar(
      title: Text(widget.title ?? 'Chat'),
      actions: [
        IconButton(
          tooltip: 'Voice call',
          onPressed: () => _startCall(video: false),
          icon: const Icon(Icons.call_outlined),
        ),
        IconButton(
          tooltip: 'Video call',
          onPressed: () => _startCall(video: true),
          icon: const Icon(Icons.videocam_outlined),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'safety') _showSafetyMenu();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'safety',
              child: ListTile(
                leading: Icon(Icons.shield_outlined),
                title: Text('Block or report'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    final message = messages[index];
                    final isMine = myId != null && message.senderId == myId;
                    return Align(
                      alignment: isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          color: isMine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: message.type == 'IMAGE' && message.mediaUrl != null
                            ? Image.network(message.mediaUrl!, width: 220)
                            : message.type == 'VOICE'
                                ? InkWell(
                                    onTap: () => _playVoice(message),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          playingMessageId == message.id
                                              ? Icons.stop_circle_outlined
                                              : Icons.play_arrow,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          playingMessageId == message.id
                                              ? 'Playing…'
                                              : 'Voice note',
                                        ),
                                      ],
                                    ),
                                  )
                                : Text(message.body ?? 'Media'),
                      ),
                    );
                  },
                ),
            ),
          ),
        ),
        if (otherUserTyping)
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Text(
                  '${widget.title ?? 'They'} is typing…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: sendPhoto,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                ),
                IconButton(
                  onPressed: toggleRecording,
                  color: recording ? Colors.red : null,
                  icon: Icon(recording ? Icons.stop_circle : Icons.mic_none),
                ),
                Expanded(
                  child: TextField(
                    controller: text,
                    maxLines: 5,
                    minLines: 1,
                    onChanged: (_) => ref
                        .read(chatSocketProvider)
                        .typing(widget.conversationId, true),
                    onSubmitted: (_) => send(),
                    decoration: InputDecoration(
                      hintText: recording ? 'Recording…' : 'Message',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  onPressed: send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
            ),
          ),
        ),
      ],
    ),
  );
  }
}
