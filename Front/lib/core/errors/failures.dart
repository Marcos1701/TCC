abstract class Failure {
  final String message;
  final int? statusCode;

  const Failure(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure([String message = 'Erro de conexão'])
      : super(message, statusCode: null);
}

class ServerFailure extends Failure {
  const ServerFailure(String message, {int? statusCode})
      : super(message, statusCode: statusCode);
}

class ValidationFailure extends Failure {
  final Map<String, dynamic>? errors;

  const ValidationFailure(String message, {this.errors})
      : super(message, statusCode: 400);
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([String message = 'Sessão expirada'])
      : super(message, statusCode: 401);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([String message = 'Recurso não encontrado'])
      : super(message, statusCode: 404);
}

class ParseFailure extends Failure {
  const ParseFailure([String message = 'Erro ao processar resposta'])
      : super(message);
}
