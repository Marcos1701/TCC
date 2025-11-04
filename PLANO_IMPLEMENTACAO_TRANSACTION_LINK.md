# 📋 Plano de Implementação: Sistema de Vinculação de Transações (TransactionLink)

## 📊 Visão Geral

Este documento detalha o plano completo de implementação do sistema de vinculação de transações, incluindo todas as adaptações necessárias nos modelos, serializers, views, services e interface do usuário.

## 🎯 Objetivos

1. ✅ Eliminar duplicação de dados no pagamento de dívidas
2. ✅ Criar rastreabilidade completa entre receitas e despesas
3. ✅ Corrigir cálculo de indicadores (TPS, RDR, ILI)
4. ✅ Melhorar drasticamente a UX
5. ✅ Adicionar automação para pagamentos recorrentes

---

## 📅 Cronograma Geral

### **Fase 1: Backend Base** (Semana 1-2)
- Criar modelo e migrations
- Implementar serializers básicos
- Criar ViewSet e endpoints principais
- Testes unitários

### **Fase 2: Lógica de Negócio** (Semana 3)
- Atualizar cálculo de indicadores
- Implementar vinculação automática recorrente
- Testes de integração
- Otimizações de performance

### **Fase 3: Frontend Base** (Semana 4-5)
- Criar tela de pagamento de dívidas
- Implementar widgets de seleção
- Validações em tempo real
- Feedback visual

### **Fase 4: Features Avançadas** (Semana 6-7)
- Sugestões inteligentes
- Templates de pagamento
- Histórico e relatórios
- Dashboard de dívidas

### **Fase 5: Refinamento e Deploy** (Semana 8)
- Testes end-to-end
- Otimizações finais
- Documentação
- Deploy

---

## 🔧 FASE 1: BACKEND BASE

### 1.1. Criar Modelo TransactionLink

**Arquivo:** `Api/finance/models.py`

**Localização:** Adicionar após o modelo `Transaction`

```python
class TransactionLink(models.Model):
    """
    Representa uma vinculação entre transações que se anulam parcial ou totalmente.
    Usado principalmente para pagamento de dívidas: vincular receita → dívida.
    
    Exemplo:
    - Receita (Salário) R$ 5.000 → Dívida (Cartão) R$ 2.000
    - Após vinculação:
      - Salário tem R$ 3.000 disponíveis
      - Cartão tem R$ 0 devendo
    """
    
    class LinkType(models.TextChoices):
        DEBT_PAYMENT = "DEBT_PAYMENT", "Pagamento de dívida"
        INTERNAL_TRANSFER = "INTERNAL_TRANSFER", "Transferência interna"
        SAVINGS_ALLOCATION = "SAVINGS_ALLOCATION", "Alocação para poupança"
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transaction_links',
        help_text="Usuário proprietário da vinculação"
    )
    
    # Transação de origem (de onde vem o dinheiro)
    source_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='outgoing_links',
        help_text="Transação de origem (normalmente uma receita)"
    )
    
    # Transação de destino (para onde vai o dinheiro)
    target_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='incoming_links',
        help_text="Transação de destino (normalmente uma dívida)"
    )
    
    # Valor vinculado (pode ser parcial)
    linked_amount = models.DecimalField(
        max_digits=12,
        decimal_places=2,
        help_text="Valor que está sendo transferido/vinculado"
    )
    
    link_type = models.CharField(
        max_length=20,
        choices=LinkType.choices,
        default=LinkType.DEBT_PAYMENT
    )
    
    # Metadados
    description = models.CharField(
        max_length=255,
        blank=True,
        help_text="Descrição opcional da vinculação"
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    # Vincular recorrências se aplicável
    is_recurring = models.BooleanField(
        default=False,
        help_text="Se True, vincular automaticamente transações recorrentes futuras"
    )
    
    class Meta:
        ordering = ('-created_at',)
        indexes = [
            models.Index(fields=['user', 'created_at']),
            models.Index(fields=['source_transaction']),
            models.Index(fields=['target_transaction']),
        ]
        # Prevenir vinculações duplicadas
        constraints = [
            models.CheckConstraint(
                check=models.Q(linked_amount__gt=0),
                name='linked_amount_positive'
            )
        ]
    
    def __str__(self) -> str:
        return f"{self.source_transaction.description} → {self.target_transaction.description} (R$ {self.linked_amount})"
    
    def clean(self):
        """Validações personalizadas."""
        from django.core.exceptions import ValidationError
        
        # Validar que source e target pertencem ao mesmo usuário
        if self.source_transaction.user != self.target_transaction.user:
            raise ValidationError("As transações devem pertencer ao mesmo usuário.")
        
        # Validar que user da vinculação é o mesmo das transações
        if self.user != self.source_transaction.user:
            raise ValidationError("Usuário da vinculação deve ser o mesmo das transações.")
        
        # Validar que linked_amount não excede o disponível na source
        if self.linked_amount > self.source_transaction.available_amount:
            raise ValidationError(
                f"Valor vinculado (R$ {self.linked_amount}) excede o disponível na transação de origem (R$ {self.source_transaction.available_amount})"
            )
        
        # Validar que linked_amount não excede o devido na target (se for dívida)
        if self.target_transaction.category and self.target_transaction.category.type == Category.CategoryType.DEBT:
            if self.linked_amount > self.target_transaction.available_amount:
                raise ValidationError(
                    f"Valor vinculado (R$ {self.linked_amount}) excede o devido na dívida (R$ {self.target_transaction.available_amount})"
                )
    
    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)
```

