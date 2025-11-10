# Plano: Sistema de Pagamento Múltiplo de Despesas

## 🎯 Objetivo
Criar um sistema robusto para identificar despesas pendentes e permitir pagamento em lote com múltiplas fontes de receita.

## 📊 Funcionalidades

### 1. **Identificação de Despesas Pendentes**

#### Backend - Novo Endpoint
```python
# Api/finance/views.py

@action(detail=False, methods=['get'])
def pending_debts_summary(self, request):
    """
    Retorna resumo de despesas pendentes com análise de urgência.
    
    Query params:
    - include_categories: IDs de categorias a incluir
    - exclude_categories: IDs de categorias a excluir
    - min_remaining: Valor mínimo de saldo devedor
    - sort_by: urgency|amount|date (padrão: urgency)
    
    Response:
    {
        "total_pending": 5000.00,
        "urgent_count": 3,  # Despesas com >80% vinculadas
        "debts": [
            {
                "id": 123,
                "description": "Cartão de Crédito",
                "category": {...},
                "total_amount": 2000.00,
                "paid_amount": 500.00,
                "remaining_amount": 1500.00,
                "payment_percentage": 25.0,
                "is_urgent": true,  # >80% vinculado
                "days_since_created": 15,
                "estimated_monthly": 2000.00  # Se recorrente
            }
        ],
        "available_income": 3500.00,
        "coverage_percentage": 70.0  # Quanto % pode pagar com renda disponível
    }
    """
```

#### Frontend - Service para Notificações
```dart
// lib/core/services/debt_notification_service.dart

class DebtNotificationService {
  /// Verifica despesas pendentes e exibe notificações apropriadas
  static Future<void> checkPendingDebts({
    required BuildContext context,
    bool forceCheck = false,
  }) async {
    // Lógica de verificação:
    // 1. Verificar se está próximo do fim do mês (dia > 25)
    // 2. Buscar despesas pendentes
    // 3. Calcular urgência
    // 4. Exibir popup se necessário
  }
  
  /// Exibe modal com resumo de pendências
  static Future<void> showPendingDebtsModal({...}) async {
    // Modal estilo iOS/Material com:
    // - Lista de despesas urgentes
    // - Botão "Pagar Agora"
    // - Botão "Lembrar Depois"
    // - Checkbox "Não mostrar novamente este mês"
  }
}
```

### 2. **Pagamento em Lote (Múltiplas Fontes → Múltiplas Despesas)**

#### Backend - Endpoint de Criação em Lote
```python
# Api/finance/views.py

@action(detail=False, methods=['post'])
def bulk_payment(self, request):
    """
    Cria múltiplas vinculações de uma vez.
    
    Body:
    {
        "payments": [
            {
                "source_id": "uuid-receita-1",
                "target_id": "uuid-despesa-1",
                "amount": 500.00
            },
            {
                "source_id": "uuid-receita-1",  # Mesma receita
                "target_id": "uuid-despesa-2",
                "amount": 300.00
            },
            {
                "source_id": "uuid-receita-2",  # Outra receita
                "target_id": "uuid-despesa-2",  # Mesma despesa
                "amount": 200.00
            }
        ],
        "description": "Pagamento mensal - Janeiro/2025"
    }
    
    Response:
    {
        "success": true,
        "created_count": 3,
        "total_amount": 1000.00,
        "links": [...],
        "updated_debts": [
            {
                "debt_id": "...",
                "new_remaining": 0.00,
                "is_fully_paid": true
            }
        ]
    }
    """
    from django.db import transaction as db_transaction
    
    payments_data = request.data.get('payments', [])
    description = request.data.get('description', '')
    
    if not payments_data:
        return Response({'error': 'Nenhum pagamento fornecido'}, 
                       status=status.HTTP_400_BAD_REQUEST)
    
    created_links = []
    total_amount = Decimal('0')
    
    try:
        with db_transaction.atomic():
            for payment in payments_data:
                # Validar dados
                source_id = payment.get('source_id')
                target_id = payment.get('target_id')
                amount = Decimal(str(payment.get('amount', 0)))
                
                if amount <= 0:
                    raise ValueError(f"Valor inválido: {amount}")
                
                # Criar link
                link = TransactionLink.objects.create(
                    user=request.user,
                    source_transaction_uuid=source_id,
                    target_transaction_uuid=target_id,
                    linked_amount=amount,
                    link_type=TransactionLink.LinkType.DEBT_PAYMENT,
                    description=description
                )
                
                created_links.append(link)
                total_amount += amount
            
            # Invalidar cache
            invalidate_user_dashboard_cache(request.user)
        
        # Serializar resposta
        serializer = TransactionLinkSerializer(created_links, many=True)
        
        return Response({
            'success': True,
            'created_count': len(created_links),
            'total_amount': float(total_amount),
            'links': serializer.data
        })
        
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )
```

