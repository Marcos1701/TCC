# 🎯 Sistema de Níveis e Faixas de Usuários

## 📊 Como Funciona a Progressão

### **Sistema de XP e Níveis**

O sistema de progressão é baseado em **Experiência (XP)** ganho ao completar missões:

1. **Ganhar XP:** Usuários ganham XP ao completar missões
   - Missões EASY: 50-100 XP
   - Missões MEDIUM: 100-200 XP
   - Missões HARD: 200-350 XP

2. **Subir de Nível:** XP necessário aumenta progressivamente
   ```
   Nível 1 → 2: 150 XP
   Nível 2 → 3: 200 XP (150 + 50)
   Nível 3 → 4: 250 XP (150 + 100)
   Nível N → N+1: 150 + (N-1) × 50 XP
   ```

3. **Level Up:** Quando o XP acumulado atinge o threshold, o usuário sobe de nível
   - XP excedente é mantido para o próximo nível
   - Exemplo: Se tem 170 XP no nível 1 (precisa 150), vai para nível 2 com 20 XP

---

## 🎓 Faixas de Usuários (Tiers)

As faixas são determinadas **exclusivamente pelo NÍVEL** do usuário:

| Faixa | Intervalo de Níveis | Tempo Estimado | Características |
|-------|---------------------|----------------|-----------------|
| **BEGINNER** | Níveis 1-5 | Primeiras semanas | Aprendendo o básico, criando hábitos |
| **INTERMEDIATE** | Níveis 6-15 | 1-3 meses | Otimizando finanças, consistência |
| **ADVANCED** | Níveis 16+ | Mais de 3 meses | Controle avançado, metas ambiciosas |

---

## 🔍 Detalhamento das Faixas

### **🌱 BEGINNER (Níveis 1-5)**

**Perfil Típico:**
- Está começando a usar o sistema
- Poucas transações registradas
- Ainda não tem controle claro das finanças
- TPS médio: ~10%
- RDR médio: ~60%
- ILI médio: ~2 meses

**Foco das Missões:**
- Criar hábito de registro de transações
- Entender categorias básicas
- Identificar para onde vai o dinheiro
- Metas pequenas e alcançáveis
- Educação sobre TPS, RDR, ILI

**Exemplos de Missões:**
- "Registre suas primeiras 5 transações"
- "Categorize 10 despesas diferentes"
- "Complete uma semana registrando todas as compras"

**XP Total Necessário:** ~1.000 XP (7-10 missões médias)

---

### **📈 INTERMEDIATE (Níveis 6-15)**

**Perfil Típico:**
- Usa o sistema regularmente há algumas semanas
- Tem transações consistentes
- Entende os conceitos básicos
- TPS médio: ~20%
- RDR médio: ~40%
- ILI médio: ~4 meses

**Foco das Missões:**
- Otimizar gastos por categoria
- Aumentar TPS gradualmente
- Reduzir dívidas estrategicamente
- Melhorar reserva de emergência
- Identificar padrões de consumo

**Exemplos de Missões:**
- "Reduza gastos com alimentação em 15%"
- "Mantenha TPS acima de 20% por 30 dias"
- "Aumente sua reserva de emergência em R$ 500"

**XP Total Necessário:** ~3.500 XP adicional (30-40 missões totais)

---

### **🏆 ADVANCED (Níveis 16+)**

**Perfil Típico:**
- Usuário experiente e consistente
- Controle financeiro consolidado
- Pensa em investimentos e patrimônio
- TPS médio: ~30%
- RDR médio: ~20%
- ILI médio: ~8 meses

**Foco das Missões:**
- Metas ambiciosas (TPS 30%+)
- Otimização fina de categorias
- Estratégias avançadas de alocação
- Desafios de longo prazo
- Preparação para grandes objetivos

**Exemplos de Missões:**
- "Alcance TPS de 35% por 60 dias consecutivos"
- "Mantenha RDR abaixo de 15% por 90 dias"
- "Construa reserva de emergência para 12 meses"

**XP Total Necessário:** ~7.500+ XP (80+ missões totais)

---

## 💡 Por Que Usar Níveis (e não transações ou missões)?

### **Vantagens do Sistema Baseado em Níveis:**

1. ✅ **Gamificação Natural**
   - Níveis são intuitivos (todos entendem RPGs/jogos)
   - Sensação clara de progressão
   - Motivação para continuar

2. ✅ **Reflete Engajamento Real**
   - Missões completadas = aprendizado aplicado
   - XP = esforço investido na educação financeira
   - Nível = competência financeira desenvolvida

3. ✅ **Balanceamento Automático**
   - Usuários que fazem mais missões progridem mais
   - Impossível "trapacear" o sistema
   - Progressão justa e meritocrática

4. ✅ **Fácil de Entender**
   - "Estou no nível 8" é mais claro que "tenho 237 transações"
   - Permite comparação saudável entre amigos
   - Interface simples de mostrar

### **Alternativas Descartadas:**

