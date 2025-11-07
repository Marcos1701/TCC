# Correções - Problema de Type Cast no Painel Administrativo

## 🐛 Problema Identificado

Ao acessar o painel administrativo, ocorria o erro:
```
DioException [unknown]: null
Error: type 'String' is not a subtype of type 'Map<String, dynamic>?' in type cast
```

## 🔍 Causa Raiz

O problema ocorria porque o Dio (cliente HTTP) estava retornando os dados da API como `String` (JSON serializado) ao invés de `Map<String, dynamic>` já parseado. 

Isso acontece quando:
1. O backend retorna JSON mas sem o header `Content-Type: application/json` correto
2. O Dio não consegue fazer o parse automático
3. O código tenta fazer cast direto de String para Map

## ✅ Solução Aplicada

### 1. AdminDashboardPage

**Antes:**
```dart
final response = await _apiClient.client.get<Map<String, dynamic>>(
  '/admin/stats/overview/',
);

if (response.data != null) {
  setState(() {
    _stats = response.data!;
    _isLoading = false;
  });
}
```

**Depois:**
```dart
final response = await _apiClient.client.get(
  '/admin/stats/overview/',
);

if (response.data != null) {
  final data = response.data is Map<String, dynamic> 
      ? response.data as Map<String, dynamic>
      : json.decode(response.data.toString()) as Map<String, dynamic>;
  
  setState(() {
    _stats = data;
    _isLoading = false;
  });
}
```

### 2. AdminMissionsManagementPage

**Antes:**
```dart
final response = await _apiClient.client.get<Map<String, dynamic>>(
  '/missions/',
);

if (response.data != null) {
  final results = response.data!['results'] as List?;
  setState(() {
    _missions = results?.cast<Map<String, dynamic>>() ?? [];
    _isLoading = false;
  });
}
```

**Depois:**
```dart
final response = await _apiClient.client.get(
  '/missions/',
);

if (response.data != null) {
  final data = response.data is Map<String, dynamic> 
      ? response.data as Map<String, dynamic>
      : json.decode(response.data.toString()) as Map<String, dynamic>;
  
  final results = data['results'] as List?;
  setState(() {
    _missions = results?.cast<Map<String, dynamic>>() ?? [];
    _isLoading = false;
  });
}
```

### 3. AdminCategoriesManagementPage

**Antes:**
```dart
final response = await _apiClient.client.get<List<dynamic>>(
  '/categories/',
);

if (response.data != null) {
  final allCategories = response.data!.cast<Map<String, dynamic>>();
  
  setState(() {
    _categories = allCategories
        .where((cat) => cat['is_user_created'] == false)
        .toList();
    _isLoading = false;
  });
}
```

**Depois:**
```dart
final response = await _apiClient.client.get(
  '/categories/',
);

if (response.data != null) {
  List<dynamic> dataList;
  
  if (response.data is List) {
    dataList = response.data as List;
  } else if (response.data is String) {
    dataList = json.decode(response.data.toString()) as List;
  } else if (response.data is Map && response.data['results'] != null) {
    dataList = response.data['results'] as List;
  } else {
    dataList = [];
  }
  
  final allCategories = dataList.cast<Map<String, dynamic>>();
  
  setState(() {
    _categories = allCategories
        .where((cat) => cat['is_user_created'] == false)
        .toList();
    _isLoading = false;
  });
}
```

### 4. Settings Page - Navegação Corrigida

**Antes:**
```dart
import '../../../admin/presentation/pages/admin_ai_missions_page.dart';

// ...

subtitle: 'Gerar missões com IA',
onTap: () => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const AdminAiMissionsPage(),
  ),
),
```

**Depois:**
```dart
import '../../../admin/presentation/pages/admin_dashboard_page.dart';

// ...

subtitle: 'Dashboard e gerenciamento do sistema',
onTap: () => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => const AdminDashboardPage(),
  ),
),
```

## 🔧 Imports Adicionados

Todas as páginas admin agora importam `dart:convert`:

```dart
import 'dart:convert';
```

Isso permite fazer o parse manual do JSON quando necessário.

## 📝 Arquivos Modificados

1. `Front/lib/features/admin/presentation/pages/admin_dashboard_page.dart`
2. `Front/lib/features/admin/presentation/pages/admin_missions_management_page.dart`
3. `Front/lib/features/admin/presentation/pages/admin_categories_management_page.dart`
4. `Front/lib/features/settings/presentation/pages/settings_page.dart`

## 🎯 Benefícios

1. **Robustez**: O código agora lida com diferentes formatos de resposta
2. **Fallback**: Se a resposta vier como String, faz parse automático
3. **Sem quebra**: Mantém compatibilidade com respostas já parseadas
4. **Navegação correta**: Usuários admin agora acessam o dashboard completo

## 🧪 Como Testar

1. Fazer login como usuário admin (`is_staff=True` ou `is_superuser=True`)
2. Ir para Settings (Configurações)
3. Clicar em "Administração"
4. Verificar se o dashboard carrega sem erros
5. Navegar para "Gerenciar Missões"
6. Navegar para "Gerenciar Categorias"

## ⚠️ Nota Importante

Se o erro persistir, verificar:

1. **Backend está rodando**: `python manage.py runserver`
2. **Endpoint existe**: `GET /admin/stats/overview/`
3. **Usuário tem permissão**: `is_staff=True` no banco
4. **Token JWT válido**: Fazer novo login se necessário

## 🔍 Debug Adicional

Se precisar verificar o tipo de resposta:

```dart
try {
  final response = await _apiClient.client.get('/admin/stats/overview/');
  print('Response type: ${response.data.runtimeType}');
  print('Response data: ${response.data}');
} catch (e) {
  print('Error: $e');
}
```

Isso ajudará a identificar exatamente o formato da resposta.
