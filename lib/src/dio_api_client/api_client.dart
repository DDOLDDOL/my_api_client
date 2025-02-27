import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:my_api_client/src/dio_api_client/enums.dart';
import 'package:my_api_client/src/dio_api_client/exceptions.dart';

part 'response_extension.dart';

typedef Json = Map<String, dynamic>;
typedef FileJson = Map<String, File>;

class ApiClient {
  /// HTTP 통신을 더 간편하게 핸들링 할 수 있도록 해주는 Dio Wrapper 클래스입니다
  ApiClient({
    this.authorizationHeader,
    this.onTokenRefreshRequired,
  }) : _dio = Dio();

  /// HTTP 요청 헤더에 전달할 Authorization Type과 Token 값입니다
  ///
  /// ex) Bearer [YOUR_ACCESS_TOKEN]
  final String Function()? authorizationHeader;

  /// Access Token 만료 시에 토큰을 전체 refresh하는 함수를 전달합니다
  final Future<void> Function()? onTokenRefreshRequired;

  final Dio _dio; // HTTP 요청을 보낼 Dio 객체입니다

  /// HTTP 요청 메서드 중 GET 요청을 보냅니다
  Future<Response> get(
    String requestUrl, {
    bool needAuth = false,
    bool external = false,
    Json? queryParameters,
    Options? options,
    Json? body,
    CancelToken? cancelToken,
  }) {
    return _request(
      requestUrl,
      type: RequestType.get,
      needAuth: needAuth,
      queryParameters: queryParameters,
      options: options,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 요청 메서드 중 POST 요청을 보냅니다
  Future<Response> post(
    String requestUrl, {
    bool needAuth = false,
    bool external = false,
    bool useFormData = false,
    Json? queryParameters,
    Options? options,
    Json? body,
    FileJson? files,
    CancelToken? cancelToken,
  }) {
    return _request(
      requestUrl,
      type: RequestType.post,
      needAuth: needAuth,
      useFormData: useFormData,
      queryParameters: queryParameters,
      options: options,
      body: body,
      files: files,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 요청 메서드 중 PUT 요청을 보냅니다
  Future<Response> put(
    String requestUrl, {
    bool needAuth = false,
    bool external = false,
    Json? queryParameters,
    Options? options,
    Json? body,
    CancelToken? cancelToken,
  }) {
    return _request(
      requestUrl,
      type: RequestType.put,
      needAuth: needAuth,
      queryParameters: queryParameters,
      options: options,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 요청 메서드 중 PATCH 요청을 보냅니다
  Future<Response> patch(
    String requestUrl, {
    bool needAuth = false,
    bool external = false,
    Json? queryParameters,
    Options? options,
    Json? body,
    CancelToken? cancelToken,
  }) {
    return _request(
      requestUrl,
      type: RequestType.patch,
      needAuth: needAuth,
      queryParameters: queryParameters,
      options: options,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 요청 메서드 중 DELETE 요청을 보냅니다
  Future<Response> delete(
    String requestUrl, {
    bool needAuth = false,
    bool external = false,
    Json? queryParameters,
    Options? options,
    Json? body,
    CancelToken? cancelToken,
  }) {
    return _request(
      requestUrl,
      type: RequestType.delete,
      needAuth: needAuth,
      queryParameters: queryParameters,
      options: options,
      body: body,
      cancelToken: cancelToken,
    );
  }

  /// HTTP 요청을 보냅니다
  Future<Response> _request(
    /// API 요청 Url입니다
    String requestUrl, {
    /// Http Method 타입입니다
    required RequestType type,

    /// 서버로의 요청에 Authorization 필요 여부입니다
    ///
    /// true일 경우 내부 멤버 [accessTokenGetter]의 반환 값이 헤더로 전달됩니다
    required bool needAuth,

    /// FormData 여부입니다
    bool useFormData = false,

    /// Url 뒤에 붙는 Query Parameter 맵입니다
    Json? queryParameters,

    /// 헤더를 비롯한 Dio 옵션입니다
    Options? options,

    /// 요청 body입니다
    Json? body,

    /// FormData 요청 body입니다
    FileJson? files,

    /// Dio CancelToken
    CancelToken? cancelToken,
  }) async {
    // [method] field in [options] argument must be null because
    // it is replaced with String value from [type] argument
    assert(options?.method == null);
    assert(
      files == null || useFormData,
      'If you upload files by POST method, "useFormData" field must be true',
    );
    assert(!(useFormData && body == null && files == null));

    final method = switch (type) {
      RequestType.get => 'GET',
      RequestType.post => 'POST',
      RequestType.put => 'PUT',
      RequestType.patch => 'PATCH',
      RequestType.delete => 'DELETE',
    };

    final response = await _auth(
      request: () => _dio.request(
        requestUrl,
        options: _defaultOptions(
          options,
          method: method,
          needAuth: needAuth,
          useFormData: useFormData,
        ),
        data: useFormData
            ? FormData.fromMap({
                ...(body ?? {}),
                ...(files ?? {}).map(
                  (key, file) => MapEntry(
                    key,
                    MultipartFile.fromFileSync(file.path),
                  ),
                ),
              })
            : body,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      ),
    );

    return ResponseExtension(response).jsonDecoded;
  }

  /// 기본 Dio Option 입니다
  Options _defaultOptions(
    Options? options, {
    required String method,
    required bool needAuth,
    bool useFormData = false,
  }) {
    final contentType =
        useFormData ? 'multipart/form-data' : 'application/json';

    options ??= Options(headers: {'Content-Type': contentType});
    options.headers ??= {'Content-Type': contentType};
    options.headers!['Content-Type'] ??= contentType;

    print('authorization header: ${authorizationHeader?.call()}');

    if (needAuth) {
      options.headers!.addAll({
        'Authorization': authorizationHeader?.call(),
      });
    }

    return options.copyWith(method: method, validateStatus: (_) => true);
  }

  /// HTTP 요청 시에 authorization을 수행합니다
  Future<Response> _auth({
    required Future<Response> Function() request,
  }) async {
    final response = await request();

    // 401 error 발생시에만 _refreshTokens 호출 후 재요청 결과 반환
    if (response.statusCode == 401) {
      await onTokenRefreshRequired?.call();

      // tokens refresh 에러 발생 -> return -> 재 요청 시 똑같이 401 에러 반환
      return await request();
    }

    return response;
  }
}
