# Checklist de Migração UUID - Problemas Pendentes

## ✅ Completado

### Backend (Django)
- [x] Campos UUID adicionados aos 4 modelos críticos
- [x] UUIDs populados para 37 registros existentes
- [x] Signals configurados para auto-geração de UUIDs
- [x] Serializers expondo campo `uuid`
- [x] ViewSets aceitam lookup por ID ou UUID
- [x] Mixins criados (UUIDLookupMixin, UUIDResponseMixin)

### Frontend (Flutter)
- [x] Modelos atualizados com campo `uuid` opcional
- [x] `FinanceRepository` aceita `dynamic` (int ou String)
- [x] Helpers criados (`identifier`, `hasUuid`)
- [x] TransactionsViewModel usando `identifier`

---

## ⚠️ PROBLEMAS PENDENTES (Críticos)

### 1. **Foreign Keys ainda apontam para ID numérico**

**Localização:** `Api/finance/models.py`

```python
# TransactionLink
source_transaction = models.ForeignKey(
    Transaction,
    on_delete=models.CASCADE,
    related_name='outgoing_links',  # ← Aponta para Transaction.id
)
target_transaction = models.ForeignKey(
    Transaction,
    on_delete=models.CASCADE,
    related_name='incoming_links',  # ← Aponta para Transaction.id
)

# Goal
target_category = models.ForeignKey(
    Category,
    on_delete=models.SET_NULL,  # ← OK, Category não tem UUID
    null=True,
    blank=True,
    related_name="goals",
)
```

**Impacto:** Quando UUID virar PK, todas as FKs quebram.

**Solução:** Criar migration para alterar FKs de `id` → `uuid`:
```python
# Etapas necessárias:
1. Criar campo FK temporário apontando para UUID
2. Popular FK temporário com base no UUID
3. Remover FK antiga (id)
4. Renomear FK temporário para nome original
```

---

### 2. **Flutter ainda usa `.id` em vez de `.identifier` em 24 locais**

**Arquivos afetados:**

#### ViewModels (ALTA PRIORIDADE)
- ✅ `transactions_viewmodel.dart` - linha 147 (PARCIALMENTE CORRIGIDO)
- ❌ `goals_viewmodel.dart` - linha 75 usa `goal.id`

#### UI Pages (MÉDIA PRIORIDADE)
- ❌ `friends_page.dart` - linha 270: `friendship.id`
- ❌ `goal_details_page.dart` - linhas 81, 85, 122, 409: `goal.id`
- ❌ `progress_page.dart` - linhas 776, 869: `goal.id`
- ❌ `transactions_page.dart` - linha 129: `link.id`
- ❌ `edit_transaction_sheet.dart` - linha 89: `transaction.id`
- ❌ `transaction_details_sheet.dart` - linhas 52, 102: `transaction.id`

**Solução:** Substituir todos `.id` por `.identifier`:

```dart
// ❌ Antes
await _repository.deleteGoal(goal.id);

// ✅ Depois
await _repository.deleteGoal(goal.identifier);
```

---

### 3. **Serializers ainda enviam `source_id` e `target_id` numéricos**

**Localização:** `Api/finance/serializers.py` - `TransactionLinkSerializer`

```python
class TransactionLinkSerializer(serializers.ModelSerializer):
    # Campos write-only para criação
    source_id = serializers.IntegerField(write_only=True)  # ← Problema
    target_id = serializers.IntegerField(write_only=True)  # ← Problema
```

**Impacto:** Frontend envia IDs numéricos ao criar links, não UUIDs.

**Solução:** Criar campos alternativos que aceitem ambos:
```python
source_id = serializers.IntegerField(write_only=True, required=False)
source_uuid = serializers.UUIDField(write_only=True, required=False)
target_id = serializers.IntegerField(write_only=True, required=False)
target_uuid = serializers.UUIDField(write_only=True, required=False)

def validate(self, attrs):
    if not (attrs.get('source_id') or attrs.get('source_uuid')):
        raise ValidationError("source_id or source_uuid required")
    # ...
```

---

### 4. **CreateTransactionLinkRequest usa IDs numéricos**

**Localização:** `Front/lib/core/models/transaction_link.dart`

```dart
class CreateTransactionLinkRequest {
  final int sourceId;  // ← Problema
  final int targetId;  // ← Problema
  
  Map<String, dynamic> toMap() {
    return {
      'source_id': sourceId,  // ← Envia int
      'target_id': targetId,  // ← Envia int
    };
  }
}
```

**Solução:** Aceitar ambos os formatos:
```dart
class CreateTransactionLinkRequest {
  final dynamic sourceId;  // int ou String
  final dynamic targetId;  // int ou String
  
  Map<String, dynamic> toMap() {
    return {
      if (sourceId is String) 'source_uuid': sourceId,
      if (sourceId is int) 'source_id': sourceId,
      if (targetId is String) 'target_uuid': targetId,
      if (targetId is int) 'target_id': targetId,
    };
  }
}
```

