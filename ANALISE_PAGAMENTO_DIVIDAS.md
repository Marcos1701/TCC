# Análise e Proposta: Sistema de Pagamento de Dívidas

## 📋 Análise da Implementação Atual

### Problemas Identificados

1. **Duplicação de Dados**
   - Atualmente, o usuário precisa cadastrar manualmente um pagamento de dívida (`DEBT_PAYMENT`)
   - Isso não está vinculado diretamente à receita que está sendo usada para pagar
   - Não há rastreabilidade entre a origem do dinheiro e o destino

2. **Falta de Vínculo entre Transações**
   - Receitas e pagamentos de dívidas são entidades independentes
   - Não existe um modelo de "transferência" ou "vinculação" entre transações
   - Dificulta análise de fluxo de caixa real

3. **Complexidade para o Usuário**
   - Usuário precisa lembrar:
     - Quanto recebeu
     - Qual categoria de receita
     - Quanto pagou de dívida
     - Registrar duas vezes informações relacionadas

4. **Inconsistências Potenciais**
   - Usuário pode esquecer de registrar o pagamento após registrar a receita
   - Valores podem não corresponder exatamente
   - Dificulta reconciliação financeira

5. **Recorrência Desconectada**
   - Se uma receita é recorrente e usada para pagar uma dívida recorrente, não há vinculação automática
   - Usuário precisa gerenciar ambas as recorrências separadamente

## 🎯 Proposta de Solução: Sistema de Vinculação de Transações

### Conceito Principal

Transformar o pagamento de dívidas em uma **operação de vinculação** entre duas transações que se anulam parcial ou totalmente, similar a uma transferência interna, mas com impacto nos indicadores financeiros.

### Arquitetura Proposta

#### 1. Novo Modelo: `TransactionLink`

```python
class TransactionLink(models.Model):
    """
    Representa uma vinculação entre transações (ex: receita usada para pagar dívida).
    Funciona como uma transferência que anula transações parcial ou totalmente.
    """
    
    class LinkType(models.TextChoices):
        DEBT_PAYMENT = "DEBT_PAYMENT", "Pagamento de dívida"
        TRANSFER = "TRANSFER", "Transferência"
        SAVINGS_ALLOCATION = "SAVINGS_ALLOCATION", "Alocação para poupança"
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='transaction_links'
    )
    
    # Transação de origem (de onde vem o dinheiro)
    source_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='outgoing_links'
    )
    
    # Transação de destino (para onde vai o dinheiro)
    target_transaction = models.ForeignKey(
        Transaction,
        on_delete=models.CASCADE,
        related_name='incoming_links'
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
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['source_transaction']),
            models.Index(fields=['target_transaction']),
        ]
    
    def __str__(self):
        return f"{self.source_transaction.description} → {self.target_transaction.description} (R$ {self.linked_amount})"
    
    def clean(self):
        """Validações de negócio."""
        from django.core.exceptions import ValidationError
        
        # Verificar se as transações pertencem ao mesmo usuário
        if self.source_transaction.user != self.user or self.target_transaction.user != self.user:
            raise ValidationError("As transações devem pertencer ao usuário da vinculação.")
        
        # Verificar tipos de transação compatíveis
        if self.link_type == self.LinkType.DEBT_PAYMENT:
            # Origem deve ser receita ou categoria de poupança
            if self.source_transaction.type not in [Transaction.TransactionType.INCOME]:
                raise ValidationError("Origem deve ser uma receita para pagamento de dívida.")
            
            # Destino deve ser despesa de categoria DEBT
            if (self.target_transaction.type != Transaction.TransactionType.EXPENSE or
                self.target_transaction.category.type != Category.CategoryType.DEBT):
                raise ValidationError("Destino deve ser uma dívida (despesa de categoria DEBT).")
        
        # Verificar se o valor vinculado não excede os totais
        if self.linked_amount > self.source_transaction.amount:
            raise ValidationError("Valor vinculado não pode exceder o valor da transação de origem.")
        
        if self.linked_amount > self.target_transaction.amount:
            raise ValidationError("Valor vinculado não pode exceder o valor da transação de destino.")
        
        # Verificar se não há sobre-vinculação (valor já vinculado)
        source_linked = TransactionLink.objects.filter(
            source_transaction=self.source_transaction
        ).exclude(id=self.id).aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        if source_linked + self.linked_amount > self.source_transaction.amount:
            raise ValidationError(
                f"Receita já tem R$ {source_linked} vinculados. "
                f"Disponível: R$ {self.source_transaction.amount - source_linked}"
            )
        
        target_linked = TransactionLink.objects.filter(
            target_transaction=self.target_transaction
        ).exclude(id=self.id).aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
        
        if target_linked + self.linked_amount > self.target_transaction.amount:
            raise ValidationError(
                f"Dívida já tem R$ {target_linked} pagos. "
                f"Restante: R$ {self.target_transaction.amount - target_linked}"
            )
```

