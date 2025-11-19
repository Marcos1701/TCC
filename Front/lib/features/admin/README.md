# Widgets e Utilitários Admin - Frontend

Este diretório contém componentes reutilizáveis e utilitários para as páginas administrativas do aplicativo Flutter.

## Objetivo

Eliminar duplicação de código nas páginas admin, melhorar manutenibilidade e garantir consistência visual.

## Estrutura

```
admin/presentation/
├── widgets/          # Widgets reutilizáveis
├── utils/            # Funções auxiliares
├── mixins/           # Mixins para comportamentos comuns
└── pages/            # Páginas administrativas
```

## Widgets Disponíveis

### AdminSectionHeader
Cabeçalho estilizado para seções de formulários/páginas.

**Uso:**
```dart
AdminSectionHeader(
  title: 'Informações Básicas',
  icon: Icons.info_outline,
)
```

**Substitui:** Múltiplas implementações do método `_buildSectionHeader`

---

### AdminStatRow
Linha para exibir estatísticas (label + valor).

**Uso:**
```dart
AdminStatRow(
  label: 'Total de Usuários',
  value: 150,
  icon: Icons.people,
)
```

**Substitui:** Método `_buildStatRow` duplicado

---

### AdminEmptyState
Estado vazio para listas sem dados.

**Uso:**
```dart
AdminEmptyState(
  icon: Icons.inbox,
  title: 'Nenhum resultado encontrado',
  subtitle: 'Tente ajustar os filtros',
  onAction: () => _loadData(),
  actionLabel: 'Recarregar',
)
```

**Substitui:** Múltiplas implementações de estados vazios

---

### AdminErrorState
Estado de erro com botão de retry.

**Uso:**
```dart
AdminErrorState(
  error: 'Falha ao carregar dados',
  onRetry: _loadData,
)
```

**Substitui:** Método `_buildError` duplicado

---

### AdminFilterChip
Chip de filtro selecionável.

**Uso:**
```dart
AdminFilterChip(
  label: 'Ativo',
  icon: Icons.check_circle,
  isSelected: _filterActive,
  onTap: () => setState(() => _filterActive = !_filterActive),
)
```

**Substitui:** Método `_buildChipFilter` duplicado

---

### AdminLabeledDropdown
Dropdown com label estilizado.

**Uso:**
```dart
AdminLabeledDropdown<String>(
  label: 'Dificuldade',
  value: _difficulty,
  items: [
    DropdownMenuItem(value: 'EASY', child: Text('Fácil')),
    DropdownMenuItem(value: 'MEDIUM', child: Text('Médio')),
  ],
  onChanged: (value) => setState(() => _difficulty = value!),
)
```

**Substitui:** Método `_buildLabeledDropdown` duplicado

---

### AdminTextField
Campo de texto com label estilizado.

**Uso:**
```dart
AdminTextField(
  label: 'Título',
  controller: _titleController,
  validator: (v) => v?.isEmpty ?? true ? 'Obrigatório' : null,
)
```

**Substitui:** Método `_buildTextField` duplicado

---

### AdminMetricCard
Card para exibir métrica no dashboard.

**Uso:**
```dart
AdminMetricCard(
  title: 'Total Usuários',
  value: '1,234',
  icon: Icons.people,
  color: AppColors.primary,
  subtitle: 'Ativos',
)
```

**Substitui:** Classe interna `_MetricCard`

---

## Utilitários (admin_helpers.dart)

### Funções de parsing seguro

```dart
// Obter int seguro
int total = getSafeInt(data, 'total_users');

// Obter double seguro
double avg = getSafeDouble(data, 'average_level');

// Obter string segura
String name = getSafeString(data, 'username', defaultValue: 'Anônimo');

// Obter lista segura
List<String> tags = getSafeList<String>(data, 'tags');
```

**Substitui:** Métodos `getSafeInt`, `getSafeValue`, etc duplicados

---

## Mixin (AdminPageMixin)

Comportamentos comuns para páginas admin:

```dart
class _MyAdminPageState extends State<MyAdminPage> with AdminPageMixin {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await executeAdminAction(
      () async {
        final response = await apiClient.client.get('/api/admin/data/');
        // processar dados
      },
      successMessage: 'Dados carregados',
      onSuccess: () => print('Sucesso!'),
    );
  }
}
```

**Funcionalidades:**
- `startLoading()` - Inicia estado de loading
- `setError(String)` - Define erro
- `setSuccess()` - Define sucesso
- `parseResponse(dynamic)` - Parse JSON seguro
- `executeAdminAction()` - Executa ação com tratamento de erro

**Substitui:** Lógica duplicada de loading/error em cada página

---

## Importação Simplificada

Use o arquivo barrel para importar todos os widgets:

```dart
import '../widgets/admin_widgets.dart';
import '../utils/admin_helpers.dart';
import '../mixins/admin_page_mixin.dart';
```

---

## Benefícios

✅ **Redução de código duplicado** - Centenas de linhas eliminadas  
✅ **Manutenibilidade** - Alterações em um único lugar  
✅ **Consistência** - UI uniforme em todas as páginas admin  
✅ **Testabilidade** - Widgets isolados mais fáceis de testar  
✅ **Reutilização** - Componentes prontos para novas páginas  

---

## Próximos Passos

1. Refatorar páginas existentes para usar os novos widgets
2. Adicionar testes unitários para widgets
3. Documentar exemplos de uso em Storybook (futuro)
4. Criar variantes de widgets conforme necessário
