import 'failures.dart';

class Result<T> {
  final T? data;
  final Failure? failure;

  const Result.success(this.data) : failure = null;
  const Result.failure(this.failure) : data = null;

  bool get isSuccess => data != null;
  bool get isFailure => failure != null;

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(data as T);
    } else {
      return onFailure(failure!);
    }
  }

  T getOrElse(T defaultValue) {
    return data ?? defaultValue;
  }

  T? getOrNull() {
    return data;
  }
}