#### 2. Campos Adicionais no Modelo `Transaction`

```python
class Transaction(models.Model):
    # ... campos existentes ...
    
    # Novos campos calculados
    @property
    def linked_amount_source(self) -> Decimal:
        """Total vinculado saindo desta transação."""
        return self.outgoing_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
    
    @property
    def linked_amount_target(self) -> Decimal:
        """Total vinculado entrando nesta transação."""
        return self.incoming_links.aggregate(
            total=Sum('linked_amount')
        )['total'] or Decimal('0')
    
    @property
    def available_amount(self) -> Decimal:
        """Valor disponível para vincular (receitas) ou valor não pago (dívidas)."""
        if self.type == Transaction.TransactionType.INCOME:
            return self.amount - self.linked_amount_source
        elif self.category and self.category.type == Category.CategoryType.DEBT:
            return self.amount - self.linked_amount_target
        return self.amount
    
    @property
    def is_fully_linked(self) -> bool:
        """Verifica se a transação está totalmente vinculada."""
        return self.available_amount <= Decimal('0')
    
    @property
    def payment_status(self) -> str:
        """Status de pagamento para dívidas."""
        if self.category and self.category.type == Category.CategoryType.DEBT:
            if self.linked_amount_target == 0:
                return "pending"  # Não paga
            elif self.linked_amount_target < self.amount:
                return "partial"  # Parcialmente paga
            else:
                return "paid"  # Totalmente paga
        return "not_applicable"
```

#### 3. Serializers

```python
class TransactionLinkSerializer(serializers.ModelSerializer):
    source_transaction = TransactionSerializer(read_only=True)
    target_transaction = TransactionSerializer(read_only=True)
    source_transaction_id = serializers.PrimaryKeyRelatedField(
        queryset=Transaction.objects.none(),
        source='source_transaction',
        write_only=True
    )
    target_transaction_id = serializers.PrimaryKeyRelatedField(
        queryset=Transaction.objects.none(),
        source='target_transaction',
        write_only=True
    )
    
    class Meta:
        model = TransactionLink
        fields = [
            'id', 'source_transaction', 'target_transaction',
            'source_transaction_id', 'target_transaction_id',
            'linked_amount', 'link_type', 'description',
            'is_recurring', 'created_at', 'updated_at'
        ]
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            # Limitar transações ao usuário
            self.fields['source_transaction_id'].queryset = Transaction.objects.filter(
                user=request.user
            )
            self.fields['target_transaction_id'].queryset = Transaction.objects.filter(
                user=request.user
            )
    
    def validate(self, attrs):
        """Validações customizadas."""
        attrs = super().validate(attrs)
        
        # Criar instância temporária para validação
        instance = TransactionLink(**attrs, user=self.context['request'].user)
        instance.clean()  # Chama as validações do modelo
        
        return attrs
    
    def create(self, validated_data):
        validated_data['user'] = self.context['request'].user
        return super().create(validated_data)


class TransactionSerializer(serializers.ModelSerializer):
    # ... campos existentes ...
    
    # Novos campos calculados
    linked_amount_source = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    linked_amount_target = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    available_amount = serializers.DecimalField(
        max_digits=12, decimal_places=2, read_only=True
    )
    is_fully_linked = serializers.BooleanField(read_only=True)
    payment_status = serializers.CharField(read_only=True)
    
    # Links relacionados
    outgoing_links = TransactionLinkSerializer(many=True, read_only=True)
    incoming_links = TransactionLinkSerializer(many=True, read_only=True)
    
    class Meta:
        model = Transaction
        fields = [
            # ... campos existentes ...
            'linked_amount_source', 'linked_amount_target',
            'available_amount', 'is_fully_linked', 'payment_status',
            'outgoing_links', 'incoming_links'
        ]
```

