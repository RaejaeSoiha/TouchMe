class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.body,
    required this.mediaUrl,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String type;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;

  factory ChatMessage.fromJson(Map<String, Object?> json) => ChatMessage(
    id: json['id']! as String,
    conversationId: json['conversationId']! as String,
    senderId: json['senderId']! as String,
    type: json['type']! as String,
    body: json['body'] as String?,
    mediaUrl: json['mediaUrl'] as String?,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}
