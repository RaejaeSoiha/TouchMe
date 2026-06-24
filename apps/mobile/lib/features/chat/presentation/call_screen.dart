import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uuid/uuid.dart';
import '../data/chat_socket.dart';
import '../domain/call_signal.dart';

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({
    required this.conversationId,
    required this.title,
    required this.video,
    this.incomingCall,
    super.key,
  });

  final String conversationId;
  final String title;
  final bool video;
  final IncomingCall? incomingCall;

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final localRenderer = RTCVideoRenderer();
  final remoteRenderer = RTCVideoRenderer();
  final callId = const Uuid().v4();
  final pendingCandidates = <RTCIceCandidate>[];

  RTCPeerConnection? peer;
  MediaStream? localStream;
  StreamSubscription<CallAnswerSignal>? answerSubscription;
  StreamSubscription<CallIceSignal>? iceSubscription;
  StreamSubscription<CallEndSignal>? endSubscription;
  StreamSubscription<CallBusySignal>? busySubscription;
  bool remoteDescriptionReady = false;
  bool disposedCall = false;
  bool connecting = true;
  bool muted = false;
  bool cameraOff = false;
  String status = 'Connecting…';

  String get activeCallId => widget.incomingCall?.callId ?? callId;

  @override
  void initState() {
    super.initState();
    Future<void>(_start);
  }

  @override
  void dispose() {
    _disposeCall(sendEnd: false);
    super.dispose();
  }

  Future<void> _start() async {
    final socket = ref.read(chatSocketProvider);
    await socket.connect();
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    _subscribeToSignals(socket);
    await _openMedia();
    await _createPeer(socket);
    if (widget.incomingCall != null) {
      await _answerIncoming(socket, widget.incomingCall!);
    } else {
      await _placeOutgoing(socket);
    }
    if (!mounted) return;
    setState(() {
      connecting = false;
      status = widget.incomingCall == null ? 'Ringing…' : 'Connected';
    });
  }

  void _subscribeToSignals(ChatSocket socket) {
    answerSubscription = socket.callAnswers
        .where((event) => event.callId == activeCallId)
        .listen((event) async {
      await peer?.setRemoteDescription(_descriptionFromMap(event.answer));
      remoteDescriptionReady = true;
      await _flushPendingCandidates();
      if (mounted) setState(() => status = 'Connected');
    });
    iceSubscription = socket.callIceEvents
        .where((event) => event.callId == activeCallId)
        .listen((event) async {
      final candidate = _candidateFromMap(event.candidate);
      if (!remoteDescriptionReady) {
        pendingCandidates.add(candidate);
        return;
      }
      await peer?.addCandidate(candidate);
    });
    endSubscription = socket.callEnds
        .where((event) => event.callId == activeCallId)
        .listen((_) async {
      if (!mounted) return;
      setState(() => status = 'Call ended');
      await _disposeCall(sendEnd: false);
      if (mounted) Navigator.of(context).pop();
    });
    busySubscription = socket.callBusy
        .where((event) => event.callId == activeCallId)
        .listen((_) async {
      if (!mounted) return;
      setState(() => status = 'User is busy');
      await _disposeCall(sendEnd: false);
    });
  }

  Future<void> _openMedia() async {
    final constraints = <String, Object>{
      'audio': true,
      'video': widget.video
          ? <String, Object>{
              'facingMode': 'user',
              'width': 1280,
              'height': 720,
            }
          : false,
    };
    localStream = await navigator.mediaDevices.getUserMedia(constraints);
    localRenderer.srcObject = localStream;
  }

  Future<void> _createPeer(ChatSocket socket) async {
    peer = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
    });
    peer!.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      socket.callIce(
        conversationId: widget.conversationId,
        callId: activeCallId,
        candidate: _candidateToMap(candidate),
      );
    };
    peer!.onTrack = (event) {
      if (event.streams.isEmpty) return;
      remoteRenderer.srcObject = event.streams.first;
      if (mounted) setState(() => status = 'Connected');
    };
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await peer!.addTrack(track, localStream!);
    }
  }

  Future<void> _placeOutgoing(ChatSocket socket) async {
    final offer = await peer!.createOffer();
    await peer!.setLocalDescription(offer);
    socket.callOffer(
      conversationId: widget.conversationId,
      callId: activeCallId,
      media: widget.video ? 'VIDEO' : 'AUDIO',
      offer: _descriptionToMap(offer),
    );
  }

  Future<void> _answerIncoming(ChatSocket socket, IncomingCall call) async {
    await peer!.setRemoteDescription(_descriptionFromMap(call.offer));
    remoteDescriptionReady = true;
    await _flushPendingCandidates();
    final answer = await peer!.createAnswer();
    await peer!.setLocalDescription(answer);
    socket.callAnswer(
      conversationId: widget.conversationId,
      callId: call.callId,
      answer: _descriptionToMap(answer),
    );
  }

  Future<void> _flushPendingCandidates() async {
    if (pendingCandidates.isEmpty) return;
    final candidates = List<RTCIceCandidate>.from(pendingCandidates);
    pendingCandidates.clear();
    for (final candidate in candidates) {
      await peer?.addCandidate(candidate);
    }
  }

  void _toggleMute() {
    muted = !muted;
    for (final track in localStream?.getAudioTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !muted;
    }
    setState(() {});
  }

  void _toggleCamera() {
    cameraOff = !cameraOff;
    for (final track in localStream?.getVideoTracks() ?? <MediaStreamTrack>[]) {
      track.enabled = !cameraOff;
    }
    setState(() {});
  }

  Future<void> _hangUp() async {
    await _disposeCall(sendEnd: true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _disposeCall({required bool sendEnd}) async {
    if (disposedCall) return;
    disposedCall = true;
    if (sendEnd) {
      ref.read(chatSocketProvider).endCall(
            conversationId: widget.conversationId,
            callId: activeCallId,
            reason: 'ended',
          );
    }
    await answerSubscription?.cancel();
    await iceSubscription?.cancel();
    await endSubscription?.cancel();
    await busySubscription?.cancel();
    for (final track in localStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    await localStream?.dispose();
    await peer?.close();
    await peer?.dispose();
    await localRenderer.dispose();
    await remoteRenderer.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = widget.video || widget.incomingCall?.media == 'VIDEO';
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: video
                ? RTCVideoView(
                    remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Center(
                    child: Icon(
                      Icons.account_circle,
                      size: 144,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
          ),
          if (video)
            Positioned(
              top: 24,
              right: 24,
              width: 120,
              height: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: Colors.black87,
                  child: cameraOff
                      ? const Icon(Icons.videocam_off, color: Colors.white)
                      : RTCVideoView(
                          localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  status,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CallControl(
                      icon: muted ? Icons.mic_off : Icons.mic,
                      onPressed: connecting ? null : _toggleMute,
                    ),
                    if (video) ...[
                      const SizedBox(width: 18),
                      _CallControl(
                        icon: cameraOff ? Icons.videocam_off : Icons.videocam,
                        onPressed: connecting ? null : _toggleCamera,
                      ),
                    ],
                    const SizedBox(width: 18),
                    _CallControl(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onPressed: _hangUp,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallControl extends StatelessWidget {
  const _CallControl({
    required this.icon,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton.filled(
      style: IconButton.styleFrom(
        backgroundColor: color ?? Colors.white.withValues(alpha: 0.18),
        foregroundColor: Colors.white,
        fixedSize: const Size.square(58),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

Map<String, Object?> _descriptionToMap(RTCSessionDescription description) => {
      'sdp': description.sdp,
      'type': description.type,
    };

RTCSessionDescription _descriptionFromMap(Map<String, Object?> map) =>
    RTCSessionDescription(map['sdp'] as String?, map['type'] as String?);

Map<String, Object?> _candidateToMap(RTCIceCandidate candidate) => {
      'candidate': candidate.candidate,
      'sdpMid': candidate.sdpMid,
      'sdpMLineIndex': candidate.sdpMLineIndex,
    };

RTCIceCandidate _candidateFromMap(Map<String, Object?> map) => RTCIceCandidate(
      map['candidate'] as String?,
      map['sdpMid'] as String?,
      map['sdpMLineIndex'] as int?,
    );
