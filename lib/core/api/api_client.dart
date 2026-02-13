import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required String baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio _dio;

  Future<Response<dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    String? authToken,
  }) {
    return _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: _buildOptions(authToken),
    );
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? authToken,
  }) {
    return _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _buildOptions(authToken),
    );
  }

  Future<Response<dynamic>> patch(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? authToken,
  }) {
    return _dio.patch<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _buildOptions(authToken),
    );
  }

  Future<Response<dynamic>> delete(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? authToken,
  }) {
    return _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: _buildOptions(authToken),
    );
  }

  Options? _buildOptions(String? authToken) {
    if (authToken == null || authToken.isEmpty) {
      return null;
    }
    return Options(headers: <String, String>{'Authorization': 'Bearer $authToken'});
  }
}
