# Correção do Gráfico de Evolução do Saldo

## Problema Identificado

O gráfico "Evolução do Saldo" estava exibindo dados incorretos porque:

1. **Usava dados mock (falsos)**: A função `_generateMockData()` criava 7 pontos artificiais baseados apenas no saldo atual, sem considerar as transações reais
2. **Não considerava datas reais**: Mostrava sempre 7 dias de evolução crescente, independente de quantas transações realmente existiam
3. **Não permitia mudança de período**: Estava fixo em 7 dias

### Exemplo do Problema
- **Situação real**: 2 transações no dia 04/11 e 1 no dia 05/11
- **Gráfico mostrava**: Evolução crescente por 7 dias consecutivos (D, S, T, Q, Q, S, S)
- **Resultado**: Informação completamente incorreta e enganosa

## Solução Implementada

### 1. Dados Reais das Transações

O gráfico agora:
- **Busca todas as transações** do usuário via `repository.fetchTransactions()`
- **Calcula o saldo dia a dia** baseado nas transações reais
- **Considera o tipo de transação**: INCOME adiciona, EXPENSE/DEBT subtrai

### 2. Cálculo Correto do Saldo Acumulado

```dart
// Calcula saldo inicial (antes do período selecionado)
double initialBalance = 0;
for (transações antes do período) {
  if (INCOME) initialBalance += valor
  else initialBalance -= valor
}

// Para cada dia do período:
for (dia em período) {
  // Soma/subtrai transações do dia
  saldo_dia = saldo_anterior ± transações_do_dia
  pontos.add(dia, saldo_dia)
}
```

### 3. Seleção de Período

Adicionados 3 períodos diferentes:
- **7 dias**: Mostra últimos 7 dias (padrão)
- **15 dias**: Mostra últimos 15 dias
- **30 dias**: Mostra últimos 30 dias (aproximadamente 1 mês)

**UI**: Chips clicáveis acima do gráfico para alternar entre períodos

### 4. Labels Inteligentes no Eixo X

- **7 dias**: Mostra inicial do dia da semana (D, S, T, Q, Q, S, S)
- **15 dias**: Mostra dia do mês a cada 2 dias (1, 3, 5, ...)
- **30 dias**: Mostra dia do mês a cada 5 dias (1, 6, 11, ...)

### 5. Tooltip Melhorado

Ao tocar em um ponto do gráfico, mostra:
- Data no formato dia/mês (ex: 04/11)
- Saldo naquele dia formatado (ex: R$ 1.850,00)

## Arquitetura da Solução

### Mudanças no Código

**Antes (StatelessWidget):**
```dart
class _BalanceEvolutionCard extends StatelessWidget {
  List<FlSpot> _generateMockData() {
    // Dados falsos baseados no saldo atual
    return List.generate(7, (index) => FlSpot(...));
  }
}
```

**Depois (StatefulWidget):**
```dart
class _BalanceEvolutionCard extends StatefulWidget {
  final FinanceRepository repository;
  // ...
}

class _BalanceEvolutionCardState extends State<_BalanceEvolutionCard> {
  int _selectedPeriod = 7;
  List<TransactionModel>? _transactions;
  
  void initState() {
    _loadTransactions(); // Busca dados reais
  }
  
  List<FlSpot> _calculateBalanceEvolution() {
    // Calcula saldo real dia a dia
  }
}
```

### Novo Widget: _PeriodChip

Widget reutilizável para os chips de seleção de período:
- Visual com estado selecionado/não selecionado
- Cor primária quando selecionado
- Borda destacada quando ativo

## Comportamento

### Caso 1: Poucas Transações (como no exemplo)
- **2 transações dia 04, 1 dia 05**
- Gráfico mostra:
  - Dias sem transações: linha estável
  - Dia 04: saldo sobe/desce conforme transações
  - Dia 05: ajuste conforme transação do dia
  - Demais dias: linha estável no saldo final

### Caso 2: Sem Transações
- Gráfico mostra linha reta em zero
- Período ainda pode ser alterado
- Sem erros ou crashes

### Caso 3: Muitas Transações
- Calcula corretamente o acumulado
- Mostra evolução real ao longo do período
- Performance otimizada (filtra apenas período relevante)

## Melhorias de UX

1. **Estado de Loading**: CircularProgressIndicator enquanto carrega transações
2. **Seleção Visual**: Chips com cores e bordas para indicar período ativo
3. **Responsividade**: Adapta labels do eixo X conforme período
4. **Tooltip Contextual**: Mostra data e valor ao tocar
5. **Tendência Percentual**: Calcula corretamente baseado em dados reais

## Testes Recomendados

1. **Teste com 3 transações** (cenário do usuário):
   - Verificar que apenas dias 04 e 05 mostram mudanças
   - Outros dias devem manter o saldo

2. **Teste com período de 30 dias**:
   - Verificar labels espaçadas corretamente
   - Verificar cálculo de saldo inicial

3. **Teste sem transações**:
   - Verificar que não há crash
   - Linha deve ficar em zero

4. **Teste com transações antigas**:
   - Transações de meses atrás devem contribuir para saldo inicial
   - Não devem aparecer como pontos no gráfico

## Arquivos Modificados

- `Front/lib/features/home/presentation/pages/home_page.dart`
  - Classe `_BalanceEvolutionCard` convertida para StatefulWidget
  - Adicionado método `_calculateBalanceEvolution()`
  - Adicionado método `_getBottomTitle()`
  - Adicionado método `_loadTransactions()`
  - Novo widget `_PeriodChip`
  - Atualizada chamada do widget para passar `repository`

## Exemplo Visual

```
Antes (ERRADO):
Saldo
  |     •──•──•──•──•──•──•
  |   •
  |──────────────────────────────
    D  S  T  Q  Q  S  S
    (Sempre crescente, 7 dias)

Depois (CORRETO com 3 transações):
Saldo
  |           •────•────────────
  |         •
  |──────────────────────────────
    1  2  3  4  5  6  7
         (Muda apenas nos dias 4 e 5)
```

## Próximos Passos Possíveis

1. Cache de transações para melhor performance
2. Animação ao mudar de período
3. Mais períodos (3 meses, 6 meses, 1 ano)
4. Export do gráfico como imagem
5. Comparação com período anterior