**Impacto:**
- ✅ Novo modelo para rastrear vinculações
- ✅ Validações garantem integridade dos dados
- ✅ Suporta diferentes tipos de vinculação (extensível)

---

### 1.2. Adicionar Properties ao Modelo Transaction

**Arquivo:** `Api/finance/models.py`

**Localização:** Dentro da classe `Transaction`, adicionar após o método `__str__`:

```python
    @property
    def linked_amount(self) -> Decimal:
        """
        Retorna o valor total vinculado desta transação.
        - Para receitas (source): soma dos outgoing_links
        - Para dívidas (target): soma dos incoming_links
        """
        from django.db.models import Sum
        
        # Soma links de saída (quando esta é a source)
        outgoing = self.outgoing_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        # Soma links de entrada (quando esta é a target)
        incoming = self.incoming_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        # Para receitas, usar outgoing; para dívidas, usar incoming
        if self.type == self.TransactionType.INCOME:
            return outgoing
        elif self.category and self.category.type == Category.CategoryType.DEBT:
            return incoming
        
        return Decimal('0')
    
    @property
    def available_amount(self) -> Decimal:
        """
        Retorna o valor disponível desta transação (não vinculado).
        - Para receitas: amount - linked_amount (quanto ainda pode ser usado)
        - Para dívidas: amount - linked_amount (quanto ainda deve)
        """
        return self.amount - self.linked_amount
    
    @property
    def link_percentage(self) -> Decimal:
        """
        Retorna o percentual vinculado (0-100).
        Útil para exibir barras de progresso.
        """
        if self.amount == 0:
            return Decimal('0')
        return (self.linked_amount / self.amount) * Decimal('100')
```

**Impacto:**
- ✅ Cálculo automático de valores vinculados
- ✅ Fácil verificar saldo disponível
- ✅ Suporte a pagamentos parciais

---

### 1.3. Criar Migration

**Comando:** 
```bash
cd Api
python manage.py makemigrations finance
python manage.py migrate finance
```

**Verificações:**
- ✅ Migration criada sem erros
- ✅ Índices criados corretamente
- ✅ Constraints aplicadas

---

### 1.4. Criar Serializers

**Arquivo:** `Api/finance/serializers.py`

**Localização:** Adicionar no final do arquivo:

```python
class TransactionLinkSerializer(serializers.ModelSerializer):
    """Serializer para TransactionLink."""
    
    # Campos read-only nested
    source_transaction = TransactionSerializer(read_only=True)
    target_transaction = TransactionSerializer(read_only=True)
    
    # Campos write-only para criação
    source_id = serializers.IntegerField(write_only=True)
    target_id = serializers.IntegerField(write_only=True)
    
    # Campos calculados
    source_description = serializers.SerializerMethodField()
    target_description = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    
    class Meta:
        model = TransactionLink
        fields = (
            'id',
            'source_transaction',
            'target_transaction',
            'source_id',
            'target_id',
            'linked_amount',
            'link_type',
            'description',
            'is_recurring',
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
        )
        read_only_fields = (
            'created_at',
            'updated_at',
            'source_description',
            'target_description',
            'formatted_amount',
        )
    
    def get_source_description(self, obj):
        return obj.source_transaction.description if obj.source_transaction else None
    
    def get_target_description(self, obj):
        return obj.target_transaction.description if obj.target_transaction else None
    
    def get_formatted_amount(self, obj):
        return f"R$ {obj.linked_amount:,.2f}".replace(',', 'X').replace('.', ',').replace('X', '.')
    
    def validate(self, attrs):
        """Validações customizadas."""
        from .models import Transaction
        
        request = self.context.get('request')
        if not request:
            raise serializers.ValidationError("Request context is required.")
        
        user = request.user
        source_id = attrs.get('source_id')
        target_id = attrs.get('target_id')
        linked_amount = attrs.get('linked_amount')
        
        # Validar que source existe e pertence ao usuário
        try:
            source = Transaction.objects.get(id=source_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"source_id": "Transação de origem não encontrada."})
        
        # Validar que target existe e pertence ao usuário
        try:
            target = Transaction.objects.get(id=target_id, user=user)
        except Transaction.DoesNotExist:
            raise serializers.ValidationError({"target_id": "Transação de destino não encontrada."})
        
        # Validar que linked_amount não excede disponível na source
        if linked_amount > source.available_amount:
            raise serializers.ValidationError({
                "linked_amount": f"Valor excede o disponível na receita (R$ {source.available_amount})"
            })
        
        # Validar que linked_amount não excede devido na target (se for dívida)
        if target.category and target.category.type == 'DEBT':
            if linked_amount > target.available_amount:
                raise serializers.ValidationError({
                    "linked_amount": f"Valor excede o devido na dívida (R$ {target.available_amount})"
                })
        
        # Adicionar transações ao attrs para uso no create()
        attrs['source_transaction'] = source
        attrs['target_transaction'] = target
        
        return attrs
    
    def create(self, validated_data):
        """Criar vinculação."""
        from .services import invalidate_indicators_cache
        
        # Remover campos write-only
        validated_data.pop('source_id', None)
        validated_data.pop('target_id', None)
        
        # Adicionar usuário
        request = self.context.get('request')
        validated_data['user'] = request.user
        
        # Criar link
        link = TransactionLink.objects.create(**validated_data)
        
        # Invalidar cache de indicadores
        invalidate_indicators_cache(request.user)
        
        return link


class TransactionLinkSummarySerializer(serializers.Serializer):
    """Serializer para resumo de vinculações por transação."""
    transaction_id = serializers.IntegerField()
    transaction_description = serializers.CharField()
    transaction_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    linked_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    available_amount = serializers.DecimalField(max_digits=12, decimal_places=2)
    link_percentage = serializers.DecimalField(max_digits=5, decimal_places=2)
```

