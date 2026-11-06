/// Error body of the AuxIA API (`application/problem+json`, RFC 9457).
class ProblemDetails {
  const ProblemDetails({
    this.title,
    this.status,
    this.detail,
    this.fieldErrors = const {},
  });

  final String? title;
  final int? status;
  final String? detail;

  /// `errors[].field` → `errors[].message`, present on validation errors.
  final Map<String, String> fieldErrors;

  /// Parses a decoded JSON body; returns null if it is not a problem object.
  static ProblemDetails? tryParse(Object? body) {
    if (body is! Map) return null;
    final errors = <String, String>{};
    final rawErrors = body['errors'];
    if (rawErrors is List) {
      for (final item in rawErrors) {
        if (item is Map && item['field'] is String) {
          errors[item['field'] as String] = '${item['message'] ?? ''}';
        }
      }
    }
    return ProblemDetails(
      title: body['title'] as String?,
      status: (body['status'] as num?)?.toInt(),
      detail: body['detail'] as String?,
      fieldErrors: errors,
    );
  }
}