#### 4. ViewSets e Endpoints

```python
class TransactionLinkViewSet(viewsets.ModelViewSet):
    """
    ViewSet para gerenciar vinculações entre transações.
    """
    serializer_class = TransactionLinkSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        return TransactionLink.objects.filter(
            user=self.request.user
        ).select_related(
            'source_transaction',
            'target_transaction',
            'source_transaction__category',
            'target_transaction__category'
        )
    
    @action(detail=False, methods=['get'])
    def available_sources(self, request):
        """
        Retorna receitas disponíveis para vincular (que ainda têm saldo).
        """
        transactions = Transaction.objects.filter(
            user=request.user,
            type=Transaction.TransactionType.INCOME
        ).annotate(
            linked_total=Coalesce(
                Sum('outgoing_links__linked_amount'),
                Decimal('0')
            ),
            available=F('amount') - F('linked_total')
        ).filter(
            available__gt=0
        ).order_by('-date')
        
        serializer = TransactionSerializer(transactions, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def available_targets(self, request):
        """
        Retorna dívidas disponíveis para pagar (que ainda têm saldo devedor).
        """
        transactions = Transaction.objects.filter(
            user=request.user,
            category__type=Category.CategoryType.DEBT,
            type=Transaction.TransactionType.EXPENSE
        ).annotate(
            linked_total=Coalesce(
                Sum('incoming_links__linked_amount'),
                Decimal('0')
            ),
            available=F('amount') - F('linked_total')
        ).filter(
            available__gt=0
        ).order_by('-date')
        
        serializer = TransactionSerializer(transactions, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def quick_link(self, request):
        """
        Endpoint simplificado para vincular receita e dívida rapidamente.
        """
        source_id = request.data.get('source_id')
        target_id = request.data.get('target_id')
        amount = Decimal(request.data.get('amount', '0'))
        
        if not all([source_id, target_id, amount > 0]):
            return Response(
                {'error': 'source_id, target_id e amount são obrigatórios'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        try:
            source = Transaction.objects.get(id=source_id, user=request.user)
            target = Transaction.objects.get(id=target_id, user=request.user)
            
            # Criar vinculação
            link = TransactionLink.objects.create(
                user=request.user,
                source_transaction=source,
                target_transaction=target,
                linked_amount=amount,
                link_type=TransactionLink.LinkType.DEBT_PAYMENT,
                description=f"Pagamento de {target.description} com {source.description}"
            )
            
            # Invalidar cache de indicadores
            invalidate_indicators_cache(request.user)
            
            serializer = self.get_serializer(link)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        except Transaction.DoesNotExist:
            return Response(
                {'error': 'Transação não encontrada'},
                status=status.HTTP_404_NOT_FOUND
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
    
    @action(detail=True, methods=['delete'])
    def unlink(self, request, pk=None):
        """
        Remove vinculação entre transações.
        """
        link = self.get_object()
        link.delete()
        
        # Invalidar cache de indicadores
        invalidate_indicators_cache(request.user)
        
        return Response(
            {'message': 'Vinculação removida com sucesso'},
            status=status.HTTP_204_NO_CONTENT
        )
```

#### 5. Atualização do Cálculo de Indicadores

