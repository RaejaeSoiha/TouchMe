class IncomingCall {
  const IncomingCall({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.media,
    required this.offer,
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final String media;
  final Map<String, Object?> offer;
}

class CallAnswerSignal {
  const CallAnswerSignal({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.answer,
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final Map<String, Object?> answer;
}

class CallIceSignal {
  const CallIceSignal({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.candidate,
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final Map<String, Object?> candidate;
}

class CallEndSignal {
  const CallEndSignal({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.reason,
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final String reason;
}

class CallBusySignal {
  const CallBusySignal({
    required this.conversationId,
    required this.callId,
    required this.fromUserId,
    required this.busy,
  });

  final String conversationId;
  final String callId;
  final String fromUserId;
  final bool busy;
}
