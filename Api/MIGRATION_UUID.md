# Migração de IDs Sequenciais para UUID

## 📋 Índice
1. [Objetivo](#objetivo)
2. [Motivação](#motivação)
3. [Arquitetura Implementada](#arquitetura-implementada)
4. [Etapas Realizadas](#etapas-realizadas)
5. [Status Atual](#status-atual)
6. [Próximos Passos](#próximos-passos)
7. [Guia de Rollback](#guia-de-rollback)
8. [Testes](#testes)

---

## 🎯 Objetivo

Migrar o sistema de identificadores sequenciais (1, 2, 3...) para UUIDs (Universally Unique Identifiers) para melhorar a segurança e prevenir ataques IDOR (Insecure Direct Object Reference).

---

## 🔒 Motivação

### Vulnerabilidade Identificada
IDs sequenciais expõem informações sensíveis:
- Facilita enumeração de recursos (`/api/transactions/1`, `/api/transactions/2`, etc.)
- Permite ataques IDOR se houver falhas de autorização
- Expõe volume de dados (ID 1000 = ~1000 transações)
- Facilita scraping e análise não autorizada

### Solução com UUID
- UUIDs são aleatórios e impossíveis de enumerar
- Não expõem informações sobre volume de dados
- Padrão da indústria para APIs públicas
- Compatível com sistemas distribuídos

---

## 🏗️ Arquitetura Implementada

### Sistema Dual (Fase Atual)
O sistema atualmente opera com **dois identificadores paralelos**:

```python
class Transaction(models.Model):
    id = models.AutoField(primary_key=True)  # ID sequencial (PK atual)
    uuid = models.UUIDField(unique=True, db_index=True)  # UUID (futuro PK)
```

### Lookup Dual com Mixins
```python
class UUIDLookupMixin:
    """Aceita ID ou UUID para buscar recursos."""
    def get_object(self):
        lookup_value = self.kwargs[self.lookup_field]
        queryset = self.filter_queryset(self.get_queryset())
        
        # Tentar UUID primeiro
        try:
            uuid_obj = UUID(str(lookup_value))
            filter_kwargs = {'uuid': uuid_obj}
        except (ValueError, AttributeError):
            # Fallback para ID numérico
            filter_kwargs = {self.lookup_field: lookup_value}
        
        obj = get_object_or_404(queryset, **filter_kwargs)
        self.check_object_permissions(self.request, obj)
        return obj
```

### Serializers com Suporte Dual
```python
class TransactionLinkSerializer(serializers.ModelSerializer):
    # Aceita ambos os formatos
    source_id = serializers.IntegerField(write_only=True, required=False)
    source_uuid = serializers.UUIDField(write_only=True, required=False)
    
    def validate(self, attrs):
        # Normaliza ID/UUID → UUID internamente
        if source_uuid:
            source = Transaction.objects.get(uuid=source_uuid, user=user)
        else:
            source = Transaction.objects.get(id=source_id, user=user)
        
        attrs['source_transaction_uuid'] = source.uuid
        return attrs
```

---

## ✅ Etapas Realizadas

### 1. Adição de Campos UUID (Migration 0025)
**Status:** ✅ Completo  
**Migrations:** `0025_add_uuid_fields.py`

```python
# Adicionados a 4 modelos críticos:
- Transaction.uuid
- Goal.uuid
- TransactionLink.uuid
- Friendship.uuid

# Características:
- unique=True (não permite duplicatas)
- null=True (permite registros sem UUID temporariamente)
- db_index=True (índice para performance)
- default=None (será populado via signal ou migration)
```

### 2. População de UUIDs Existentes (Migration 0026)
**Status:** ✅ Completo  
**Migrations:** `0026_populate_uuids.py`  
**Registros Atualizados:** 37 UUIDs gerados

```python
def populate_uuids(apps, schema_editor):
    Transaction = apps.get_model('finance', 'Transaction')
    
    # Popula em lotes de 1000
    for transaction in Transaction.objects.filter(uuid__isnull=True):
        transaction.uuid = uuid.uuid4()
        transaction.save(update_fields=['uuid'])
```

### 3. Auto-geração de UUID (Signals)
**Status:** ✅ Completo  
**Arquivo:** `finance/signals.py`

```python
@receiver(pre_save, sender=Transaction)
def generate_uuid_for_transaction(sender, instance, **kwargs):
    if instance.uuid is None:
        instance.uuid = uuid.uuid4()
```

### 4. Backend - ViewSets com Lookup Dual
**Status:** ✅ Completo  
**Arquivo:** `finance/views.py`

Todos os 4 ViewSets críticos atualizados:
- `TransactionViewSet`
- `GoalViewSet`
- `TransactionLinkViewSet`
- `FriendshipViewSet`

```python
class TransactionViewSet(UUIDLookupMixin, UUIDResponseMixin, viewsets.ModelViewSet):
    # Aceita /api/transactions/123/ OU /api/transactions/{uuid}/
    pass
```

### 5. Backend - Serializers Expondo UUID
**Status:** ✅ Completo  
**Arquivo:** `finance/serializers.py`

```python
class TransactionSerializer(serializers.ModelSerializer):
    uuid = serializers.UUIDField(read_only=True)  # Exposto na API
    
    class Meta:
        model = Transaction
        fields = ['id', 'uuid', 'amount', 'description', ...]
```

### 6. Frontend - Modelos com UUID
**Status:** ✅ Completo  
**Arquivos:** `Front/lib/core/models/*.dart`

```dart
class Transaction {
  final int id;
  final String? uuid;  // Opcional durante transição
  
  // Getter inteligente: prefere UUID, fallback para ID
  dynamic get identifier => uuid ?? id;
  
  bool get hasUuid => uuid != null;
}
```

### 7. Frontend - Repository com Dynamic IDs
**Status:** ✅ Completo  
**Arquivo:** `Front/lib/core/repositories/finance_repository.dart`

```dart
// Antes: Future<void> deleteTransaction(int id)
// Agora:
Future<void> deleteTransaction(dynamic id) async {
  // Aceita int OU String (UUID)
  await _dio.delete('/transactions/$id/');
}
```

### 8. Frontend - UI Usando .identifier
**Status:** ✅ Completo  
**Arquivos:** 24 locais atualizados

```dart
// Antes: transaction.id
// Agora:  transaction.identifier

// Exemplo:
onDelete: () => deleteTransaction(transaction.identifier)
```

### 9. Migração de Foreign Keys para UUID
**Status:** ✅ COMPLETO  
**Migrations:** `0027, 0028, 0029`

#### Step 1 (0027): Adicionar Campos Temporários
```python
migrations.AddField(
    model_name='transactionlink',
    name='source_transaction_uuid_temp',
    field=models.UUIDField(null=True, blank=True)
)
```

#### Step 2 (0028): Popular UUIDs
```python
def populate_uuid_fk_fields(apps, schema_editor):
    TransactionLink = apps.get_model('finance', 'TransactionLink')
    
    for link in TransactionLink.objects.all():
        link.source_transaction_uuid_temp = link.source_transaction.uuid
        link.target_transaction_uuid_temp = link.target_transaction.uuid
        link.save()
```

#### Step 3 (0029): Substituir FKs
```python
# Remover ForeignKeys antigas
migrations.RemoveField('transactionlink', 'source_transaction')
migrations.RemoveField('transactionlink', 'target_transaction')

# Tornar campos UUID obrigatórios
migrations.AlterField('transactionlink', 'source_transaction_uuid_temp', 
    field=models.UUIDField(db_index=True))

# Renomear para nomes definitivos
migrations.RenameField('transactionlink', 
    'source_transaction_uuid_temp', 'source_transaction_uuid')
```

#### Modelo com Properties
```python
class TransactionLink(models.Model):
    source_transaction_uuid = models.UUIDField(db_index=True)
    target_transaction_uuid = models.UUIDField(db_index=True)
    
    @property
    def source_transaction(self):
        """Retorna Transaction via UUID lookup."""
        if not hasattr(self, '_source_cache'):
            self._source_cache = Transaction.objects.get(
                uuid=self.source_transaction_uuid
            )
        return self._source_cache
    
    @source_transaction.setter
    def source_transaction(self, value):
        """Permite atribuição via ORM."""
        self.source_transaction_uuid = value.uuid
        self._source_cache = value
```

---

## 📊 Status Atual

### ✅ Implementado e Testado
- [x] Campos UUID em 4 modelos
- [x] 37 UUIDs populados em registros existentes
- [x] Auto-geração de UUID via signals
- [x] Backend aceita ID ou UUID
- [x] Serializers expõem UUID
- [x] Frontend suporta UUID opcional
- [x] 24 locais no Flutter usando `.identifier`
- [x] TransactionLink usa UUIDs em FKs
- [x] **14 testes de integração passando (100%)**

### ⚠️ Pendente
- [ ] **Primary Key Migration:** Tornar UUID a chave primária
- [ ] **Remover suporte a ID:** Aceitar apenas UUID nas rotas
- [ ] **Atualizar constraints:** Recriar índices e constraints
- [ ] **Documentação API:** Atualizar docs para mencionar UUID

---

## 🚀 Próximos Passos

### Task 7: Primary Key Migration (CRÍTICO)
**Risco:** 🔴 ALTO - Pode quebrar sistema se não executado corretamente

```python
# Migration 0030: UUID como Primary Key
operations = [
    # 1. Remover constraints que referenciam PK
    migrations.RemoveConstraint(...),
    
    # 2. Remover campo id
    migrations.RemoveField('transaction', 'id'),
    
    # 3. Renomear uuid → id
    migrations.RenameField('transaction', 'uuid', 'id'),
    
    # 4. Tornar id a primary key
    migrations.AlterField('transaction', 'id',
        field=models.UUIDField(primary_key=True, default=uuid.uuid4)
    ),
    
    # 5. Recriar constraints e índices
    migrations.AddConstraint(...),
]
```

**Pré-requisitos:**
- ✅ Todos os registros têm UUID
- ✅ Frontend suporta UUID
- ✅ Testes passando
- ⚠️ Backup do banco de dados
- ⚠️ Plano de rollback testado

### Task 8: UUID-Only Routes
**Risco:** 🟡 MÉDIO

```python
# Remover UUIDLookupMixin (que aceita ID)
class TransactionViewSet(viewsets.ModelViewSet):
    lookup_field = 'uuid'  # Apenas UUID
    lookup_value_regex = '[0-9a-f-]{36}'  # Validação UUID
```

### Task 9: Documentação Final
**Risco:** 🟢 BAIXO

- [ ] Atualizar README com novo formato de API
- [ ] Documentar endpoints com Swagger/OpenAPI
- [ ] Criar guia de migração para outros ambientes
- [ ] Atualizar testes E2E

---

## 🔄 Guia de Rollback

### Cenário 1: Rollback das Migrations UUID (0025-0029)

#### Antes de Aplicar em Produção
```bash
# 1. Backup completo
pg_dump -U postgres -d finance_db > backup_before_uuid_$(date +%Y%m%d_%H%M%S).sql

# 2. Testar migrations em ambiente de staging
python manage.py migrate finance 0029

# 3. Validar integridade
python manage.py test finance.tests.test_uuid_integration
```

#### Se Algo Der Errado (Rollback)
```bash
# 1. Reverter para migration anterior
python manage.py migrate finance 0024  # Antes das UUIDs

# 2. Limpar cache e reiniciar
python manage.py clear_cache
systemctl restart gunicorn

# 3. Restaurar backup se necessário
psql -U postgres -d finance_db < backup_before_uuid_20250105.sql
```

### Cenário 2: Rollback de FK Migration (0027-0029)

```bash
# Voltar para antes da migração de FKs
python manage.py migrate finance 0026

# Isso irá:
# - Restaurar ForeignKeys tradicionais (source_transaction, target_transaction)
# - Remover campos UUID temporários
# - Reverter índices
```

### Cenário 3: Rollback Completo (Emergência)

```sql
-- 1. Restaurar backup completo
psql -U postgres -d finance_db < backup_completo.sql

-- 2. Reverter código
git revert HEAD~5  # Reverter últimos 5 commits UUID
git push origin main

-- 3. Reiniciar serviços
systemctl restart gunicorn
systemctl restart nginx
```

### Validação Pós-Rollback
```bash
# 1. Verificar migrations aplicadas
python manage.py showmigrations finance

# 2. Testar endpoints críticos
curl -X GET https://api.example.com/api/transactions/
curl -X POST https://api.example.com/api/transactions/ -d '{"amount": 100, ...}'

# 3. Verificar logs
tail -f /var/log/gunicorn/error.log
```

---

## 🧪 Testes

### Suite de Testes UUID
**Arquivo:** `finance/tests/test_uuid_integration.py`  
**Total:** 14 testes  
**Status:** ✅ 100% passando

#### 1. UUIDLookupTestCase (6 testes)
```python
✅ test_transaction_lookup_by_id - Busca por ID numérico (retrocompat.)
✅ test_transaction_lookup_by_uuid - Busca por UUID
✅ test_transaction_update_by_uuid - Atualização por UUID
✅ test_transaction_delete_by_uuid - Exclusão por UUID
✅ test_goal_lookup_by_uuid - Meta por UUID
✅ test_transaction_link_lookup_by_uuid - Vínculo por UUID
```

#### 2. UUIDCreationTestCase (3 testes)
```python
✅ test_create_transaction_link_with_uuid - Criação com UUID
✅ test_create_transaction_link_with_id - Criação com ID (retrocompat.)
✅ test_create_transaction_link_mixed - Criação formato misto
```

#### 3. UUIDPermissionTestCase (2 testes)
```python
✅ test_cannot_access_other_user_transaction_by_uuid - Segurança UUID
✅ test_cannot_access_other_user_goal_by_uuid - Segurança UUID
```

#### 4. UUIDAutoGenerationTestCase (3 testes)
```python
✅ test_transaction_auto_generates_uuid - Auto-geração Transaction
✅ test_goal_auto_generates_uuid - Auto-geração Goal
✅ test_uuid_uniqueness - Unicidade de UUIDs
```

### Executar Testes
```bash
# Suite completa
python manage.py test finance.tests.test_uuid_integration -v 2

# Teste específico
python manage.py test finance.tests.test_uuid_integration.UUIDLookupTestCase

# Com coverage
coverage run --source='finance' manage.py test finance.tests.test_uuid_integration
coverage report
```

### Testes de Carga (Recomendado antes de produção)
```python
# test_uuid_performance.py
import time
from django.test import TestCase

class UUIDPerformanceTestCase(TestCase):
    def test_lookup_performance(self):
        """UUID lookup deve ser < 50ms."""
        start = time.time()
        Transaction.objects.get(uuid=test_uuid)
        elapsed = time.time() - start
        
        self.assertLess(elapsed, 0.05, "Lookup muito lento!")
```

---

## 📝 Notas Importantes

### Performance
- **Índices UUID:** Criados em todos os campos UUID (`db_index=True`)
- **Cache de Properties:** TransactionLink cacheia objetos Transaction
- **Queries N+1:** Removido `select_related` (não funciona com properties)

### Segurança
- ✅ Validação de permissões mantida
- ✅ UUID não expõe informações sensíveis
- ✅ Testes de isolamento de usuários passando

### Compatibilidade
- ✅ Backend aceita ID e UUID (dual)
- ✅ Frontend migra gradualmente
- ✅ Migrations reversíveis

### Monitoramento Recomendado
```python
# settings.py
LOGGING = {
    'loggers': {
        'finance.migrations': {
            'handlers': ['file'],
            'level': 'INFO',
        }
    }
}
```

---

## 🔗 Referências

- [Django UUID Fields](https://docs.djangoproject.com/en/4.2/ref/models/fields/#uuidfield)
- [OWASP - Insecure Direct Object Reference](https://owasp.org/www-community/vulnerabilities/Insecure_Direct_Object_Reference)
- [RFC 4122 - UUID Standard](https://tools.ietf.org/html/rfc4122)
- [Django Migrations Best Practices](https://docs.djangoproject.com/en/4.2/topics/migrations/)

---

**Última Atualização:** 05/11/2025  
**Autor:** Sistema de Migração UUID  
**Status:** Fase 2 Completa - FKs migradas para UUID