**Impacto:**
- ✅ Validações robustas no nível de serializer
- ✅ Campos calculados para facilitar exibição
- ✅ Invalidação automática de cache

---

### 1.5. Atualizar TransactionSerializer

**Arquivo:** `Api/finance/serializers.py`

**Localização:** Dentro da classe `TransactionSerializer`, adicionar campos:

```python
class TransactionSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)
    category_id = serializers.PrimaryKeyRelatedField(
        queryset=Category.objects.none(), source="category", write_only=True, allow_null=True, required=False
    )
    # Campos calculados read-only
    recurrence_description = serializers.SerializerMethodField()
    days_since_created = serializers.SerializerMethodField()
    formatted_amount = serializers.SerializerMethodField()
    
    # NOVOS CAMPOS para vinculação
    linked_amount = serializers.SerializerMethodField()
    available_amount = serializers.SerializerMethodField()
    link_percentage = serializers.SerializerMethodField()
    outgoing_links_count = serializers.SerializerMethodField()
    incoming_links_count = serializers.SerializerMethodField()
    
    class Meta:
        model = Transaction
        fields = (
            "id",
            "type",
            "description",
            "amount",
            "date",
            "category",
            "category_id",
            "is_recurring",
            "recurrence_value",
            "recurrence_unit",
            "recurrence_end_date",
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            # Novos campos
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
            "created_at",
            "updated_at",
        )
        read_only_fields = (
            "recurrence_description",
            "days_since_created",
            "formatted_amount",
            "linked_amount",
            "available_amount",
            "link_percentage",
            "outgoing_links_count",
            "incoming_links_count",
            "created_at",
            "updated_at",
        )
    
    # ... métodos existentes ...
    
    def get_linked_amount(self, obj):
        """Retorna valor total vinculado."""
        return float(obj.linked_amount)
    
    def get_available_amount(self, obj):
        """Retorna valor disponível (não vinculado)."""
        return float(obj.available_amount)
    
    def get_link_percentage(self, obj):
        """Retorna percentual vinculado."""
        return float(obj.link_percentage)
    
    def get_outgoing_links_count(self, obj):
        """Retorna número de links de saída."""
        return obj.outgoing_links.count()
    
    def get_incoming_links_count(self, obj):
        """Retorna número de links de entrada."""
        return obj.incoming_links.count()
```

**Impacto:**
- ✅ Transações agora expõem informações de vinculação
- ✅ Frontend pode exibir saldo disponível
- ✅ Fácil identificar transações vinculadas

---

## 🔧 FASE 2: LÓGICA DE NEGÓCIO

### 2.1. Atualizar Cálculo de Indicadores

**Arquivo:** `Api/finance/services.py`

**Localização:** Modificar função `calculate_summary`

**Problema Atual:**
```python
# TPS atual está considerando pagamentos de dívida como despesa separada
# Isso causa dupla contagem quando receita é usada para pagar dívida
savings = income - expense - debt_payments
tps = (savings / income) * Decimal("100")
```

