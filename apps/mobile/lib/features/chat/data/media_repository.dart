import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(ref.watch(dioProvider)),
);

class MediaRepository {
  MediaRepository(this._dio);
  final Dio _dio;

  Future<String> uploadBytes(Uint8List bytes, String contentType) async {
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
