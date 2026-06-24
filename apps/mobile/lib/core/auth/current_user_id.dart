import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/token_store.dart';

final currentUserIdProvider = FutureProvider<String?>((ref) async {
  final token = await ref.watch(tokenStoreProvider).accessToken();
  if (token == null) return null;
  final parts = token.split('.');
  if (parts.length != 3) return null;
  final payload = json.decode(
    utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
  ) as Map<String, dynamic>;
  return payload['sub'] as String?;
});