```python
def calculate_summary(user) -> Dict[str, Decimal]:
    """
    Atualização do cálculo considerando vinculações.
    """
    # ... código existente ...
    
    # Calcular totais considerando vinculações
    # Receitas que foram vinculadas não contam como disponíveis
    available_income = income - _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.INCOME
        ).annotate(
            linked=Coalesce(Sum('outgoing_links__linked_amount'), Decimal('0'))
        ).aggregate(total_linked=Sum('linked'))['total_linked']
    )
    
    # Dívidas já pagas (via vinculação) não contam no saldo devedor
    debt_paid_via_links = _decimal(
        TransactionLink.objects.filter(
            user=user,
            link_type=TransactionLink.LinkType.DEBT_PAYMENT
        ).aggregate(total=Sum('linked_amount'))['total']
    )
    
    # Ajustar cálculo de dívidas
    actual_debt_balance = debt_balance - debt_paid_via_links
    
    # Recalcular TPS considerando vinculações
    # TPS = ((Receitas - Vinculações para Dívidas - Despesas Não-Vinculadas) / Receitas) × 100
    non_linked_expenses = expense - _decimal(
        Transaction.objects.filter(
            user=user,
            type=Transaction.TransactionType.EXPENSE,
            category__type=Category.CategoryType.DEBT
        ).annotate(
            linked=Coalesce(Sum('incoming_links__linked_amount'), Decimal('0'))
        ).aggregate(total_linked=Sum('linked'))['total_linked']
    )
    
    if income > 0:
        savings = available_income - non_linked_expenses
        tps = (savings / income) * Decimal("100")
    
    # ... resto do código ...
```

### Interface do Usuário (Flutter)

#### Tela de Pagamento de Dívidas

```dart
class DebtPaymentScreen extends StatefulWidget {
  const DebtPaymentScreen({super.key});

  @override
  State<DebtPaymentScreen> createState() => _DebtPaymentScreenState();
}

class _DebtPaymentScreenState extends State<DebtPaymentScreen> {
  List<TransactionModel> availableIncomes = [];
  List<TransactionModel> availableDebts = [];
  TransactionModel? selectedIncome;
  TransactionModel? selectedDebt;
  double? paymentAmount;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // Carregar receitas disponíveis
      final incomes = await repository.getAvailableIncomes();
      // Carregar dívidas disponíveis
      final debts = await repository.getAvailableDebts();
      
      setState(() {
        availableIncomes = incomes;
        availableDebts = debts;
        isLoading = false;
      });
    } catch (e) {
      // Tratar erro
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagar Dívida'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card explicativo
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vincule uma receita a uma dívida para registrar o pagamento. '
                              'Você pode fazer pagamentos parciais ou totais.',
                              style: TextStyle(color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Seção: Selecionar Receita
                  Text(
                    '1. Selecione a Receita',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (availableIncomes.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Nenhuma receita disponível. Cadastre uma receita primeiro.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...availableIncomes.map((income) => _IncomeCard(
                      income: income,
                      isSelected: selectedIncome?.id == income.id,
                      onTap: () => setState(() => selectedIncome = income),
                    )),
                  
                  const SizedBox(height: 24),
                  
                  // Seção: Selecionar Dívida
                  Text(
                    '2. Selecione a Dívida',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  if (availableDebts.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Nenhuma dívida pendente.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    )
                  else
                    ...availableDebts.map((debt) => _DebtCard(
                      debt: debt,
                      isSelected: selectedDebt?.id == debt.id,
                      onTap: () => setState(() => selectedDebt = debt),
                    )),
                  
                  const SizedBox(height: 24),
                  
                  // Seção: Valor do Pagamento
                  if (selectedIncome != null && selectedDebt != null) ...[
                    Text(
                      '3. Valor do Pagamento',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              decoration: const InputDecoration(
                                labelText: 'Valor',
                                prefixText: 'R\$ ',
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              onChanged: (value) {
                                setState(() {
                                  paymentAmount = double.tryParse(
                                    value.replaceAll(',', '.')
                                  );
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _QuickAmountButton(
                                    label: 'Máximo Disponível',
                                    amount: selectedIncome!.availableAmount,
                                    onTap: () => setState(() {
                                      paymentAmount = selectedIncome!.availableAmount;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _QuickAmountButton(
                                    label: 'Total da Dívida',
                                    amount: selectedDebt!.availableAmount,
                                    onTap: () => setState(() {
                                      paymentAmount = selectedDebt!.availableAmount;
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Disponível na receita:',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'R\$ ${selectedIncome!.availableAmount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Restante da dívida:',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                Text(
                                  'R\$ ${selectedDebt!.availableAmount.toStringAsFixed(2)}',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Botão Confirmar
                  if (selectedIncome != null && 
                      selectedDebt != null && 
                      paymentAmount != null &&
                      paymentAmount! > 0)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _confirmPayment,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Confirmar Pagamento',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _confirmPayment() async {
    if (selectedIncome == null || selectedDebt == null || paymentAmount == null) {
      return;
    }

    // Validações
    if (paymentAmount! > selectedIncome!.availableAmount) {
      _showError('Valor excede o disponível na receita');
      return;
    }

    if (paymentAmount! > selectedDebt!.availableAmount) {
      _showError('Valor excede o restante da dívida');
      return;
    }

    try {
      await repository.linkTransactions(
        sourceId: selectedIncome!.id,
        targetId: selectedDebt!.id,
        amount: paymentAmount!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pagamento registrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Retornar sucesso
      }
    } catch (e) {
      _showError('Erro ao registrar pagamento: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Widgets auxiliares
class _IncomeCard extends StatelessWidget {
  final TransactionModel income;
  final bool isSelected;
  final VoidCallback onTap;

  const _IncomeCard({
    required this.income,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.green.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      income.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (income.category != null)
                      Text(
                        income.category!.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(income.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${income.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Disponível: R\$ ${income.availableAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  final TransactionModel debt;
  final bool isSelected;
  final VoidCallback onTap;

  const _DebtCard({
    required this.debt,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isSelected ? Colors.red.shade50 : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.description,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (debt.category != null)
                      Text(
                        debt.category!.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    Text(
                      DateFormat('dd/MM/yyyy').format(debt.date),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'R\$ ${debt.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Restante: R\$ ${debt.availableAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAmountButton extends StatelessWidget {
  final String label;
  final double amount;
  final VoidCallback onTap;

  const _QuickAmountButton({
    required this.label,
    required this.amount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
          Text(
            'R\$ ${amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
```

