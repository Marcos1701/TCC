abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Connection error'])
      : super(statusCode: null);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message, {super.statusCode});
}

class ValidationFailure extends Failure {
  final Map<String, dynamic>? errors;

  const ValidationFailure(super.message, {this.errors})
      : super(statusCode: 400);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([super.message = 'Session expired'])
      : super(statusCode: 401);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Resource not found'])
      : super(statusCode: 404);
}

class ParseFailure extends Failure {
  const ParseFailure([super.message = 'Error processing response']);
}