#### Frontend - Tela de Pagamento Múltiplo
```dart
// lib/features/transactions/presentation/pages/bulk_payment_page.dart

class BulkPaymentPage extends StatefulWidget {
  // Permite selecionar:
  // - Múltiplas receitas (com % ou valor fixo de cada)
  // - Múltiplas despesas (com valor a pagar em cada)
  // 
  // Mostra:
  // - Total disponível nas receitas selecionadas
  // - Total pendente nas despesas selecionadas
  // - Saldo após pagamento
  // - Validação em tempo real
}

class _PaymentAllocation {
  final TransactionModel source;  // Receita
  final double allocatedAmount;   // Quanto usar desta receita
  
  const _PaymentAllocation({
    required this.source,
    required this.allocatedAmount,
  });
}

class _DebtPayment {
  final TransactionModel target;  // Despesa
  final double paymentAmount;     // Quanto pagar
  
  const _DebtPayment({
    required this.target,
    required this.paymentAmount,
  });
}
```

### 3. **Melhorias na UI/UX**

#### a) Dashboard - Card de Pendências
```dart
// Adicionar na HomePage um card destacado quando houver pendências urgentes

_PendingDebtsCard(
  urgentCount: 3,
  totalPending: 5000.00,
  onTap: () => Navigator.push(...BulkPaymentPage()),
)
```

#### b) Notificações Inteligentes
- **Diária**: Se dia > 25 do mês E houver pendências
- **Semanal**: Todo domingo, se houver >R$1000 pendente
- **Urgente**: Quando despesa atinge 90% de vinculação (quase paga)

#### c) Visualização de Fluxo
```dart
// Gráfico tipo Sankey mostrando:
// Receitas → Despesas → Saldo
// 
// Exemplo:
// Salário (R$ 5000) ──┬→ Cartão (R$ 2000)
//                     ├→ Aluguel (R$ 1500)
//                     └→ Disponível (R$ 1500)
```

## 🔄 Fluxo de Uso

### Cenário 1: Notificação Automática
1. Usuário abre o app no dia 28 do mês
2. Sistema detecta 3 despesas urgentes
3. Popup aparece: "Você tem R$ 3.500 em contas pendentes"
4. Botão "Pagar Agora" leva para `BulkPaymentPage`

### Cenário 2: Pagamento Manual em Lote
1. Usuário navega para Transações → Pagar Despesas
2. Seleciona 2 receitas:
   - Salário: usar R$ 2.000
   - Freelance: usar R$ 500
3. Seleciona 3 despesas:
   - Cartão: pagar R$ 1.500
   - Aluguel: pagar R$ 800
   - Internet: pagar R$ 200 (total)
4. Sistema valida e cria 5 links automaticamente
5. Feedback visual mostra despesas quitadas

## 🎨 Wireframe Conceitual

```
┌─────────────────────────────────────────┐
│ Pagar Despesas                      [X] │
├─────────────────────────────────────────┤
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Selecione as Fontes de Pagamento   │ │
│ ├─────────────────────────────────────┤ │
│ │ ☑ Salário            R$ 5.000,00   │ │
│ │   Usar: [R$ 2.000,00▼]              │ │
│ │                                     │ │
│ │ ☑ Freelance          R$ 1.200,00   │ │
│ │   Usar: [R$ 500,00▼]                │ │
│ │                                     │ │
│ │ ☐ 13º Salário        R$ 3.000,00   │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Total Disponível: R$ 2.500,00          │
│                                         │
│ ┌─────────────────────────────────────┐ │
│ │ Selecione as Despesas a Pagar      │ │
│ ├─────────────────────────────────────┤ │
│ │ ☑ Cartão de Crédito                │ │
│ │   Deve: R$ 2.000,00                 │ │
│ │   Pagar: [R$ 1.500,00▼]             │ │
│ │                                     │ │
│ │ ☑ Aluguel                          │ │
│ │   Deve: R$ 800,00                   │ │
│ │   Pagar: [R$ 800,00▼]               │ │
│ │                                     │ │
│ │ ☑ Internet                         │ │
│ │   Deve: R$ 200,00                   │ │
│ │   Pagar: [R$ 200,00▼]               │ │
│ └─────────────────────────────────────┘ │
│                                         │
│ Total a Pagar: R$ 2.500,00             │
│ Saldo Após: R$ 0,00                    │
│                                         │
│ [        Confirmar Pagamento        ]  │
└─────────────────────────────────────────┘
```

## 📝 Checklist de Implementação

### Backend
- [ ] Criar endpoint `pending_debts_summary`
- [ ] Criar endpoint `bulk_payment`
- [ ] Adicionar validações de saldo
- [ ] Adicionar testes unitários
- [ ] Documentar no Swagger

### Frontend
- [ ] Criar `DebtNotificationService`
- [ ] Criar `BulkPaymentPage`
- [ ] Adicionar `PendingDebtsCard` na HomePage
- [ ] Implementar lógica de notificações
- [ ] Adicionar testes de widget

### Infraestrutura
- [ ] Configurar cron job para notificações (opcional)
- [ ] Adicionar métricas de uso
- [ ] Documentar no README

## 🚀 Próximos Passos

1. **Fase 1**: Endpoint `bulk_payment` + tela básica
2. **Fase 2**: Sistema de notificações
3. **Fase 3**: Melhorias de UX (gráficos, animações)
4. **Fase 4**: Relatórios e analytics

## ⚡ Otimizações Futuras

1. **Cache Inteligente**: Cachear lista de pendências por 5min
2. **Sugestões Automáticas**: IA sugere alocação ideal
3. **Parcelamento**: Permitir dividir pagamento em múltiplos meses
4. **Recorrência**: Salvar "templates" de pagamento mensal
