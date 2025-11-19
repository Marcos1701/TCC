import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';

/// Mixin para comportamentos comuns em páginas admin
/// 
/// Fornece funcionalidades compartilhadas:
/// - Gerenciamento de estado de loading/error
/// - Métodos auxiliares para API
/// - Parsing de resposta padrão
mixin AdminPageMixin<T extends StatefulWidget> on State<T> {
  final apiClient = ApiClient();
  
  bool isLoading = true;
  String? errorMessage;

  /// Inicia estado de loading
  void startLoading() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
  }

  /// Define estado de erro
  void setError(String error) {
    setState(() {
      isLoading = false;
      errorMessage = error;
    });
  }

  /// Define estado de sucesso
  void setSuccess() {
    setState(() {
      isLoading = false;
      errorMessage = null;
    });
  }

  /// Parse de resposta JSON da API
  /// 
  /// Substitui o método _parseResponse duplicado
  Map<String, dynamic> parseResponse(dynamic response) {
    if (response.data == null) {
      return {};
    }

    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }

    if (response.data is String) {
      try {
        final decoded = json.decode(response.data.toString());
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return {};
      }
    }

    return {};
  }

  /// Executa ação async com tratamento de erro padrão
  Future<void> executeAdminAction(
    Future<void> Function() action, {
    String? successMessage,
    VoidCallback? onSuccess,
  }) async {
    startLoading();

    try {
      await action();
      setSuccess();
      
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      onSuccess?.call();
    } catch (e) {
      setError(e.toString());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
