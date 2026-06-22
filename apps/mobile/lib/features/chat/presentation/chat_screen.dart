import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import '../../../core/layout/responsive.dart';
import '../data/chat_repository.dart';
import '../data/chat_socket.dart';
import '../data/media_repository.dart';
import '../domain/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.conversationId,
    this.title,
    super.key,
  });

  final String conversationId;
  final String? title;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final text = TextEditingController();
  final scroll = ScrollController();
  final messages = <ChatMessage>[];
  final recorder = AudioRecorder();
  StreamSubscription<ChatMessage>? subscription;
  bool loading = true;
  bool recording = false;
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
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
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

  Future<void> sendPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2048,
    );
    if (picked == null) return;
    final url = await ref
        .read(mediaRepositoryProvider)
        .upload(File(picked.path), picked.mimeType ?? 'image/jpeg');
    ref.read(chatSocketProvider).send({
      'conversationId': widget.conversationId,
      'clientId': const Uuid().v4(),
      'type': 'IMAGE',
      'mediaUrl': url,
    });
  }

  Future<void> toggleRecording() async {
    if (recording) {
      final path = await recorder.stop();
      final started = recordingStarted;
      setState(() => recording = false);
      if (path == null) return;
      final url = await ref
          .read(mediaRepositoryProvider)
          .upload(File(path), 'audio/m4a');
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

  @override
  Widget build(BuildContext context) {
    final maxWidth = Responsive.contentMaxWidth(context);
    return Scaffold(
    appBar: AppBar(title: Text(widget.title ?? 'Chat')),
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
                    return Align(
                      alignment: index.isEven
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          color: index.isEven
                              ? Colors.white
                              : Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: message.type == 'IMAGE' && message.mediaUrl != null
                            ? Image.network(message.mediaUrl!, width: 220)
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (message.type == 'VOICE')
                                    const Icon(Icons.play_arrow),
                                  Flexible(
                                    child: Text(
                                      message.body ??
                                          (message.type == 'VOICE'
                                              ? 'Voice note'
                                              : 'Media'),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
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