## 📊 Requisitos Funcionais Detalhados

### RF01: Listagem de Receitas Disponíveis
**Descrição:** O sistema deve listar todas as receitas que ainda possuem saldo disponível para vinculação.

**Critérios de Aceitação:**
- Exibir apenas receitas com `available_amount > 0`
- Mostrar valor total e valor disponível
- Ordenar por data (mais recentes primeiro)
- Filtrar por categoria opcionalmente
- Exibir ícone indicando se é recorrente

**Endpoint:** `GET /api/transaction-links/available-sources/`

### RF02: Listagem de Dívidas Pendentes
**Descrição:** O sistema deve listar todas as dívidas que ainda possuem saldo devedor.

**Critérios de Aceitação:**
- Exibir apenas dívidas com `available_amount > 0`
- Mostrar valor total, valor pago e valor restante
- Ordenar por data de vencimento (se disponível) ou data de cadastro
- Exibir progresso visual (barra ou percentual)
- Indicar status: pendente, parcial, pago

**Endpoint:** `GET /api/transaction-links/available-targets/`

### RF03: Vinculação de Transações
**Descrição:** Permitir vincular uma receita a uma dívida, especificando o valor.

**Critérios de Aceitação:**
- Validar que o valor não excede o disponível na receita
- Validar que o valor não excede o restante da dívida
- Permitir pagamento parcial
- Permitir pagamento total
- Gerar descrição automática da vinculação
- Atualizar indicadores financeiros automaticamente

**Endpoint:** `POST /api/transaction-links/quick-link/`

**Payload:**
```json
{
  "source_id": 123,
  "target_id": 456,
  "amount": "150.00"
}
```

### RF04: Visualização de Vinculações
**Descrição:** Permitir visualizar todas as vinculações existentes.

**Critérios de Aceitação:**
- Listar vinculações ordenadas por data
- Exibir origem → destino com valor
- Filtrar por tipo de vinculação
- Filtrar por período
- Exibir detalhes completos ao clicar

**Endpoint:** `GET /api/transaction-links/`

### RF05: Remoção de Vinculação
**Descrição:** Permitir desvincular transações.

**Critérios de Aceitação:**
- Confirmar ação com o usuário
- Restaurar saldos disponíveis
- Atualizar indicadores financeiros
- Registrar no histórico (auditoria)

**Endpoint:** `DELETE /api/transaction-links/{id}/`

