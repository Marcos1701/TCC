# 🎯 Plano de Otimização da Geração de Missões

## 📊 Análise dos Problemas Identificados

### 1. **Worker Timeout (CRÍTICO)**
```
[CRITICAL] WORKER TIMEOUT (pid:9)
[ERROR] Worker (pid:9) was sent SIGKILL! Perhaps out of memory?
```
**Causa Raiz:** Gunicorn tem timeout de 30s por padrão, mas geração de 20 missões demora ~2-3 minutos

### 2. **Alta Taxa de Duplicação (65%)**
```
Missões 6, 8, 9, 10: Falharam por duplicação
Sucesso: 7/20 (35%)
```
**Causa Raiz:** 
- Prompt muito genérico gera respostas repetitivas
- Falta de diversificação no contexto entre iterações
- Validação de similaridade muito rígida (70% threshold)

### 3. **Timeout do Frontend (60s)**
```dart
receiveTimeout: const Duration(seconds: 60)
```
**Problema:** Geração de 20 missões leva 120-180s, frontend desiste antes

### 4. **Templates Não Utilizados**
```
✅ FASE 1 completa: 0 missões de templates salvas
```
**Desperdício:** 12 missões candidatas de templates ignoradas

---

## 🚀 Plano de Ação Completo

### **PRIORIDADE CRÍTICA - Evitar Worker Timeout**

#### **Ação 1.1: Implementar Geração Assíncrona com Celery** ⭐⭐⭐⭐⭐
```python
# Benefícios:
✅ Processamento em background (sem limite de tempo)
✅ Frontend recebe resposta imediata
✅ Polling/WebSocket para status
✅ Retry automático em caso de falha
```

**Implementação:**
1. Criar task Celery `generate_missions_async.py`
2. Endpoint retorna task_id imediato
3. Endpoint `/missions/generation-status/<task_id>/` para polling
4. Frontend faz polling a cada 2s

#### **Ação 1.2: Aumentar Worker Timeout (TEMPORÁRIO)**
```python
# Procfile ou gunicorn.conf.py
workers = 2
timeout = 300  # 5 minutos
```

---

### **PRIORIDADE ALTA - Reduzir Duplicação**

#### **Ação 2.1: Diversificar Prompts por Lote** ⭐⭐⭐⭐
```python
# Estratégia: Gerar em lotes temáticos
LOTES_TEMATICOS = {
    'lote_1_habitos': {
        'foco': 'Criação de hábitos de registro',
        'palavras_chave': ['diário', 'rotina', 'consistência'],
        'quantidade': 4
    },
    'lote_2_categorias': {
        'foco': 'Organização por categorias',  
        'palavras_chave': ['categorizar', 'separar', 'organizar'],
        'quantidade': 4
    },
    'lote_3_economia': {
        'foco': 'Controle de gastos e economia',
        'palavras_chave': ['economizar', 'reduzir', 'cortar'],
        'quantidade': 4
    },
    'lote_4_metas': {
        'foco': 'Estabelecimento de objetivos',
        'palavras_chave': ['meta', 'objetivo', 'planejar'],
        'quantidade': 4
    },
    'lote_5_analise': {
        'foco': 'Análise e compreensão financeira',
        'palavras_chave': ['analisar', 'entender', 'descobrir'],
        'quantidade': 4
    }
}
```

#### **Ação 2.2: Flexibilizar Validação de Similaridade** ⭐⭐⭐
```python
# Ajustar thresholds:
SIMILARITY_THRESHOLDS = {
    'title_exact_match': 95,      # Antes: 70
    'title_high_similarity': 85,   # Antes: 70
    'description_similarity': 80,  # Antes: 70 (menos rígido para descrições)
}

# Permitir variações criativas
- "Seu Primeiro Orçamento" vs "Meu Primeiro Orçamento" ✅ PERMITIR
- "Desvende Seus Gastos" vs "Desvende Seus Gastos Diários" ✅ PERMITIR
```

#### **Ação 2.3: Injetar Missões Existentes no Contexto** ⭐⭐⭐⭐
```python
# Adicionar ao prompt:
"""
IMPORTANTE: As seguintes missões JÁ EXISTEM, crie algo DIFERENTE:
1. "Seu Primeiro Orçamento!" - Registre 5 transações
2. "Desvende Seus Gastos" - Analise categorias
3. "Seu Primeiro Mapa do Tesouro" - Crie 3 categorias
...

Seja CRIATIVO e evite repetir temas ou títulos similares.
"""
```

---

### **PRIORIDADE ALTA - Utilizar Templates Eficientemente**

#### **Ação 3.1: Priorizar Templates na Fase 1** ⭐⭐⭐⭐⭐
```python
# Modificar lógica de geração híbrida:
def generate_hybrid_missions(tier, count=20):
    # FASE 1: Templates (SEMPRE usar quando disponível)
    template_missions = generate_from_templates(tier, count)
    missions_created = save_missions(template_missions)  # Salvar TODOS
    
    remaining = count - len(missions_created)
    
    if remaining > 0:
        # FASE 2: IA apenas para complementar
        ai_missions = generate_ai_missions(tier, remaining)
        missions_created.extend(ai_missions)
    
    return missions_created
```