**Solução:**
```python
def calculate_summary(user) -> Dict[str, Decimal]:
    """
    Calcula os indicadores financeiros principais do usuário.
    ATUALIZADO: Considera apenas transações não-vinculadas para evitar dupla contagem.
    
    Lógica:
    - TPS: Calcula economia usando apenas receitas e despesas livres (não vinculadas)
    - RDR: Calcula comprometimento usando total vinculado para dívidas
    - ILI: Mantém lógica atual (não afetado)
    """
    from django.db.models import Sum, Q
    from .models import TransactionLink
    
    # Verificar cache
    profile, _ = UserProfile.objects.get_or_create(user=user)
    if not profile.should_recalculate_indicators():
        return {
            "tps": profile.cached_tps or Decimal("0.00"),
            "rdr": profile.cached_rdr or Decimal("0.00"),
            "ili": profile.cached_ili or Decimal("0.00"),
            "total_income": profile.cached_total_income or Decimal("0.00"),
            "total_expense": profile.cached_total_expense or Decimal("0.00"),
            "total_debt": profile.cached_total_debt or Decimal("0.00"),
        }
    
    # ============================================================================
    # CÁLCULO ATUALIZADO: Considerar vinculações
    # ============================================================================
    
    # Total de receitas (bruto)
    total_income = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.INCOME
        ).aggregate(total=Sum('amount'))['total']
    )
    
    # Total de despesas normais (não-dívida, bruto)
    total_expense = _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
        ).exclude(
            category__type=Category.CategoryType.DEBT
        ).aggregate(total=Sum('amount'))['total']
    )
    
    # Total vinculado para pagamento de dívidas
    # Soma de todos os links onde target é uma dívida
    debt_payments_via_links = _decimal(
        TransactionLink.objects.filter(
            user=user,
            link_type=TransactionLink.LinkType.DEBT_PAYMENT
        ).aggregate(total=Sum('linked_amount'))['total']
    )
    
    # Calcular reserva de emergência (mantém lógica atual)
    reserve_transactions = Transaction.objects.filter(
        user=user, 
        category__group=Category.CategoryGroup.SAVINGS
    ).values("type").annotate(total=Sum("amount"))
    
    reserve_deposits = Decimal("0")
    reserve_withdrawals = Decimal("0")
    
    for item in reserve_transactions:
        tx_type = item["type"]
        total = _decimal(item["total"])
        if tx_type == Transaction.TransactionType.INCOME:
            reserve_deposits += total
        elif tx_type == Transaction.TransactionType.EXPENSE:
            reserve_withdrawals += total
    
    # Calcular média de despesas essenciais (mantém lógica atual)
    today = timezone.now().date()
    three_months_ago = today - timedelta(days=90)
    essential_expense_total = _decimal(
        Transaction.objects.filter(
            user=user,
            category__group=Category.CategoryGroup.ESSENTIAL_EXPENSE,
            type=Transaction.TransactionType.EXPENSE,
            date__gte=three_months_ago,
            date__lte=today,
        ).aggregate(total=Sum("amount"))["total"]
    )
    essential_expense = essential_expense_total / Decimal("3") if essential_expense_total > 0 else Decimal("0")
    
    # ============================================================================
    # CÁLCULO DOS INDICADORES - NOVA ABORDAGEM
    # ============================================================================
    
    tps = Decimal("0")
    rdr = Decimal("0")
    ili = Decimal("0")
    
    if total_income > 0:
        # TPS (Taxa de Poupança Pessoal) - CORRIGIDO
        # Fórmula: ((Receitas - Despesas - Pagamentos Dívida Vinculados) / Receitas) × 100
        # Agora usa pagamentos REAIS via vinculação, não duplica
        savings = total_income - total_expense - debt_payments_via_links
        tps = (savings / total_income) * Decimal("100")
        
        # RDR (Razão Dívida/Renda) - CORRIGIDO
        # Fórmula: (Pagamentos Dívida Vinculados / Receitas) × 100
        # Agora usa valor REAL pago via vinculação
        rdr = (debt_payments_via_links / total_income) * Decimal("100")
    
    # ILI (Índice de Liquidez Imediata) - MANTÉM LÓGICA ATUAL
    reserve_balance = reserve_deposits - reserve_withdrawals
    if essential_expense > 0:
        ili = reserve_balance / essential_expense
    
    # Total de dívidas (saldo devedor atual)
    debt_info = _debt_components(user)
    debt_total = debt_info["balance"] if debt_info["balance"] > 0 else Decimal("0")
    
    # Atualizar cache
    profile.cached_tps = tps.quantize(Decimal("0.01"))
    profile.cached_rdr = rdr.quantize(Decimal("0.01"))
    profile.cached_ili = ili.quantize(Decimal("0.01"))
    profile.cached_total_income = total_income.quantize(Decimal("0.01"))
    profile.cached_total_expense = total_expense.quantize(Decimal("0.01"))
    profile.cached_total_debt = debt_total.quantize(Decimal("0.01"))
    profile.indicators_updated_at = timezone.now()
    profile.save(update_fields=[
        'cached_tps', 
        'cached_rdr', 
        'cached_ili', 
        'cached_total_income',
        'cached_total_expense',
        'cached_total_debt',
        'indicators_updated_at'
    ])
    
    return {
        "tps": profile.cached_tps,
        "rdr": profile.cached_rdr,
        "ili": profile.cached_ili,
        "total_income": profile.cached_total_income,
        "total_expense": profile.cached_total_expense,
        "total_debt": profile.cached_total_debt,
    }
```

