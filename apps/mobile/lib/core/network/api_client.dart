import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_config.dart';
import '../storage/token_store.dart';
import '../../features/auth/presentation/auth_controller.dart';

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(tokenStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    QueuedInterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await store.accessToken();
        if (token != null) {
          options.headers['authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode != 401 ||
            error.requestOptions.extra['retried'] == true ||
            error.requestOptions.path.contains('/auth/refresh')) {
          handler.next(error);
          return;
        }
        final refresh = await store.refreshToken();
        if (refresh == null) {
          handler.next(error);
          return;
        }
        try {
          final response = await Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl))
              .post<Map<String, Object?>>(
                '/auth/refresh',
                data: {'refreshToken': refresh},
              );
          final data = response.data!;
          await store.save(
            accessToken: data['accessToken']! as String,
            refreshToken: data['refreshToken']! as String,
          );
          final request = error.requestOptions;
          request.headers['authorization'] = 'Bearer ${data['accessToken']}';
          request.extra['retried'] = true;
          handler.resolve(await dio.fetch<Object?>(request));
        } catch (_) {
          await store.clear();
          ref.read(authControllerProvider.notifier).markExpired();
          handler.next(error);
        }
      },
    ),
  );
  return dio;
});
