part of 'api_client.dart';

typedef _Json = Map<String, dynamic>;

extension ResponseExtension on Response {
  Response get jsonDecoded {
    /// String or null will be returned when status code is 500
    if (statusCode == 500) return this;

    /// Returned with simple string
    if (data is String) return this;

    /// return Response with [List<Json>] decoded data field if data's type is list
    if (data is List) {
      data = (data as List).cast<_Json>().toList();
      return this;
    }

    /// return Response with [Json] decoded data field if data's type is not list
    data = data as _Json;
    return this;
  }

  ApiResponseException? get exception {
    /// request success
    if ((statusCode! / 100).floor() == 2) return null;

    /// server exception
    if (statusCode == 500) {
      return const ApiResponseException.server(
        errorMessage: '서버 통신에 오류가 발생했습니다',
      );
    }

    // /// unauthorized exception
    // if (statusCode == 401) return const ApiException.unauthorizedError();

    /// api response exception
    return ApiResponseException.api(
      statusCode: statusCode,
      errorMessage: data?['message'] ?? '응답이 없습니다',
    );
  }

  bool get hasException => exception != null;
}
