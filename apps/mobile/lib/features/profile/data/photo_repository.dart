import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(ref.watch(dioProvider)),
);

class PhotoRepository {
  PhotoRepository(this._dio);
  final Dio _dio;

  Future<void> uploadProfilePhotoBytes(
    List<int> bytes,
    String contentType,
    int position,
  ) async {
    if (kIsWeb) {
      await _dio.post<void>(
        '/uploads/photos/direct',
        data: {
          'contentType': contentType,
          'position': position,
          'imageBase64': base64Encode(bytes),
        },
      );
      return;
    }

    final presign = await _dio.post<Map<String, Object?>>(
      '/uploads/presign',
      data: {
        'contentType': contentType,
        'contentLength': bytes.length,
        'purpose': 'profile',
      },
    );
    final data = presign.data!;
    await Dio().put<void>(
      data['uploadUrl']! as String,
      data: bytes,
      options: Options(
        headers: {'content-type': contentType, 'content-length': bytes.length},
      ),
    );
    await _dio.post<void>(
      '/uploads/photos/complete',
      data: {'storageKey': data['key']! as String, 'position': position},
    );
  }

  Future<void> deletePhoto(String photoId) =>
      _dio.delete<void>('/profiles/me/photos/$photoId');

  Future<void> reorderPhotos(List<String> photoIds) => _dio.patch<void>(
    '/profiles/me/photos/order',
    data: {'photoIds': photoIds},
  );

  static String contentTypeForFilename(String? filename) {
    final lower = (filename ?? '').toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
