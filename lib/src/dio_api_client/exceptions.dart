import 'package:my_api_client/src/dio_api_client/enums.dart';

class ApiResponseException implements Exception {
  const ApiResponseException._(
    this.statusCode, {
    required this.errorMessage,
  }) : _type = ApiExceptionType.server;

  /// api 응답 오류입니다 (400대)
  const ApiResponseException.api({
    required this.errorMessage,
    this.statusCode,
  }) : _type = ApiExceptionType.api;

  /// 서버 통신 오류입니다 (500)
  const ApiResponseException.server({
    required this.errorMessage,
  })  : statusCode = 500,
        _type = ApiExceptionType.server;

  /// 응답 오류 메시지입니다
  final String errorMessage;

  /// 응답 statusCode 입니다
  final int? statusCode;

  /// 응답 오류 타입입니다
  final ApiExceptionType _type;

  /// 응답 오류 타입입니다
  ApiExceptionType get type => _type;
}