**Benefício:** Templates são INSTANTÂNEOS (sem custo de API, sem duplicação)

#### **Ação 3.2: Expandir Biblioteca de Templates** ⭐⭐⭐
```python
# Adicionar mais variações aos templates existentes:
BEGINNER_ONBOARDING_TEMPLATES = [
    # ... templates existentes (12) ...
    
    # NOVOS: +8 templates para cobrir 20 missões
    {
        'title': 'Detective de Gastos',
        'description': 'Investigue para onde vai seu dinheiro registrando {count} transações diferentes.',
        'min_transactions_ranges': [(8, 12), (12, 15)],
        ...
    },
    # ... mais 7 templates ...
]
```

---

### **PRIORIDADE ALTA - Otimizar Performance da IA**

#### **Ação 4.1: Reduzir max_output_tokens** ⭐⭐⭐
```python
# Atual: 1500 tokens
# Otimizado: 800 tokens (missão típica usa 400-600)
generation_config={
    'temperature': 0.8,  # Aumentar criatividade
    'top_p': 0.9,
    'max_output_tokens': 800,  # ⚡ 50% mais rápido
}
```

#### **Ação 4.2: Gerar em Lotes de 3-5 Missões** ⭐⭐⭐⭐
```python
# Ao invés de 1 missão por request:
def generate_batch(count=3):
    prompt = f"""
    Gere EXATAMENTE {count} missões únicas e criativas...
    
    Retorne um array JSON com {count} objetos.
    """
    # 1 request gera 3-5 missões (3x mais rápido)
```

#### **Ação 4.3: Paralelizar Lotes com ThreadPoolExecutor** ⭐⭐⭐⭐⭐
```python
from concurrent.futures import ThreadPoolExecutor

def generate_parallel_batches(total=20, batch_size=4):
    num_batches = total // batch_size
    
    with ThreadPoolExecutor(max_workers=3) as executor:
        futures = [
            executor.submit(generate_batch, batch_size)
            for _ in range(num_batches)
        ]
        results = [f.result() for f in futures]
    
    # 20 missões em ~40s ao invés de 120s (3x mais rápido)
```

---

### **PRIORIDADE MÉDIA - Melhorar UX do Frontend**

#### **Ação 5.1: Implementar Polling com Feedback de Progresso** ⭐⭐⭐⭐⭐
```dart
// 1. Iniciar geração (retorna task_id)
final response = await _client.post('/api/missions/generate_ai_missions/', data: {...});
final taskId = response.data['task_id'];

// 2. Polling com progresso
while (true) {
  final status = await _client.get('/api/missions/generation-status/$taskId/');
  
  if (status.data['state'] == 'SUCCESS') {
    return status.data['result'];
  }
  
  // Mostrar progresso
  setState(() {
    _progress = status.data['current'] / status.data['total'];
    _statusMessage = status.data['message']; // "Gerando missão 7/20..."
  });
  
  await Future.delayed(Duration(seconds: 2));
}
```

#### **Ação 5.2: Aumentar Timeout e Adicionar Indicadores** ⭐⭐⭐
```dart
// api_client.dart
ApiClient._internal() {
  final options = BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),  // 5min para geração
    sendTimeout: const Duration(seconds: 30),
  );
}
```

```dart
// UI Component
if (_isGenerating) {
  Column(
    children: [
      CircularProgressIndicator(value: _progress),
      SizedBox(height: 12),
      Text('Gerando missões... ${(_progress * 100).toInt()}%'),
      Text(_statusMessage, style: TextStyle(fontSize: 12)),
      Text('Isso pode levar até 3 minutos', 
           style: TextStyle(color: Colors.grey)),
    ],
  )
}
```

---

### **PRIORIDADE MÉDIA - Caching e Otimização**

#### **Ação 6.1: Cache de Missões Pré-Geradas** ⭐⭐⭐⭐
```python
# Gerar missões em background e cachear
from django.core.cache import cache

def pre_generate_missions():
    """Executar via cron job diariamente"""
    for tier in ['BEGINNER', 'INTERMEDIATE', 'ADVANCED']:
        missions = generate_hybrid_missions(tier, count=20)
        cache.set(f'pre_generated_{tier}', missions, timeout=86400)  # 24h

def get_missions_for_tier(tier):
    # Tentar cache primeiro
    cached = cache.get(f'pre_generated_{tier}')
    if cached:
        return cached
    
    # Fallback: gerar sob demanda
    return generate_hybrid_missions(tier, count=20)
```

#### **Ação 6.2: Limitar Geração Simultânea** ⭐⭐⭐
```python
# Usando Redis locks
from django.core.cache import cache

def generate_with_lock(tier):
    lock_key = f'generating_missions_{tier}'
    
    if cache.get(lock_key):
        return {'error': 'Geração em andamento, aguarde...'}
    
    cache.set(lock_key, True, timeout=300)  # 5min
    try:
        missions = generate_hybrid_missions(tier)
        return missions
    finally:
        cache.delete(lock_key)
```