❌ **Número de Transações**
- Problema: Fácil de inflar (registrar transações fake)
- Não reflete qualidade, só quantidade
- Não incentiva completar missões

❌ **Missões Completadas**
- Problema: Missões têm dificuldades diferentes
- Alguém com 10 missões HARD > alguém com 20 EASY
- XP resolve isso naturalmente

❌ **Tempo de Cadastro**
- Problema: Não reflete engajamento
- Usuário inativo por meses teria tier alto
- Não incentiva uso do app

---

## 📊 Estatísticas por Faixa (Valores Padrão)

Quando não há usuários suficientes em uma faixa, o sistema usa estes valores:

| Métrica | BEGINNER | INTERMEDIATE | ADVANCED |
|---------|----------|--------------|----------|
| **TPS Médio** | 10% | 20% | 30% |
| **RDR Médio** | 60% | 40% | 20% |
| **ILI Médio** | 2 meses | 4 meses | 8 meses |
| **Categorias Comuns** | Alimentação, Transporte, Moradia |
| **Experiência** | Primeiras semanas | 1-3 meses | Mais de 3 meses |

---

## 🔄 Progressão Típica de um Usuário

### **Semana 1-2 (Nível 1-2)** 
- Completa onboarding
- Primeiras 5-10 transações
- Aprende categorias básicas
- **XP ganho:** ~150-300

### **Semana 3-4 (Nível 3-4)**
- Registra transações diariamente
- Completa primeiras missões de economia
- Entende TPS/RDR/ILI
- **XP ganho:** ~300-500

### **Mês 2 (Nível 5-7)**
- Transição BEGINNER → INTERMEDIATE
- Missões mais desafiadoras desbloqueadas
- Começa otimização de categorias
- **XP ganho:** ~600-900

### **Mês 3-4 (Nível 8-12)**
- Hábitos consolidados
- Melhoria contínua de TPS/RDR
- Desafios de médio prazo
- **XP ganho:** ~1.000-1.500

### **Mês 5+ (Nível 13-15)**
- Preparação para ADVANCED
- Controle financeiro sólido
- Metas ambiciosas começam
- **XP ganho:** ~1.500-2.000

### **Mês 6+ (Nível 16+)**
- Tier ADVANCED
- Missões de otimização avançada
- Foco em investimentos e patrimônio
- **XP ganho:** Contínuo

---

## 🎯 Impacto na Geração de Missões com IA

A IA usa a faixa do usuário para:

1. **Ajustar Complexidade**
   - BEGINNER: Missões simples, educacionais
   - INTERMEDIATE: Missões de otimização
   - ADVANCED: Missões desafiadoras

2. **Personalizar Metas**
   - BEGINNER: TPS 10→15%
   - INTERMEDIATE: TPS 20→25%
   - ADVANCED: TPS 30→35%

3. **Adaptar Duração**
   - BEGINNER: Mais missões curtas (7 dias)
   - INTERMEDIATE: Mix de durações
   - ADVANCED: Mais missões longas (30 dias)

4. **Definir Recompensas**
   - Baseado na dificuldade da missão
   - Progressão natural de XP
   - Incentiva desafios maiores

---

## 📈 Exemplo Prático

**João começou a usar o app:**

| Semana | Ações | Nível | XP Total | Faixa |
|--------|-------|-------|----------|-------|
| 1 | Registrou 10 transações, completou onboarding | 1→2 | 200 | BEGINNER |
| 2 | Completou 3 missões EASY | 2→3 | 350 | BEGINNER |
| 3 | Completou 2 missões MEDIUM | 3→4 | 550 | BEGINNER |
| 4 | Completou 1 missão HARD | 4→5 | 750 | BEGINNER |
| 6 | Completou 5 missões MEDIUM | 5→7 | 1.500 | **INTERMEDIATE** ✨ |
| 8 | Completou 3 missões HARD | 7→9 | 2.200 | INTERMEDIATE |
| 12 | Consistência, mix de missões | 9→14 | 4.000 | INTERMEDIATE |
| 20 | Completou desafios avançados | 14→17 | 7.800 | **ADVANCED** 🏆 |

---

## 🎓 Resumo para o TCC

**"As faixas de usuários (BEGINNER, INTERMEDIATE, ADVANCED) são determinadas pelo NÍVEL do usuário, que por sua vez é calculado através da EXPERIÊNCIA (XP) acumulada ao completar missões. Este sistema gamificado incentiva o engajamento contínuo e reflete a competência financeira desenvolvida pelo usuário ao longo do tempo."**

**Níveis por Faixa:**
- 🌱 BEGINNER: Níveis 1-5
- 📈 INTERMEDIATE: Níveis 6-15
- 🏆 ADVANCED: Níveis 16+

**Sistema de XP:**
- XP necessário por nível: 150 + (Nível-1) × 50
- XP por missão: 50-350 (conforme dificuldade)
- Progressão meritocrática baseada em esforço real

---

**Data:** 09/11/2025  
**Documento:** Sistema de Níveis e Faixas - TCC