**Impacto:**
- ✅ Elimina dupla contagem em TPS e RDR
- ✅ Indicadores refletem realidade financeira
- ✅ Compatível com abordagem anterior

---

### 2.2. Criar Função de Vinculação Automática Recorrente

**Arquivo:** `Api/finance/services.py`

**Localização:** Adicionar nova função:

```python
def auto_link_recurring_transactions(user) -> int:
    """
    Vincula automaticamente transações recorrentes baseado em configuração.
    
    Lógica:
    1. Buscar todos os TransactionLinks com is_recurring=True do usuário
    2. Para cada link recorrente:
       - Verificar se existem novas instâncias das transações recorrentes
       - Criar links automáticos entre as novas instâncias
    
    Returns:
        Número de links criados automaticamente
    """
    from .models import Transaction, TransactionLink
    from datetime import timedelta
    
    links_created = 0
    
    # Buscar links recorrentes ativos
    recurring_links = TransactionLink.objects.filter(
        user=user,
        is_recurring=True
    ).select_related('source_transaction', 'target_transaction')
    
    for link in recurring_links:
        source = link.source_transaction
        target = link.target_transaction
        
        # Verificar se ambas são recorrentes
        if not (source.is_recurring and target.is_recurring):
            continue
        
        # Buscar próximas instâncias das transações recorrentes
        # que ainda não foram vinculadas
        
        # Calcular data esperada da próxima instância
        if source.recurrence_unit == Transaction.RecurrenceUnit.DAYS:
            delta = timedelta(days=source.recurrence_value)
        elif source.recurrence_unit == Transaction.RecurrenceUnit.WEEKS:
            delta = timedelta(weeks=source.recurrence_value)
        elif source.recurrence_unit == Transaction.RecurrenceUnit.MONTHS:
            delta = timedelta(days=source.recurrence_value * 30)  # Aproximado
        else:
            continue
        
        # Buscar transações similares criadas após a original
        next_sources = Transaction.objects.filter(
            user=user,
            type=source.type,
            category=source.category,
            description=source.description,
            amount=source.amount,
            date__gt=source.date,
            is_recurring=True,
        ).exclude(
            # Excluir transações já vinculadas
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('source_transaction_id', flat=True)
        )
        
        next_targets = Transaction.objects.filter(
            user=user,
            category=target.category,
            description=target.description,
            amount=target.amount,
            date__gt=target.date,
            is_recurring=True,
        ).exclude(
            id__in=TransactionLink.objects.filter(
                user=user,
                link_type=link.link_type
            ).values_list('target_transaction_id', flat=True)
        )
        
        # Criar links entre pares correspondentes
        for next_source in next_sources[:1]:  # Uma por vez
            for next_target in next_targets[:1]:
                # Verificar se há saldo disponível
                if next_source.available_amount >= link.linked_amount:
                    if next_target.available_amount >= link.linked_amount:
                        # Criar link automático
                        TransactionLink.objects.create(
                            user=user,
                            source_transaction=next_source,
                            target_transaction=next_target,
                            linked_amount=link.linked_amount,
                            link_type=link.link_type,
                            description=f"Auto: {link.description}",
                            is_recurring=True
                        )
                        links_created += 1
    
    # Invalidar cache se criou links
    if links_created > 0:
        invalidate_indicators_cache(user)
    
    return links_created
```

**Impacto:**
- ✅ Automação de pagamentos recorrentes
- ✅ Reduz trabalho manual do usuário
- ✅ Mantém consistência temporal

---

### 2.3. Criar TransactionLinkViewSet

**Arquivo:** `Api/finance/views.py`

**Localização:** Adicionar no final:

