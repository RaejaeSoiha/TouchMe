import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final postsRepositoryProvider = Provider<PostsRepository>(
  (ref) => PostsRepository(ref.watch(dioProvider)),
);

final homePostsProvider = FutureProvider<List<FeedPost>>(
  (ref) => ref.watch(postsRepositoryProvider).feed(),
);

class FeedPost {
  const FeedPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    required this.visibility,
    required this.allowComments,
    required this.likeCount,
    required this.likedByMe,
    required this.comments,
    this.mediaUrl,
    this.mediaType,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final String visibility;
  final bool allowComments;
  final int likeCount;
  final bool likedByMe;
  final List<FeedComment> comments;
  final String? mediaUrl;
  final String? mediaType;

  factory FeedPost.fromJson(Map<String, Object?> json) => FeedPost(
    id: json['id']! as String,
    authorId: json['authorId']! as String,
    authorName: json['authorName']! as String,
    body: json['body']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
    visibility: json['visibility']! as String,
    allowComments: json['allowComments']! as bool,
    likeCount: json['likeCount']! as int,
    likedByMe: json['likedByMe']! as bool,
    mediaUrl: json['mediaUrl'] as String?,
    mediaType: json['mediaType'] as String?,
    comments: ((json['comments'] as List<Object?>?) ?? [])
        .map((item) => FeedComment.fromJson(item! as Map<String, Object?>))
        .toList(),
  );
}

class FeedComment {
  const FeedComment({
    required this.id,
    required this.authorName,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String body;
  final DateTime createdAt;

  factory FeedComment.fromJson(Map<String, Object?> json) => FeedComment(
    id: json['id']! as String,
    authorName: json['authorName']! as String,
    body: json['body']! as String,
    createdAt: DateTime.parse(json['createdAt']! as String),
  );
}

class PostsRepository {
  PostsRepository(this._dio);
  final Dio _dio;

  Future<List<FeedPost>> feed() async {
    final response = await _dio.get<List<Object?>>('/posts');
    return response.data!
        .map((item) => FeedPost.fromJson(item! as Map<String, Object?>))
        .toList();
  }

  Future<FeedPost> create({
    required String body,
    String? mediaUrl,
    String? mediaType,
    required String visibility,
    required bool allowComments,
  }) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/posts',
      data: {
        'body': body,
        if (mediaUrl != null) 'mediaUrl': mediaUrl,
        if (mediaType != null) 'mediaType': mediaType,
        'visibility': visibility,
        'allowComments': allowComments,
      },
    );
    return FeedPost.fromJson(response.data!);
  }

  Future<void> toggleLike(String postId) => _dio.post<void>('/posts/$postId/like');

  Future<void> addComment(String postId, String body) => _dio.post<void>(
    '/posts/$postId/comments',
    data: {'body': body},
  );

  Future<String> uploadMedia(Uint8List bytes, String contentType) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/uploads/presign',
      data: {
        'contentType': contentType,
        'contentLength': bytes.length,
        'purpose': 'message',
      },
    );
    final data = response.data!;
    await Dio().put<void>(
      data['uploadUrl']! as String,
      data: Stream.value(bytes),
      options: Options(
        headers: {'content-type': contentType, 'content-length': bytes.length},
      ),
    );
    return data['publicUrl']! as String;
  }
}