---

## 📋 Checklist de Implementação

### **Sprint 1: Correções Críticas (2-3 dias)**
- [ ] 1.1 Implementar geração assíncrona com Celery
- [ ] 1.2 Aumentar worker timeout para 300s
- [ ] 5.1 Implementar polling no frontend
- [ ] 5.2 Aumentar timeout do Dio e adicionar UI de progresso

### **Sprint 2: Otimização de Qualidade (2-3 dias)**
- [ ] 2.1 Criar lotes temáticos diversificados
- [ ] 2.2 Ajustar thresholds de similaridade
- [ ] 2.3 Injetar contexto de missões existentes
- [ ] 3.1 Priorizar uso de templates

### **Sprint 3: Performance (2 dias)**
- [ ] 4.1 Reduzir max_output_tokens
- [ ] 4.2 Gerar em lotes de 3-5 missões
- [ ] 4.3 Paralelizar com ThreadPoolExecutor
- [ ] 3.2 Expandir biblioteca de templates

### **Sprint 4: Otimizações Avançadas (opcional)**
- [ ] 6.1 Implementar cache de pré-geração
- [ ] 6.2 Adicionar locks de concorrência
- [ ] Monitoramento com logs estruturados
- [ ] Métricas: tempo de geração, taxa de sucesso, duplicações

---

## 📈 Resultados Esperados

### **Antes:**
- ⏱️ Tempo: 120-180s
- ✅ Taxa de Sucesso: 35% (7/20)
- 🔄 Duplicações: 65%
- ⚠️ Worker Timeout: Frequente
- 📱 UX: Timeout no frontend

### **Depois (Com Todas Otimizações):**
- ⏱️ Tempo: 30-45s (75% mais rápido)
- ✅ Taxa de Sucesso: 95%+ (19-20/20)
- 🔄 Duplicações: <5%
- ⚠️ Worker Timeout: Eliminado (async)
- 📱 UX: Feedback em tempo real, progresso visual

---

## 🎯 Métricas de Sucesso

```python
# Adicionar ao final da geração:
metrics = {
    'total_requested': 20,
    'total_created': 19,
    'success_rate': 95,
    'duration_seconds': 42,
    'from_templates': 12,
    'from_ai': 7,
    'failed_duplicates': 1,
    'failed_validation': 0,
    'failed_api': 0,
    'avg_time_per_mission': 2.1
}
```

---

## 🔧 Configurações Recomendadas

### **Backend (Django)**
```python
# settings.py
CELERY_TASK_TIME_LIMIT = 600  # 10 minutos
CELERY_TASK_SOFT_TIME_LIMIT = 540  # 9 minutos

# gunicorn.conf.py
workers = 3
timeout = 300
worker_class = 'sync'
```

### **Frontend (Flutter)**
```dart
// api_client.dart
BaseOptions(
  connectTimeout: Duration(seconds: 30),
  receiveTimeout: Duration(minutes: 1),  // Para chamada inicial (retorna task_id)
  sendTimeout: Duration(seconds: 30),
)

// Polling específico com timeout maior
dio.get(
  '/status/$taskId/',
  options: Options(
    receiveTimeout: Duration(seconds: 10),  // Polling é rápido
  ),
);
```

---

## 💡 Recomendações Adicionais

1. **Logs Estruturados:**
```python
logger.info("Mission generation started", extra={
    'tier': tier,
    'scenario': scenario,
    'requested_count': count,
    'user_id': user_id
})
```

2. **Monitoramento:**
- Prometheus/Grafana para métricas
- Sentry para erros
- CloudWatch/Railway logs

3. **Testes Automatizados:**
```python
def test_generation_performance():
    start = time.time()
    missions = generate_hybrid_missions('BEGINNER', 20)
    duration = time.time() - start
    
    assert len(missions) >= 18  # 90% sucesso mínimo
    assert duration < 60  # Menos de 1 minuto
```

4. **Fallback Strategies:**
```python
# Se IA falhar completamente
if total_created < min_acceptable (10):
    # Usar apenas templates
    return generate_from_templates_only(tier, count)
```

---

## 🚦 Implementação Sugerida (Ordem)

### **Fase 1 (URGENTE - 1 dia):**
1. Aumentar worker timeout
2. Aumentar timeout do frontend
3. Adicionar UI de "carregando" com estimativa

### **Fase 2 (CRÍTICO - 2 dias):**
4. Implementar Celery + polling
5. Priorizar templates (usar 100% disponíveis)

### **Fase 3 (IMPORTANTE - 2 dias):**
6. Lotes temáticos
7. Ajustar similaridade
8. Gerar em batches (3-5 missões)

### **Fase 4 (OTIMIZAÇÃO - 2 dias):**
9. Paralelização
10. Cache de pré-geração
11. Expandir templates

---

## ✅ Validação Final

Após implementar:
```bash
# Teste de carga
python manage.py test_mission_generation --tier=BEGINNER --count=20

# Verificar métricas
✅ Sucesso: >95%
✅ Tempo: <60s  
✅ Sem duplicatas: >95%
✅ Worker timeout: 0
```
