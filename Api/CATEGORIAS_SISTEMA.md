# Sistema de Categorias e Grupos

## Visão Geral

O sistema de categorias foi projetado para organizar transações financeiras de forma hierárquica, facilitando análises precisas e cálculo correto dos indicadores financeiros.

## Estrutura

### Tipos de Categoria (CategoryType)
- **INCOME**: Receitas e entradas de dinheiro
- **EXPENSE**: Despesas e saídas de dinheiro
- **DEBT**: Dívidas e obrigações financeiras

### Grupos de Categoria (CategoryGroup)

#### 1. REGULAR_INCOME - Renda Principal
Receitas fixas e previsíveis que formam a base da renda mensal.
- Salário
- Pensão
- Aposentadoria

**Uso**: Toda renda fixa deve ser classificada aqui para cálculo correto dos indicadores.

#### 2. EXTRA_INCOME - Renda Extra
Receitas variáveis e não recorrentes.
- Freela
- Bico
- Venda
- Prêmio

**Uso**: Receitas ocasionais que complementam a renda principal.

#### 3. SAVINGS - Poupança / Reserva
Aportes em reserva de emergência e poupança.
- Reserva de Emergência
- Poupança

**Uso**: Registrar como EXPENSE quando guardar dinheiro. O valor acumulado é usado no cálculo do ILI (Índice de Liquidez Imediata).

**⚠️ IMPORTANTE**: 
- Aporte na reserva = EXPENSE em categoria SAVINGS
- Resgate da reserva = INCOME em categoria SAVINGS (raro)

#### 4. INVESTMENT - Investimentos
Aplicações financeiras de médio e longo prazo.
- Ações
- Fundos
- Tesouro Direto
- Previdência

**Uso**: 
- Aporte em investimento = EXPENSE em categoria INVESTMENT
- Rendimento/Dividendo = INCOME em categoria INVESTMENT
- Resgate = INCOME em categoria INVESTMENT

#### 5. ESSENTIAL_EXPENSE - Despesas Essenciais
Gastos fundamentais para manutenção da vida cotidiana.
- Moradia (aluguel, condomínio)
- Contas básicas (luz, água, gás, internet, telefone)
- Alimentação (mercado)
- Transporte (combustível, transporte público)
- Saúde (plano de saúde, remédios)
- Educação (mensalidade, material escolar)

**Uso**: Usado no cálculo do ILI. A média de despesas essenciais dos últimos 3 meses determina quantos meses a reserva consegue cobrir.

**⚠️ IMPORTANTE**: Classifique apenas despesas realmente essenciais aqui. Gastos supérfluos devem ir para LIFESTYLE_EXPENSE.

#### 6. LIFESTYLE_EXPENSE - Estilo de Vida
Gastos não essenciais que melhoram qualidade de vida.
- Lazer (restaurante, cinema, streaming)
- Academia
- Viagem
- Roupas
- Beleza
- Pet
- Presente

**Uso**: Primeira área a revisar ao tentar melhorar TPS ou reduzir dívidas.

#### 7. DEBT - Dívidas
Todas as obrigações de crédito.
- Cartão de Crédito
- Empréstimo Pessoal
- Financiamento (Carro, Casa)
- Empréstimo Consignado
- Cheque Especial

**Uso**:
- Nova dívida/compra a crédito = EXPENSE em categoria DEBT
- Pagamento de dívida = DEBT_PAYMENT em categoria DEBT
- Ajuste/perdão de dívida = INCOME em categoria DEBT (raro)

O saldo é calculado como: Novas Dívidas - Pagamentos - Ajustes

#### 8. GOAL - Metas e Sonhos
Aportes específicos para objetivos de médio/longo prazo.
- Meta Casa
- Meta Carro
- Meta Viagem
- Meta Casamento

**Uso**: Separar dinheiro para objetivos específicos, diferente de investimentos gerais.

#### 9. OTHER - Outros
Transações que não se encaixam nas categorias anteriores.
- Outros ganhos
- Outros gastos
- Imposto
- Restituição

**Uso**: Último recurso. Prefira sempre uma categoria específica.

## Como os Indicadores Usam as Categorias

### TPS (Taxa de Poupança Pessoal)
```
TPS = ((Receitas Totais - Despesas Totais - Pagamentos de Dívida) / Receitas Totais) × 100
```

- **Receitas Totais**: INCOME de todos os grupos
- **Despesas Totais**: EXPENSE de todos os grupos (incluindo SAVINGS e INVESTMENT)
- **Pagamentos de Dívida**: DEBT_PAYMENT em categorias DEBT

**Para melhorar TPS**:
1. Aumentar aportes em SAVINGS (conta como despesa mas melhora capacidade de poupança)
2. Reduzir LIFESTYLE_EXPENSE
3. Reduzir DEBT (menos pagamentos de dívida)

### RDR (Razão Dívida/Renda)
```
RDR = (Saldo de Dívidas / Receitas Totais) × 100
Saldo de Dívidas = Novas Dívidas - Pagamentos - Ajustes
```