---

### 5. **Indexes ainda usam campo `id`**

**Localização:** `Api/finance/models.py` - Meta classes

```python
class Meta:
    indexes = [
        models.Index(fields=['user', 'date']),  # OK
        models.Index(fields=['user', 'type']),  # OK
        # Mas queries filtram por id, não uuid ainda
    ]
```

**Impacto:** Quando UUID virar PK, queries por ID param de funcionar.

**Solução:** Adicionar índices compostos incluindo UUID:
```python
models.Index(fields=['user', 'uuid']),
models.Index(fields=['uuid']),  # Já existe, mas verificar
```

---

### 6. **URL patterns esperam inteiros**

**Localização:** `Api/finance/urls.py`

```python
# Rotas atuais aceitam qualquer formato devido aos ViewSets
# MAS: Após migração, precisam validar UUID
router.register(r'transactions', TransactionViewSet, basename='transaction')
```

**Solução:** Adicionar validação de UUID nos padrões de URL (após migração):
```python
from django.urls import path, re_path

# Após migração para UUID como PK:
re_path(
    r'^transactions/(?P<pk>[0-9a-f-]{36})/$',
    TransactionViewSet.as_view({'get': 'retrieve'}),
)
```

---

### 7. **Testes não validam comportamento UUID**

**Impacto:** Sem testes, migração é arriscada.

**Solução:** Criar testes de integração:
```python
# test_uuid_migration.py
def test_lookup_by_uuid():
    transaction = Transaction.objects.create(...)
    response = client.get(f'/api/transactions/{transaction.uuid}/')
    assert response.status_code == 200

def test_lookup_by_id_still_works():
    transaction = Transaction.objects.create(...)
    response = client.get(f'/api/transactions/{transaction.id}/')
    assert response.status_code == 200
```

---

### 8. **Cache usa IDs como chave**

**Localização:** `Front/lib/core/services/cache_manager.dart`

```dart
// Se cache usa transaction.id como chave, quebrará após migração
```

**Solução:** Revisar todas as chaves de cache para usar UUID quando disponível.

---

## 📋 ORDEM DE IMPLEMENTAÇÃO RECOMENDADA

### Fase 1: Correções Críticas (ANTES da migração de PK)
1. ✅ ~~Atualizar todos `.id` para `.identifier` no Flutter~~
2. ✅ ~~Adicionar suporte a `source_uuid` e `target_uuid` nos serializers~~
3. ✅ ~~Atualizar `CreateTransactionLinkRequest` para enviar UUID~~
4. ✅ ~~Revisar e corrigir uso de cache~~

### Fase 2: Testes Extensivos
5. ✅ Criar testes de integração para lookup dual (ID + UUID)
6. ✅ Testar criação/edição/exclusão com UUID
7. ✅ Testar vinculações de transações com UUID

### Fase 3: Migração do Primary Key (BREAKING CHANGE)
8. ⚠️ Backup completo do banco
9. ⚠️ Criar migration complexa:
   - Remover constraints que referenciam `id`
   - Criar FKs temporárias apontando para `uuid`
   - Popular FKs temporárias
   - Remover campo `id`
   - Renomear `uuid` para `id` (ou manter como `uuid`)
   - Recriar indexes e constraints
10. ⚠️ Atualizar todos os serializers para usar apenas UUID
11. ⚠️ Remover suporte a lookup por ID numérico

### Fase 4: Limpeza
12. Remover campos legados
13. Atualizar documentação
14. Criar guia de rollback

---

## 🚨 RISCOS E MITIGAÇÕES

### Risco 1: Perda de dados durante migração de FK
**Mitigação:** Criar FK paralela antes de remover antiga

### Risco 2: Frontend para de funcionar após migração
**Mitigação:** Manter suporte dual (ID + UUID) por 2-3 versões

### Risco 3: Performance degradada com UUIDs
**Mitigação:** Garantir índices otimizados, usar UUID v4 ordenado se possível

### Risco 4: Impossibilidade de rollback
**Mitigação:** Criar script de rollback detalhado + backup antes da migração

---

## 📊 ESTIMATIVA DE ESFORÇO

- **Fase 1 (Correções):** 4-6 horas
- **Fase 2 (Testes):** 3-4 horas  
- **Fase 3 (Migração PK):** 8-12 horas + teste extensivo
- **Fase 4 (Limpeza):** 2-3 horas

**Total:** ~20-25 horas de trabalho técnico + tempo de teste em produção

---

## ✅ PRÓXIMOS PASSOS IMEDIATOS

1. **Corrigir todos os `.id` no Flutter** (substituir por `.identifier`)
2. **Adicionar suporte UUID nos serializers de criação**
3. **Criar testes básicos de lookup dual**
4. **Fazer backup do banco antes de qualquer migração**