```python
class TransactionLinkViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciar vinculações entre transações.
    
    Endpoints:
    - GET /transaction-links/ - Listar vinculações
    - POST /transaction-links/ - Criar vinculação
    - GET /transaction-links/{id}/ - Detalhe de vinculação
    - DELETE /transaction-links/{id}/ - Remover vinculação
    - GET /transaction-links/available_sources/ - Listar receitas disponíveis
    - GET /transaction-links/available_targets/ - Listar dívidas pendentes
    - POST /transaction-links/quick_link/ - Vincular rapidamente
    - GET /transaction-links/payment_report/ - Relatório de pagamentos
    """
    serializer_class = TransactionLinkSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        qs = TransactionLink.objects.filter(
            user=self.request.user
        ).select_related(
            'source_transaction',
            'target_transaction',
            'source_transaction__category',
            'target_transaction__category'
        )
        
        # Filtros
        link_type = self.request.query_params.get('link_type')
        if link_type:
            qs = qs.filter(link_type=link_type)
        
        date_from = self.request.query_params.get('date_from')
        if date_from:
            qs = qs.filter(created_at__gte=date_from)
        
        date_to = self.request.query_params.get('date_to')
        if date_to:
            qs = qs.filter(created_at__lte=date_to)
        
        return qs.order_by('-created_at')
    
    def perform_destroy(self, instance):
        """Ao deletar, invalidar cache de indicadores."""
        user = instance.user
        instance.delete()
        invalidate_indicators_cache(user)
    
    @action(detail=False, methods=['get'])
    def available_sources(self, request):
        """
        Lista receitas que ainda têm saldo disponível.
        
        Query params:
        - min_amount: Filtrar receitas com saldo >= min_amount
        - category: Filtrar por categoria
        """
        min_amount = request.query_params.get('min_amount', 0)
        
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        ).select_related('category')
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        # Filtrar apenas com saldo disponível
        available = [tx for tx in transactions if tx.available_amount > Decimal(min_amount)]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def available_targets(self, request):
        """
        Lista dívidas que ainda têm saldo devedor.
        
        Query params:
        - max_amount: Filtrar dívidas com saldo <= max_amount
        - category: Filtrar por categoria
        """
        transactions = Transaction.objects.filter(
            user=request.user,
            category__type=Category.CategoryType.DEBT
        ).select_related('category')
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            transactions = transactions.filter(category_id=category_id)
        
        # Filtrar apenas com saldo devedor
        max_amount = request.query_params.get('max_amount')
        available = [
            tx for tx in transactions 
            if tx.available_amount > 0 and (not max_amount or tx.available_amount <= Decimal(max_amount))
        ]
        
        serializer = TransactionSerializer(available, many=True, context={'request': request})
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def quick_link(self, request):
        """
        Criar vinculação rapidamente com validações.
        
        Payload:
        {
            "source_id": 123,
            "target_id": 456,
            "amount": "150.00",
            "link_type": "DEBT_PAYMENT",  # opcional
            "description": "...",  # opcional
            "is_recurring": false  # opcional
        }
        """
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        link = serializer.save()
        
        return Response(
            TransactionLinkSerializer(link, context={'request': request}).data,
            status=status.HTTP_201_CREATED
        )
    
    @action(detail=False, methods=['get'])
    def payment_report(self, request):
        """
        Gera relatório de pagamentos de dívidas por período.
        
        Query params:
        - start_date: Data inicial (YYYY-MM-DD)
        - end_date: Data final (YYYY-MM-DD)
        - category: Filtrar por categoria de dívida
        
        Response:
        {
            "summary": {
                "total_paid": "5000.00",
                "total_remaining": "15000.00",
                "payment_count": 10
            },
            "by_debt": [
                {
                    "debt_id": 123,
                    "debt_description": "Cartão de Crédito",
                    "total_amount": "2000.00",
                    "paid_amount": "800.00",
                    "remaining_amount": "1200.00",
                    "payment_percentage": 40.0,
                    "payments": [...]
                }
            ]
        }
        """
        from django.db.models import Sum
        from collections import defaultdict
        
        # Filtros de data
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        links = TransactionLink.objects.filter(
            user=request.user,
            link_type=TransactionLink.LinkType.DEBT_PAYMENT
        ).select_related('target_transaction', 'target_transaction__category')
        
        if start_date:
            links = links.filter(created_at__gte=start_date)
        if end_date:
            links = links.filter(created_at__lte=end_date)
        
        # Filtrar por categoria se fornecido
        category_id = request.query_params.get('category')
        if category_id:
            links = links.filter(target_transaction__category_id=category_id)
        
        # Agrupar por dívida
        by_debt = defaultdict(lambda: {
            'debt_id': None,
            'debt_description': '',
            'total_amount': Decimal('0'),
            'paid_amount': Decimal('0'),
            'remaining_amount': Decimal('0'),
            'payment_percentage': Decimal('0'),
            'payments': []
        })
        
        total_paid = Decimal('0')
        
        for link in links:
            debt = link.target_transaction
            debt_id = debt.id
            
            if by_debt[debt_id]['debt_id'] is None:
                by_debt[debt_id]['debt_id'] = debt_id
                by_debt[debt_id]['debt_description'] = debt.description
                by_debt[debt_id]['total_amount'] = debt.amount
            
            by_debt[debt_id]['paid_amount'] += link.linked_amount
            total_paid += link.linked_amount
            
            by_debt[debt_id]['payments'].append({
                'id': link.id,
                'amount': float(link.linked_amount),
                'date': link.created_at.isoformat(),
                'source': link.source_transaction.description
            })
        
        # Calcular remaining e percentage
        total_remaining = Decimal('0')
        for debt_data in by_debt.values():
            debt_data['remaining_amount'] = debt_data['total_amount'] - debt_data['paid_amount']
            total_remaining += debt_data['remaining_amount']
            
            if debt_data['total_amount'] > 0:
                debt_data['payment_percentage'] = float(
                    (debt_data['paid_amount'] / debt_data['total_amount']) * Decimal('100')
                )
        
        return Response({
            'summary': {
                'total_paid': float(total_paid),
                'total_remaining': float(total_remaining),
                'payment_count': links.count()
            },
            'by_debt': list(by_debt.values())
        })
```

**Impacto:**
- ✅ API completa para gerenciar vinculações
- ✅ Endpoints especializados facilitam frontend
- ✅ Relatórios prontos para uso

