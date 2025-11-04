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

**Uso**: Registrar como INCOME quando guardar dinheiro. O valor acumulado é usado no cálculo do ILI (Índice de Liquidez Imediata).

**⚠️ IMPORTANTE - LEIA COM ATENÇÃO**: 

Estas categorias são do tipo **INCOME** (não EXPENSE), por uma razão específica:

- **Aporte na reserva = INCOME em categoria SAVINGS**
  - Quando você guarda R$ 300, registra como INCOME em "Reserva de Emergência"
  - Parece estranho, mas garante que o TPS seja calculado corretamente
  - O sistema entende que você está "pagando para si mesmo"

- **Resgate da reserva = EXPENSE em categoria SAVINGS (raro)**
  - Quando você tira dinheiro da reserva, registra como EXPENSE
  - Isso reduz o saldo da reserva

**Por que INCOME e não EXPENSE?**

Se fosse EXPENSE, o cálculo do TPS ficaria errado:
```
❌ ERRADO (se fosse EXPENSE):
Salário: R$ 3.000 (INCOME)
Reserva: R$ 300 (EXPENSE)
Outras despesas: R$ 2.500 (EXPENSE)
TPS = (3.000 - 2.500 - 300) / 3.000 = 6,67% ← ERRADO!

✅ CORRETO (como INCOME):
Salário: R$ 3.000 (INCOME - receita real)
Reserva: R$ 300 (INCOME - aporte em SAVINGS)
Outras despesas: R$ 2.500 (EXPENSE)
TPS = 300 / 3.000 = 10% ← CORRETO!
```

O sistema automaticamente separa a "receita real" dos "aportes em reserva" no cálculo.

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

**Fórmula detalhada:**
- **Receitas Totais**: Soma de todos os INCOME (todos os grupos)
- **Despesas Totais**: Soma de todos os EXPENSE (exceto DEBT)
- **Pagamentos de Dívida**: Soma de todos os DEBT_PAYMENT

**O que o TPS mede:**
Percentual da renda que sobra depois de pagar todas as despesas e dívidas.
- TPS ≥ 20%: Excelente capacidade de poupança
- TPS 10-19%: Boa poupança
- TPS < 10%: Baixa capacidade de formar reserva

**Para melhorar TPS**:
1. Aumentar receitas (INCOME em qualquer categoria)
2. Reduzir LIFESTYLE_EXPENSE (gastos não essenciais)
3. Otimizar ESSENTIAL_EXPENSE (buscar economia sem perder qualidade)
4. Acelerar quitação de dívidas para reduzir DEBT_PAYMENT futuro

**Exemplo prático:**
```
Receitas: R$ 5.000 (salário)
Despesas: R$ 2.000 (aluguel, mercado, contas)
Dívidas: R$ 1.500 (financiamento + cartão)
Poupança: R$ 1.500 (sobrou)
TPS = 1.500 / 5.000 × 100 = 30% ✅ Excelente!
```

### RDR (Razão Dívida/Renda)
```
RDR = (Pagamentos Mensais de Dívidas / Receitas Totais) × 100
```

**Fórmula detalhada:**
- **Pagamentos Mensais de Dívidas**: Soma de todos os DEBT_PAYMENT
- **Receitas Totais**: Soma de todos os INCOME

**O que o RDR mede:**
Percentual da renda comprometido com pagamento de dívidas mensalmente.
- RDR ≤ 35%: Saudável (padrão bancário)
- RDR 36-42%: Atenção (começando a ficar apertado)
- RDR ≥ 43%: Crítico (risco de inadimplência)

**Para melhorar RDR**:
1. Fazer mais DEBT_PAYMENT (amortizar/quitar dívidas)
2. Evitar novos EXPENSE em categorias DEBT (não contrair novas dívidas)
3. Aumentar receitas (mais INCOME)
4. Renegociar dívidas para reduzir parcelas mensais

**Exemplo prático:**
```
Receitas: R$ 5.000
Financiamento: R$ 1.200/mês
Cartão: R$ 800/mês
Total dívidas: R$ 2.000
RDR = 2.000 / 5.000 × 100 = 40% ⚠️ Atenção!
```

**Nota sobre Saldo Total de Dívidas:**
O sistema também calcula o saldo total (quanto você deve):
```
Saldo = Novas Dívidas (EXPENSE em DEBT) - Pagamentos (DEBT_PAYMENT) - Ajustes (INCOME em DEBT)
```
Esse valor aparece como informação adicional no dashboard, mas o RDR oficial usa pagamentos mensais.

### ILI (Índice de Liquidez Imediata)
```
ILI = Reserva de Emergência / Média Mensal de Despesas Essenciais (3 meses)
```

**Fórmula detalhada:**
- **Reserva de Emergência**: 
  - Saldo = INCOME em SAVINGS - EXPENSE em SAVINGS
  - Aportes (INCOME) aumentam a reserva
  - Resgates (EXPENSE) diminuem a reserva
- **Despesas Essenciais Mensais**: 
  - Média dos últimos 3 meses de EXPENSE em ESSENTIAL_EXPENSE
  - Inclui: moradia, alimentação básica, transporte essencial, saúde, educação

**O que o ILI mede:**
Quantos meses a reserva de emergência consegue cobrir suas despesas essenciais.
- ILI ≥ 6: Excelente segurança financeira
- ILI 3-5: Razoável (precisa melhorar)
- ILI < 3: Crítico (vulnerável a emergências)

**Para melhorar ILI**:
1. Aumentar aportes regulares (INCOME) em "Reserva de Emergência"
2. Otimizar despesas essenciais sem perder qualidade de vida
3. Evitar resgates (EXPENSE) da reserva, usar apenas em emergências reais
4. Configurar transferência automática mensal para a reserva

**Exemplo prático:**
```
Reserva atual: R$ 12.000
Média despesas essenciais: R$ 2.000/mês (últimos 3 meses)
ILI = 12.000 / 2.000 = 6 meses ✅ Excelente!

Se tiver emergência, consegue se manter 6 meses sem renda.
```

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
   - Guardar dinheiro = INCOME em SAVINGS
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
2. Guarda 10%: INCOME em "Reserva de Emergência" (SAVINGS)
3. Paga aluguel: EXPENSE em "Aluguel" (ESSENTIAL_EXPENSE)
4. Vai ao mercado: EXPENSE em "Mercado" (ESSENTIAL_EXPENSE)
```

Resultado: TPS = 10%, ILI aumentando

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
- Confirme que está usando INCOME em categorias SAVINGS
- Verifique se despesas essenciais não estão muito altas
- Não use categorias erradas (ex: EXPENSE em SAVINGS para aportes)

### "Meu RDR está alto"
- Priorize DEBT_PAYMENT sobre novos gastos
- Evite novos EXPENSE em categorias DEBT
- Considere aumentar receitas

### "Missões não estão progredindo"
- Verifique se está usando as categorias corretas
- Confirme que os grupos das categorias estão certos
- Revise se o tipo de transação está adequado (INCOME, EXPENSE, DEBT_PAYMENT)