- **Saldo de Dívidas**: Calculado apenas em categorias do grupo DEBT
- **Receitas Totais**: INCOME de todos os grupos

**Para melhorar RDR**:
1. Fazer mais DEBT_PAYMENT em categorias DEBT
2. Evitar novos EXPENSE em categorias DEBT
3. Aumentar receitas

### ILI (Índice de Liquidez Imediata)
```
ILI = Reserva Acumulada / Média Mensal de Despesas Essenciais (3 meses)
```

- **Reserva Acumulada**: 
  - Saldo = EXPENSE em SAVINGS - INCOME em SAVINGS
  - Quanto mais EXPENSE em "Reserva de Emergência", maior a reserva
- **Despesas Essenciais**: 
  - Média dos últimos 3 meses de EXPENSE em ESSENTIAL_EXPENSE
  - Inclui moradia, alimentação, transporte, saúde, educação

**Para melhorar ILI**:
1. Aumentar aportes (EXPENSE) em "Reserva de Emergência"
2. Reduzir despesas essenciais (otimização)
3. Não resgatar (INCOME) da reserva

## Como as Missões Usam as Categorias

### Missões de Onboarding
Focam em número de transações cadastradas, independente da categoria.

### Missões de TPS (Poupança)
Monitoram:
- Aportes em SAVINGS e INVESTMENT
- Redução em LIFESTYLE_EXPENSE
- Controle de ESSENTIAL_EXPENSE

### Missões de RDR (Dívidas)
Monitoram:
- DEBT_PAYMENT em categorias DEBT
- Redução de novos EXPENSE em DEBT
- Saldo total de dívidas

### Missões de ILI (Reserva)
Monitoram:
- EXPENSE em categorias SAVINGS
- Média de EXPENSE em ESSENTIAL_EXPENSE
- Relação entre reserva e despesas essenciais

### Missões Avançadas
Combinam múltiplos indicadores e grupos de categorias.

## Boas Práticas

### Para Usuários

1. **Seja consistente**: Use sempre a mesma categoria para o mesmo tipo de gasto
2. **Seja específico**: Prefira categorias detalhadas (ex: "Aluguel" em vez de "Moradia")
3. **Classifique corretamente**:
   - Guardar dinheiro = EXPENSE em SAVINGS
   - Pagar dívida = DEBT_PAYMENT em DEBT
   - Nova dívida = EXPENSE em DEBT
4. **Revise periodicamente**: Suas categorias estão alinhadas com seus objetivos?

### Para Desenvolvedores

1. **Respeite os grupos**: Os cálculos dependem da classificação correta
2. **Valide tipos de transação**: Nem toda combinação faz sentido
3. **Documente exceções**: Se criar lógica especial para algum grupo
4. **Teste indicadores**: Após mudanças, valide que TPS, RDR e ILI estão corretos

## Exemplos Práticos

### Exemplo 1: Construindo Reserva
```
1. Recebe salário: INCOME em "Salário" (REGULAR_INCOME)
2. Guarda 10%: EXPENSE em "Reserva de Emergência" (SAVINGS)
3. Paga aluguel: EXPENSE em "Aluguel" (ESSENTIAL_EXPENSE)
4. Vai ao mercado: EXPENSE em "Mercado" (ESSENTIAL_EXPENSE)
```

Resultado: TPS positivo, ILI aumentando

### Exemplo 2: Pagando Dívida
```
1. Recebe salário: INCOME em "Salário" (REGULAR_INCOME)
2. Paga cartão: DEBT_PAYMENT em "Cartão de Crédito" (DEBT)
3. Não faz novas compras no crédito
```

Resultado: RDR diminuindo, saldo de dívida reduzindo

### Exemplo 3: Investindo
```
1. Recebe salário: INCOME em "Salário" (REGULAR_INCOME)
2. Já tem reserva completa (ILI >= 6)
3. Investe em ações: EXPENSE em "Ações" (INVESTMENT)
```

Resultado: Patrimônio crescendo, sem afetar negativamente indicadores

## Troubleshooting

### "Meu TPS está negativo"
- Verifique se está registrando receitas
- Veja se há muitos DEBT_PAYMENT (considere renegociar)
- Revise despesas em LIFESTYLE_EXPENSE

### "Meu ILI não aumenta"
- Confirme que está usando EXPENSE em categorias SAVINGS
- Verifique se despesas essenciais não estão muito altas
- Não use categorias erradas (ex: INCOME em SAVINGS)

### "Meu RDR está alto"
- Priorize DEBT_PAYMENT sobre novos gastos
- Evite novos EXPENSE em categorias DEBT
- Considere aumentar receitas

### "Missões não estão progredindo"
- Verifique se está usando as categorias corretas
- Confirme que os grupos das categorias estão certos
- Revise se o tipo de transação está adequado (INCOME, EXPENSE, DEBT_PAYMENT)