---

### 2.4. Registrar URLs

**Arquivo:** `Api/finance/urls.py`

**Localização:** Adicionar no router:

```python
from rest_framework.routers import DefaultRouter

router = DefaultRouter()
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'transactions', TransactionViewSet, basename='transaction')
router.register(r'transaction-links', TransactionLinkViewSet, basename='transactionlink')  # NOVO
router.register(r'goals', GoalViewSet, basename='goal')
router.register(r'missions', MissionViewSet, basename='mission')
router.register(r'mission-progress', MissionProgressViewSet, basename='missionprogress')

urlpatterns = router.urls
```

---

### 2.5. Atualizar Django Admin

**Arquivo:** `Api/finance/admin.py`

**Localização:** Adicionar:

```python
from django.contrib import admin
from .models import Category, Goal, Mission, MissionProgress, Transaction, TransactionLink, UserProfile

# ... código existente ...

@admin.register(TransactionLink)
class TransactionLinkAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'source_description', 'target_description', 'linked_amount', 'link_type', 'created_at')
    list_filter = ('link_type', 'is_recurring', 'created_at')
    search_fields = ('user__username', 'description', 'source_transaction__description', 'target_transaction__description')
    readonly_fields = ('created_at', 'updated_at')
    date_hierarchy = 'created_at'
    
    def source_description(self, obj):
        return obj.source_transaction.description
    source_description.short_description = 'Origem'
    
    def target_description(self, obj):
        return obj.target_transaction.description
    target_description.short_description = 'Destino'
```

---

## 🎨 FASE 3: FRONTEND BASE

### 3.1. Criar Modelo TransactionLink

**Arquivo:** `Front/lib/core/models/transaction_link.dart`

```dart
import 'package:decimal/decimal.dart';
import 'transaction.dart';

class TransactionLinkModel {
  final int id;
  final TransactionModel? sourceTransaction;
  final TransactionModel? targetTransaction;
  final Decimal linkedAmount;
  final String linkType;
  final String? description;
  final bool isRecurring;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionLinkModel({
    required this.id,
    this.sourceTransaction,
    this.targetTransaction,
    required this.linkedAmount,
    required this.linkType,
    this.description,
    required this.isRecurring,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionLinkModel.fromJson(Map<String, dynamic> json) {
    return TransactionLinkModel(
      id: json['id'] as int,
      sourceTransaction: json['source_transaction'] != null
          ? TransactionModel.fromJson(json['source_transaction'] as Map<String, dynamic>)
          : null,
      targetTransaction: json['target_transaction'] != null
          ? TransactionModel.fromJson(json['target_transaction'] as Map<String, dynamic>)
          : null,
      linkedAmount: Decimal.parse(json['linked_amount'].toString()),
      linkType: json['link_type'] as String,
      description: json['description'] as String?,
      isRecurring: json['is_recurring'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'linked_amount': linkedAmount.toString(),
      'link_type': linkType,
      'description': description,
      'is_recurring': isRecurring,
    };
  }
}

class CreateTransactionLinkRequest {
  final int sourceId;
  final int targetId;
  final Decimal amount;
  final String? linkType;
  final String? description;
  final bool? isRecurring;

  const CreateTransactionLinkRequest({
    required this.sourceId,
    required this.targetId,
    required this.amount,
    this.linkType,
    this.description,
    this.isRecurring,
  });

  Map<String, dynamic> toJson() {
    return {
      'source_id': sourceId,
      'target_id': targetId,
      'amount': amount.toString(),
      if (linkType != null) 'link_type': linkType,
      if (description != null) 'description': description,
      if (isRecurring != null) 'is_recurring': isRecurring,
    };
  }
}
```

---

### 3.2. Atualizar Modelo Transaction

**Arquivo:** `Front/lib/core/models/transaction.dart`

**Adicionar campos:**

```dart
class TransactionModel {
  // ... campos existentes ...
  
  final double? linkedAmount;
  final double? availableAmount;
  final double? linkPercentage;
  final int? outgoingLinksCount;
  final int? incomingLinksCount;

  const TransactionModel({
    // ... parâmetros existentes ...
    this.linkedAmount,
    this.availableAmount,
    this.linkPercentage,
    this.outgoingLinksCount,
    this.incomingLinksCount,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      // ... campos existentes ...
      linkedAmount: json['linked_amount'] != null ? (json['linked_amount'] as num).toDouble() : null,
      availableAmount: json['available_amount'] != null ? (json['available_amount'] as num).toDouble() : null,
      linkPercentage: json['link_percentage'] != null ? (json['link_percentage'] as num).toDouble() : null,
      outgoingLinksCount: json['outgoing_links_count'] as int?,
      incomingLinksCount: json['incoming_links_count'] as int?,
    );
  }
  
  bool get hasLinks => (outgoingLinksCount ?? 0) > 0 || (incomingLinksCount ?? 0) > 0;
  bool get hasAvailableAmount => availableAmount != null && availableAmount! > 0;
}
```

---

