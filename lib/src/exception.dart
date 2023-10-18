import 'package:meta/meta.dart';

/// Book exception
@immutable
class BookException implements Exception {
  /// Book exception
  const BookException(this.code, this.message);

  /// Book exception code
  final String code;

  /// Book exception message
  final String message;

  @override
  String toString() => message;
}