### RF06: Pagamento Recorrente Automático
**Descrição:** Vincular automaticamente transações recorrentes futuras.

**Critérios de Aceitação:**
- Ao criar vinculação, permitir marcar como recorrente
- Gerar vinculações automáticas quando transações recorrentes forem criadas
- Respeitar valor e periodicidade
- Notificar usuário sobre vinculações automáticas
- Permitir desativar vinculação automática

### RF07: Sugestões Inteligentes
**Descrição:** Sugerir vinculações baseadas em padrões anteriores.

**Critérios de Aceitação:**
- Analisar vinculações anteriores
- Sugerir mesma receita para mesma dívida
- Sugerir valor baseado em histórico
- Permitir aceitar ou rejeitar sugestão
- Aprender com decisões do usuário

### RF08: Relatório de Pagamentos
**Descrição:** Gerar relatório de pagamentos de dívidas por período.

**Critérios de Aceitação:**
- Agrupar por dívida
- Mostrar total pago, restante e percentual
- Exibir gráfico de evolução
- Exportar para PDF/CSV
- Filtrar por categoria de dívida

**Endpoint:** `GET /api/transaction-links/payment-report/?start_date=YYYY-MM-DD&end_date=YYYY-MM-DD`

## 🎨 Melhorias de Usabilidade

### U01: Wizard de Pagamento em 3 Passos
- Passo 1: Selecionar receita
- Passo 2: Selecionar dívida
- Passo 3: Definir valor

### U02: Atalhos Rápidos
- Botão "Pagar Máximo" (usa todo saldo disponível da receita)
- Botão "Quitar Dívida" (paga total da dívida)
- Botão "Pagar Mínimo" (valor mínimo configurado)

### U03: Feedback Visual
- Cores indicando status (verde = pago, amarelo = parcial, vermelho = pendente)
- Barras de progresso para dívidas
- Animações de sucesso ao vincular
- Ícones intuitivos

### U04: Validação em Tempo Real
- Verificar saldo disponível enquanto digita
- Alertar se valor excede limites
- Sugerir valores válidos
- Highlight em campos com erro

### U05: Templates de Pagamento
- Salvar combinações frequentes (ex: "Salário → Aluguel")
- Aplicar template com um clique
- Editar templates salvos

### U06: Notificações
- Lembrar de pagar dívidas próximas ao vencimento
- Notificar quando receita chegar e houver dívida pendente
- Parabenizar quando quitar dívida

### U07: Dashboard de Dívidas
- Visão geral de todas as dívidas
- Indicador de saúde financeira
- Projeção de quitação
- Gráfico de evolução

## 🔄 Fluxos de Uso

### Fluxo 1: Pagamento Simples
1. Usuário acessa "Pagar Dívida"
2. Sistema lista receitas e dívidas disponíveis
3. Usuário seleciona receita
4. Usuário seleciona dívida
5. Usuário define valor (ou usa atalho)
6. Sistema valida
7. Usuário confirma
8. Sistema cria vinculação
9. Sistema atualiza indicadores
10. Sistema exibe sucesso

### Fluxo 2: Pagamento com Sugestão
1. Usuário acessa "Pagar Dívida"
2. Sistema analisa histórico e sugere vinculação
3. Sistema pré-seleciona receita e dívida
4. Usuário revisa e ajusta se necessário
5. Usuário confirma
6. Sistema processa (mesmo fluxo 1)

### Fluxo 3: Pagamento Recorrente
1. Usuário cria vinculação
2. Usuário marca como recorrente
3. Sistema pergunta período (igual à receita/dívida)
4. Sistema salva configuração
5. Quando próximas transações recorrentes forem criadas:
   - Sistema cria vinculação automaticamente
   - Sistema notifica usuário
6. Usuário pode revisar e ajustar

### Fluxo 4: Visualização de Status
1. Usuário visualiza lista de transações
2. Sistema exibe badges indicando:
   - Receita: "X% utilizado"
   - Dívida: "Y% pago"
3. Usuário clica para ver detalhes
4. Sistema mostra histórico de vinculações

## 🔐 Requisitos Não-Funcionais

