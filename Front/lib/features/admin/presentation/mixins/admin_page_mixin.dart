import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';

mixin AdminPageMixin<T extends StatefulWidget> on State<T> {
  final apiClient = ApiClient();
  
  bool isLoading = true;
  String? errorMessage;

  void startLoading() {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
  }

  void setError(String error) {
    setState(() {
      isLoading = false;
      errorMessage = error;
    });
  }

  void setSuccess() {
    setState(() {
      isLoading = false;
      errorMessage = null;
    });
  }

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