### 3.3. Atualizar FinanceRepository

**Arquivo:** `Front/lib/core/repositories/finance_repository.dart`

**Adicionar métodos:**

```dart
class FinanceRepository {
  // ... código existente ...
  
  /// Buscar receitas com saldo disponível
  Future<List<TransactionModel>> fetchAvailableIncomes({double? minAmount}) async {
    try {
      final queryParams = <String, String>{};
      if (minAmount != null) {
        queryParams['min_amount'] = minAmount.toString();
      }
      
      final uri = Uri.parse('$_baseUrl/transaction-links/available_sources/')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: await _headers());
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => TransactionModel.fromJson(json)).toList();
      }
      throw Exception('Falha ao carregar receitas disponíveis');
    } catch (e) {
      print('Erro ao buscar receitas disponíveis: $e');
      rethrow;
    }
  }
  
  /// Buscar dívidas pendentes
  Future<List<TransactionModel>> fetchPendingDebts({double? maxAmount}) async {
    try {
      final queryParams = <String, String>{};
      if (maxAmount != null) {
        queryParams['max_amount'] = maxAmount.toString();
      }
      
      final uri = Uri.parse('$_baseUrl/transaction-links/available_targets/')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: await _headers());
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => TransactionModel.fromJson(json)).toList();
      }
      throw Exception('Falha ao carregar dívidas pendentes');
    } catch (e) {
      print('Erro ao buscar dívidas pendentes: $e');
      rethrow;
    }
  }
  
  /// Criar vinculação
  Future<TransactionLinkModel> createTransactionLink(CreateTransactionLinkRequest request) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/transaction-links/quick_link/'),
        headers: await _headers(),
        body: json.encode(request.toJson()),
      );
      
      if (response.statusCode == 201) {
        return TransactionLinkModel.fromJson(json.decode(response.body));
      }
      
      final error = json.decode(response.body);
      throw Exception(error.toString());
    } catch (e) {
      print('Erro ao criar vinculação: $e');
      rethrow;
    }
  }
  
  /// Deletar vinculação
  Future<void> deleteTransactionLink(int linkId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/transaction-links/$linkId/'),
        headers: await _headers(),
      );
      
      if (response.statusCode != 204) {
        throw Exception('Falha ao deletar vinculação');
      }
    } catch (e) {
      print('Erro ao deletar vinculação: $e');
      rethrow;
    }
  }
  
  /// Listar vinculações
  Future<List<TransactionLinkModel>> fetchTransactionLinks({
    String? linkType,
    String? dateFrom,
    String? dateTo,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (linkType != null) queryParams['link_type'] = linkType;
      if (dateFrom != null) queryParams['date_from'] = dateFrom;
      if (dateTo != null) queryParams['date_to'] = dateTo;
      
      final uri = Uri.parse('$_baseUrl/transaction-links/')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: await _headers());
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => TransactionLinkModel.fromJson(json)).toList();
      }
      throw Exception('Falha ao carregar vinculações');
    } catch (e) {
      print('Erro ao buscar vinculações: $e');
      rethrow;
    }
  }
  
  /// Buscar relatório de pagamentos
  Future<Map<String, dynamic>> fetchPaymentReport({
    String? startDate,
    String? endDate,
    int? categoryId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      if (categoryId != null) queryParams['category'] = categoryId.toString();
      
      final uri = Uri.parse('$_baseUrl/transaction-links/payment_report/')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(uri, headers: await _headers());
      
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Falha ao carregar relatório');
    } catch (e) {
      print('Erro ao buscar relatório: $e');
      rethrow;
    }
  }
}
```

---

## 📝 Próximos Passos

Este plano de implementação cobre as fases 1-3 em detalhes. As fases 4-5 (features avançadas e refinamento) serão documentadas separadamente com base no progresso das fases iniciais.

### ✅ Checklist Rápido

**Backend:**
- [ ] Modelo TransactionLink criado
- [ ] Properties em Transaction adicionadas
- [ ] Migration executada
- [ ] Serializers implementados
- [ ] ViewSet completo
- [ ] URLs registradas
- [ ] calculate_summary atualizado
- [ ] Testes criados

**Frontend:**
- [ ] Modelo TransactionLink criado
- [ ] Transaction atualizado
- [ ] FinanceRepository atualizado
- [ ] DebtPaymentScreen criada
- [ ] Widgets de seleção criados
- [ ] Validações implementadas
- [ ] Navegação configurada

### 📊 Métricas de Sucesso

1. **Backend:** Todos os testes passando (cobertura > 80%)
2. **Indicadores:** TPS e RDR calculados corretamente sem dupla contagem
3. **Performance:** Endpoints respondendo em < 500ms
4. **UX:** Fluxo de pagamento completado em < 30 segundos
5. **Adoção:** 80%+ dos usuários usam vinculação em vez de cadastro manual

---

**Última atualização:** 04/11/2025
**Responsável:** Equipe de Desenvolvimento TCC
**Status:** 🚧 Em Planejamento