### RNF01: Performance
- Listagens devem carregar em < 500ms
- Validações em tempo real < 100ms
- Cache de consultas frequentes
- Paginação para grandes volumes

### RNF02: Segurança
- Todas as operações requerem autenticação
- Usuário só pode ver/editar suas próprias transações
- Validação de dados no backend
- Log de auditoria para operações críticas

### RNF03: Confiabilidade
- Transações atômicas (tudo ou nada)
- Validação de integridade referencial
- Backup automático
- Rollback em caso de erro

### RNF04: Usabilidade
- Interface intuitiva, sem necessidade de manual
- Feedback claro em todas as ações
- Mensagens de erro descritivas
- Consistência visual

### RNF05: Manutenibilidade
- Código bem documentado
- Testes unitários e de integração
- Logs estruturados
- Versionamento de API

## 📈 Impacto nos Indicadores

### TPS (Taxa de Poupança Pessoal)
**Antes:** Calculado considerando pagamentos de dívida como despesa separada
**Depois:** Calculado apenas com receitas não vinculadas e despesas não-vinculadas
**Impacto:** Mais preciso, pois evita dupla contagem

### RDR (Razão Dívida/Renda)
**Antes:** Baseado em total de pagamentos de dívida
**Depois:** Baseado em valor total vinculado para pagamento de dívidas
**Impacto:** Mais preciso, reflete comprometimento real da renda

### ILI (Índice de Liquidez Imediata)
**Impacto:** Não afetado diretamente, mas vinculações para reserva podem ser implementadas

## 🚀 Roadmap de Implementação

### Fase 1: Backend Base (Semana 1-2)
- [ ] Criar modelo `TransactionLink`
- [ ] Criar migration
- [ ] Adicionar properties ao modelo `Transaction`
- [ ] Criar serializers
- [ ] Criar ViewSet básico
- [ ] Escrever testes unitários

### Fase 2: Endpoints Avançados (Semana 3)
- [ ] Endpoint `available_sources`
- [ ] Endpoint `available_targets`
- [ ] Endpoint `quick_link`
- [ ] Endpoint `payment_report`
- [ ] Atualizar cálculo de indicadores
- [ ] Testes de integração

### Fase 3: Frontend Base (Semana 4-5)
- [ ] Criar tela de pagamento de dívidas
- [ ] Implementar seleção de receitas
- [ ] Implementar seleção de dívidas
- [ ] Implementar input de valor
- [ ] Validações em tempo real
- [ ] Feedback visual

### Fase 4: Features Avançadas (Semana 6-7)
- [ ] Sugestões inteligentes
- [ ] Templates de pagamento
- [ ] Pagamento recorrente automático
- [ ] Dashboard de dívidas
- [ ] Notificações

### Fase 5: Refinamento (Semana 8)
- [ ] Testes de usabilidade
- [ ] Ajustes de UX
- [ ] Otimizações de performance
- [ ] Documentação final
- [ ] Deploy

## 💡 Sugestões Adicionais

### Integração com Metas
- Criar meta de "Quitar dívida X"
- Acompanhar progresso automaticamente
- Ganhar XP ao quitar dívidas

### Análise Preditiva
- Prever quando dívida será quitada
- Sugerir quanto pagar para quitar em X meses
- Simular diferentes cenários

### Gamificação
- Conquistas por quitar dívidas
- Ranking de quitação (anônimo)
- Desafios de pagamento

### Integração com Calendário
- Visualizar dívidas no calendário
- Lembrar de vencimentos
- Planejar pagamentos futuros

### Exportação
- Gerar comprovante de pagamento (PDF)
- Exportar histórico de vinculações
- Gerar relatório para declaração de IR

## 📝 Observações Finais

Esta proposta mantém a estrutura existente de transações, mas adiciona uma camada de vinculação que:
1. **Simplifica o cadastro** - usuário não precisa duplicar informações
2. **Melhora rastreabilidade** - origem e destino do dinheiro ficam claros
3. **Evita inconsistências** - validações garantem integridade
4. **Facilita análises** - relatórios mais precisos
5. **Melhora UX** - fluxo intuitivo e visual

A implementação é **retrocompatível** - transações antigas continuam funcionando, e o novo sistema pode conviver com o antigo durante transição.
