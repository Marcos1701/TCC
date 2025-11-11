# GenApp - Gestão Financeira Gamificada com IA# GenApp - Gestão Financeira Gamificada com IA



Sistema de gestão financeira pessoal com gamificação inteligente e geração automática de missões utilizando IA.Sistema de gestão financeira pessoal com gamificação inteligente e geração automática de missões utilizando IA.



## Sobre o Projeto## 📋 Sobre o Projeto



**GenApp** é um TCC desenvolvido no IFPI que combina:**GenApp** é um TCC desenvolvido no IFPI que combina:



- 📊 **Controle Financeiro Robusto**: Transações, categorias e indicadores- 📊 **Controle Financeiro Robusto**: Transações, categorias e indicadores

- 🎮 **Gamificação Inteligente**: XP, níveis e missões adaptativas- 🎮 **Gamificação Inteligente**: XP, níveis e missões adaptativas

- 🤖 **IA Generativa**: Google Gemini 2.0 Flash para missões personalizadas- 🤖 **IA Generativa**: Google Gemini 2.0 Flash para missões personalizadas

- 📈 **Análise Avançada**: Indicadores financeiros (TPS, RDR, ILI)- 📈 **Análise Avançada**: Indicadores financeiros (TPS, RDR, ILI)

- 🔗 **Sistema de Vinculação**: Rastreamento de pagamentos e origem de recursos- 🔗 **Sistema de Vinculação**: Rastreamento de pagamentos e origem de recursos



## Tecnologias Utilizadas## Funcionalidades Principais



### Backend### 💰 Gestão Financeira Completa



- Django 4.2 + Django REST Framework 3.14**Transações e Categorização**

- PostgreSQL 14+ com UUID- Registro de receitas, despesas e dívidas com suporte a UUID

- Celery 5.3 + Redis 5.0 (tarefas assíncronas)- Sistema de categorias hierárquico com 5 grupos principais:

- Google Generative AI 0.8 (Gemini)  - Receitas: Regulares, Extras

- JWT Authentication (Simple JWT 5.3)  - Despesas: Essenciais, Estilo de Vida

  - Investimentos e Poupança

### Frontend  - Dívidas e Metas

- Transações recorrentes (diárias, semanais, mensais)

- Flutter 3.5+ (multiplataforma)- Descrições detalhadas com sugestões via IA

- Dio 5.4 (networking)- Isolamento total de dados entre usuários

- FL Chart 0.68 (gráficos)

- MVVM + Repository Pattern**Sistema de Vinculação de Transações**

- Rastreamento preciso de origem e destino de recursos

## Funcionalidades Principais- Pagamento em lote de múltiplas despesas

- Vinculação de receitas a pagamentos de dívidas

### Gestão Financeira- Prevenção de dupla contagem nos indicadores

- Proteção contra race conditions com locks de banco de dados

- Transações (receitas, despesas, dívidas) com UUID

- Categorias hierárquicas (5 grupos principais)### 📊 Indicadores Financeiros Científicos

- Transações recorrentes (diárias, semanais, mensais)

- Vinculação de transações (pagamentos em lote)**TPS (Taxa de Poupança Pessoal)**

- Isolamento total de dados entre usuários- Fórmula: `((Receitas - Despesas - Pagamentos de Dívidas) / Receitas) × 100`

- Mede percentual efetivamente poupado após todas as obrigações

### Indicadores Financeiros- Meta recomendada: ≥15%



- **TPS (Taxa de Poupança Pessoal)**: `((Receitas - Despesas - Pagamentos Dívidas) / Receitas) × 100`**RDR (Razão Dívida/Renda)**

- **RDR (Razão Dívida/Renda)**: `(Pagamentos Dívidas / Receitas) × 100`- Fórmula: `(Pagamentos de Dívidas / Receitas) × 100`

- **ILI (Índice de Liquidez Imediata)**: `Reservas / Média Despesas Essenciais (3 meses)`- Mede comprometimento da renda com dívidas

- Cache inteligente com invalidação automática- Classificação:

  - ✅ Saudável: ≤35%

### Gamificação  - ⚠️ Atenção: 35-42%

  - 🚨 Crítico: ≥42%

- Sistema de XP e níveis (progressão exponencial)

- 5 tipos de missões (ONBOARDING, TPS_IMPROVEMENT, RDR_REDUCTION, ILI_BUILDING, ADVANCED)**ILI (Índice de Liquidez Imediata)**

- 7 tipos de validação de missões (SNAPSHOT, TEMPORAL, CATEGORY_REDUCTION, etc.)- Fórmula: `Reservas Líquidas / Média Despesas Essenciais (3 meses)`

- Geração automática via IA baseada no perfil do usuário- Mede quantos meses a reserva cobre despesas essenciais

- Snapshots diários e mensais para rastreamento- Meta recomendada: ≥6 meses



### Metas Financeiras**Cache Inteligente**

- Indicadores calculados sob demanda e cacheados

- Criação de metas com valores-alvo e prazos- Invalidação automática em mudanças relevantes

- Rastreamento automático por categorias- Performance otimizada: redução de 60% em queries

- Visualização de progresso em tempo real

### 🎮 Sistema de Gamificação Adaptativo

## Configuração com Docker

**Sistema de XP e Níveis**

### Pré-requisitos- Progressão exponencial baseada em fórmula: `100 × (nivel²)`

- 1000+ níveis possíveis

- Docker 20.10+- XP ganho por:

- Docker Compose 2.0+  - Completar missões (50-500 XP)

- 2GB RAM mínimo disponível  - Registrar transações diariamente

  - Atingir metas financeiras

### Instalação Rápida  - Manter consistência



**1. Clone o repositório****Missões Personalizadas por IA**

- Geração via Google Gemini 2.0 Flash

```bash- 5 tipos de missões:

git clone <url-do-repositorio>  - `ONBOARDING`: Integração inicial (níveis 1-5)

cd TCC  - `TPS_IMPROVEMENT`: Melhoria de poupança

```  - `RDR_REDUCTION`: Redução de dívidas

  - `ILI_BUILDING`: Construção de reserva

**2. Configure as variáveis de ambiente**  - `ADVANCED`: Desafios avançados (nível 16+)

- Adaptação por faixa de usuário:

```bash  - **Iniciantes** (1-5): Criação de hábitos básicos

# Copie o arquivo de exemplo  - **Intermediários** (6-15): Otimização financeira

cp .env.example .env  - **Avançados** (16+): Estratégias complexas



# Edite as variáveis necessárias (principalmente GEMINI_API_KEY e senhas)**Tipos de Validação de Missões**

```- `SNAPSHOT`: Comparação pontual (inicial vs atual)

- `TEMPORAL`: Manter critério por período

**3. Inicie os containers**- `CATEGORY_REDUCTION`: Reduzir gasto em categoria específica

- `CATEGORY_LIMIT`: Não exceder limite de categoria

```bash- `GOAL_PROGRESS`: Progredir em meta específica

# Iniciar todos os serviços- `SAVINGS_INCREASE`: Aumentar poupança

docker-compose up -d- `CONSISTENCY`: Manter streaks/consistência



# Verificar status**Sistema de Snapshots**

docker-compose ps- Snapshots diários automáticos (Celery Beat às 23:59)

- Snapshots mensais consolidados

# Ver logs- Rastreamento de progresso histórico

docker-compose logs -f api- Validação temporal de missões

```

### 🎯 Metas Financeiras

**4. Execute as migrações e crie um superusuário**

**Gestão de Objetivos**

```bash- Criação de metas com valores-alvo e prazos

# Aplicar migrações- Categorias rastreadas para cálculo automático de progresso

docker-compose exec api python manage.py migrate- Valor inicial e progresso incremental

- Visualização de progresso percentual

# Criar cache table (para indicadores)- Notificações de marcos alcançados

docker-compose exec api python manage.py createcachetable

**Tipos de Metas Suportadas**

# Criar superusuário- Reserva de emergência

docker-compose exec api python manage.py createsuperuser- Compra de bens (casa, carro, equipamentos)

```- Viagens e experiências

- Educação e cursos

**5. Acesse a aplicação**- Investimentos



- **Backend API**: http://localhost:8000### 👥 Sistema Social (Opcional)

- **Admin Django**: http://localhost:8000/admin

- **Frontend Web**: http://localhost:3000**Amizades**

- **PostgreSQL**: localhost:5432- Sistema de convites e aceitação

- **Redis**: localhost:6379- Comparação de níveis e progresso

- Leaderboard entre amigos

### Serviços Docker- Privacidade: usuário controla visibilidade



O `docker-compose.yml` inclui:### 📈 Análises e Visualizações



- **postgres**: Banco de dados PostgreSQL 16**Dashboards Interativos:**

- **redis**: Message broker para Celery- Resumo financeiro mensal e anual

- **api**: Backend Django (porta 8000)- Indicadores em tempo real com cache inteligente

- **celery-worker**: Processamento de tarefas assíncronas- Gráficos de evolução de indicadores (FL Chart)

- **celery-beat**: Agendador de tarefas (snapshots diários às 23:59)- Breakdown por categoria

- **frontend**: Frontend Flutter (porta 3000) - opcional- Séries temporais de cashflow

- Insights automáticos baseados em padrões

### Comandos Úteis

**Relatórios:**

```bash- Relatório de pagamentos de dívidas por período (endpoint `payment_report`)

# Parar todos os serviços- Histórico completo de transações com filtros avançados

docker-compose down- Evolução de indicadores ao longo do tempo via snapshots

- Estatísticas por categoria e tipo de transação

# Parar e remover volumes (CUIDADO: apaga dados do banco)

docker-compose down -v---



# Rebuild de containers## Tecnologias Utilizadas

docker-compose build

### Backend (Django)

# Ver logs de um serviço específico

docker-compose logs -f celery-worker**Framework e Core**

- **Django 4.2**: Framework web robusto e maduro

# Acessar shell do Django- **Django REST Framework 3.14**: API REST completa e documentada

docker-compose exec api python manage.py shell- **PostgreSQL 14+**: Banco de dados relacional com suporte a UUID

- **Psycopg 3.2**: Driver PostgreSQL otimizado

# Executar testes

docker-compose exec api python manage.py test**Autenticação e Segurança**

- **Simple JWT 5.3**: Autenticação via JSON Web Tokens

# Backup do banco de dados- **Token Blacklist**: Revogação de tokens em logout

docker-compose exec postgres pg_dump -U postgres finance_db > backup.sql- **CORS Headers 4.4**: Controle de acesso entre origens

- **Rate Limiting**: Proteção contra abuso com throttling customizado

# Restaurar backup

docker-compose exec -T postgres psql -U postgres finance_db < backup.sql**Inteligência Artificial**

```- **Google Generative AI 0.8**: Integração com Gemini 2.0 Flash

- Geração de missões contextualizadas

## Instalação Manual (Desenvolvimento)- Sugestões de categorias para transações

- Custo: ~$0.01/mês (tier gratuito: 1500 req/dia)

### Backend

**Tarefas Assíncronas**

**1. Preparar ambiente**- **Celery 5.3**: Processamento distribuído de tarefas

- **Redis 5.0**: Message broker e backend de resultados

```bash- **Celery Beat 2.5**: Agendamento de tarefas periódicas

cd Api- **Celery Results 2.5**: Armazenamento de resultados no Django DB

python -m venv venv

venv\Scripts\activate  # Windows**Deploy e Produção**

# source venv/bin/activate  # Linux/Mac- **Gunicorn 21.0**: WSGI HTTP Server

pip install -r requirements.txt- **WhiteNoise 6.5**: Servir arquivos estáticos

```- **Python-dotenv 1.0**: Gerenciamento de variáveis de ambiente



**2. Configurar variáveis**### Frontend (Flutter)



```bash**Framework e UI**

# Copiar .env.example para .env e configurar- **Flutter 3.5+**: Framework multiplataforma (iOS, Android, Web)

cp .env.example .env- **Dart 3.5**: Linguagem de programação otimizada

```- **Material Design 3**: Design system moderno

- **Google Fonts 6.2**: Tipografia customizada

**3. Configurar banco de dados**

**Networking e Estado**

```bash- **Dio 5.4**: Cliente HTTP com interceptors

# Com PostgreSQL instalado localmente ou use Docker:- **Flutter Secure Storage 9.2**: Armazenamento seguro de tokens

docker run --name genapp-postgres -e POSTGRES_PASSWORD=postgres123 -e POSTGRES_DB=finance_db -p 5432:5432 -d postgres:16-alpine- **Shared Preferences 2.2**: Preferências do usuário

- **ChangeNotifier**: Gerenciamento de estado (MVVM)

# Com Redis:

docker run --name genapp-redis -p 6379:6379 -d redis:7-alpine**Visualização**

```- **FL Chart 0.68**: Gráficos interativos e animados

- **Confetti 0.7**: Efeitos de celebração em conquistas

**4. Executar migrações**- **Intl 0.19**: Internacionalização e formatação



```bash**Arquitetura**

python manage.py migrate- **Clean Architecture**: Separação clara de responsabilidades

python manage.py createcachetable- **MVVM Pattern**: ViewModels e Views

python manage.py createsuperuser- **Repository Pattern**: Abstração de fontes de dados

```

---

**5. Iniciar servidor**

## Arquitetura do Sistema

```bash

python manage.py runserver### Backend: MVVM + Repository Pattern

```

```

**6. Iniciar Celery (terminais separados)**┌─────────────────────────────────────────────────────────────┐

│                         API REST                            │

```bash│                  (Django REST Framework)                    │

# Worker└─────────────────┬───────────────────────────────────────────┘

celery -A config worker -l info --pool=solo  # Windows                  │

# celery -A config worker -l info  # Linux/Mac┌─────────────────▼───────────────────────────────────────────┐

│                    VIEWS (ViewSets)                         │

# Beat│  • CategoryViewSet     • MissionViewSet                     │

celery -A config beat -l info│  • TransactionViewSet  • GoalViewSet                        │

```│  • DashboardView       • UserProfileViewSet                 │

└─────────────────┬───────────────────────────────────────────┘

### Frontend                  │

┌─────────────────▼───────────────────────────────────────────┐

**1. Instalar dependências**│               SERIALIZERS (Validação)                       │

│  • Transformação de dados                                   │

```bash│  • Validação de entrada                                     │

cd Front│  • Nested serialization                                     │

flutter pub get└─────────────────┬───────────────────────────────────────────┘

```                  │

┌─────────────────▼───────────────────────────────────────────┐

**2. Executar aplicativo**│                 SERVICES (Lógica de Negócio)                │

│  • calculate_summary()    • update_mission_progress()       │

```bash│  • cashflow_series()      • apply_mission_reward()          │

# Web│  • category_breakdown()   • assign_missions_automatically() │

flutter run -d chrome└─────────────────┬───────────────────────────────────────────┘

                  │

# Mobile (com emulador/device conectado)┌─────────────────▼───────────────────────────────────────────┐

flutter run│                    MODELS (ORM)                             │

│  • UserProfile    • Transaction    • Mission                │

# Build para produção│  • Category       • TransactionLink                         │

flutter build web --release│  • Goal           • MissionProgress                         │

```│  • Friendship     • Snapshots (Daily/Monthly)               │

└─────────────────┬───────────────────────────────────────────┘

## Estrutura do Projeto                  │

┌─────────────────▼───────────────────────────────────────────┐

```│                    PostgreSQL                               │

TCC/│  • UUID Primary Keys  • Indexes otimizados                  │

├── Api/                          # Backend Django│  • Constraints       • Isolamento de dados                  │

│   ├── config/                   # Configurações└─────────────────────────────────────────────────────────────┘

│   │   ├── settings.py          # Settings com env vars```

│   │   ├── celery.py            # Celery config

│   │   └── urls.py              # Rotas**Tarefas Assíncronas (Celery)**

│   ├── finance/                  # App principal```

│   │   ├── models.py            # 12 modelos de dados┌──────────────────────────────────────────────────────────┐

│   │   ├── views.py             # 15+ ViewSets│                    CELERY BEAT                           │

│   │   ├── serializers.py       # DTOs e validação│              (Agendador de Tarefas)                      │

│   │   ├── services.py          # Lógica de negócio└──────────────────┬───────────────────────────────────────┘

│   │   ├── ai_services.py       # Integração Gemini                   │

│   │   ├── tasks.py             # Celery tasks       ┌───────────┼───────────┐

│   │   ├── permissions.py       # Controle de acesso       │           │           │

│   │   ├── throttling.py        # Rate limiting       ▼           ▼           ▼

│   │   └── migrations/          # 39 migrações  Daily User   Daily      Monthly

│   ├── Dockerfile               # Imagem produção  Snapshots   Mission    Snapshots

│   ├── Dockerfile.dev           # Imagem desenvolvimento  (23:59)     Snapshots  (Último dia)

│   └── requirements.txt         # Dependências Python              (23:59)

│```

├── Front/                        # Frontend Flutter

│   ├── lib/### Frontend: Clean Architecture + MVVM

│   │   ├── core/                # Shared core (models, network, storage)

│   │   └── features/            # Módulos funcionais```

│   ├── Dockerfile               # Build web┌──────────────────────────────────────────────────────────┐

│   └── pubspec.yaml             # Dependências Flutter│                  Flutter App (UI)                        │

│├──────────────────────────────────────────────────────────┤

├── docker-compose.yml            # Orquestração completa│  Presentation Layer                                      │

├── .env.example                  # Template de configuração│    ├── Pages/Screens                                     │

└── README.md                     # Este arquivo│    └── Widgets                                           │

```├──────────────────────────────────────────────────────────┤

│  Feature Layer (Domain Logic)                            │

## Segurança│    ├── ViewModels (ChangeNotifier)                       │

│    └── Commands (User Actions)                           │

### Medidas Implementadas├──────────────────────────────────────────────────────────┤

│  Core Layer                                              │

- JWT com refresh token rotation│    ├── Repositories (Data abstraction)                   │

- Token blacklist em logout│    ├── Services (API Client, Storage)                    │

- Rate limiting por endpoint│    ├── Models (DTOs)                                     │

- CORS configurado│    └── Network (Dio + Interceptors)                      │

- Isolamento de dados por usuário└──────────────────────────────────────────────────────────┘

- Validação em múltiplas camadas```

- SELECT FOR UPDATE em operações críticas

- Secure storage para tokens (frontend)### Fluxo de Dados Completo



## Testes```

User Action (UI)

```bash      │

# Backend      ▼

cd Api  ViewModel (Command)

python manage.py test      │

      ▼

# Com cobertura  Repository

pip install coverage      │

coverage run --source='finance' manage.py test      ▼

coverage report  API Client (Dio) ──────────► Django REST API

      │                              │

# Frontend      │                              ▼

cd Front      │                        JWT Authentication

flutter test      │                              │

```      │                              ▼

      │                         ViewSet/View

## Performance      │                              │

      │                              ▼

### Otimizações Implementadas      │                         Serializer

      │                              │

- Cache de indicadores (5 min TTL)      │                              ▼

- Indexes otimizados em queries frequentes      │                         Services (Business Logic)

- Select/prefetch related      │                              │

- Aggregation queries otimizadas      │                              ▼

- Connection pooling      │                         Models (ORM)

- Paginação de resultados      │                              │

      │                              ▼

## Troubleshooting      │                         PostgreSQL

      │                              │

### Backend não conecta ao banco      ▼◄────────────────────────────┘

Response (JSON)

```bash      │

# Verificar se PostgreSQL está rodando      ▼

docker-compose ps postgres  Model Parsing

      │

# Ver logs do PostgreSQL      ▼

docker-compose logs postgres  State Update (notifyListeners)

      │

# Testar conexão      ▼

docker-compose exec postgres psql -U postgres -d finance_db  UI Rebuild (Flutter)

``````



### Celery não processa tasks### Integração com IA (Gemini)



```bash```

# Verificar RedisCelery Beat (Agendador)

docker-compose exec redis redis-cli ping      │

      ▼

# Ver logs do workerTask: Verificar Usuários sem Missões

docker-compose logs -f celery-worker      │

      ▼

# Listar tasks registradasAI Service (ai_services.py)

docker-compose exec celery-worker celery -A config inspect registered      │

```      ├──► Analisar Perfil do Usuário

      │      - Nível atual

### Frontend não conecta ao backend      │      - Indicadores (TPS, RDR, ILI)

      │      - Histórico de transações

- Verifique se a API está rodando: http://localhost:8000/admin      │      - Missões já completadas

- Android emulador: use `10.0.2.2:8000` ao invés de `localhost`      │

- Configure CORS no `.env` do backend      ├──► Determinar Cenário

      │      - BEGINNER / INTERMEDIATE / ADVANCED

### Missões não são geradas      │      - Focus: TPS / RDR / ILI / MIXED

      │

- Verifique `GEMINI_API_KEY` no `.env`      ├──► Chamar Gemini API

- Verifique logs do Celery Beat: `docker-compose logs -f celery-beat`      │      - Prompt contextualizado

- Teste manualmente no Django shell      │      - JSON Schema validation

      │      - Retry logic

## Variáveis de Ambiente Importantes      │

      └──► Criar Missões Personalizadas

```env           - Salvar no banco

# Backend           - Atribuir ao usuário

DJANGO_SECRET_KEY=<gere com Django: python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())">           - Iniciar MissionProgress

GEMINI_API_KEY=<obtenha em https://aistudio.google.com/apikey>```



# Database---

POSTGRES_DB=finance_db

POSTGRES_USER=postgres## Estrutura do Projeto

POSTGRES_PASSWORD=<senha-segura>

```

# RedisTCC/

REDIS_URL=redis://redis:6379/0├── Api/                           # Backend Django

│   ├── config/                   # Configurações do projeto

# JWT│   │   ├── settings.py          # Settings com suporte a env vars

JWT_ACCESS_TOKEN_LIFETIME_MINUTES=15│   │   ├── celery.py            # Configuração Celery Beat

JWT_REFRESH_TOKEN_LIFETIME_DAYS=7│   │   ├── urls.py              # Roteamento principal

```│   │   └── wsgi.py / asgi.py    # Entry points

│   │

## Arquitetura do Sistema│   ├── finance/                  # App principal (core business)

│   │   ├── models.py            # 12 modelos de dados

### Backend: MVVM + Repository Pattern│   │   │   ├── UserProfile

│   │   │   ├── Category (5 grupos, isolamento)

```│   │   │   ├── Transaction (UUID PK, recorrência)

API REST (Django REST Framework)│   │   │   ├── TransactionLink (vinculação)

      ↓│   │   │   ├── Goal (metas financeiras)

VIEWS (ViewSets) - CategoryViewSet, TransactionViewSet, etc.│   │   │   ├── Mission (5 tipos, 7 validações)

      ↓│   │   │   ├── MissionProgress (rastreamento)

SERIALIZERS (Validação) - Transformação e validação de dados│   │   │   ├── Friendship (social)

      ↓│   │   │   └── Snapshots (Daily/Monthly)

SERVICES (Lógica de Negócio) - calculate_summary(), update_mission_progress()│   │   │

      ↓│   │   ├── views.py             # 15+ ViewSets e endpoints

MODELS (ORM) - UserProfile, Transaction, Mission, etc.│   │   │   ├── CategoryViewSet

      ↓│   │   │   ├── TransactionViewSet

PostgreSQL│   │   │   ├── TransactionLinkViewSet (bulk_payment)

```│   │   │   ├── MissionViewSet

│   │   │   ├── GoalViewSet

### Frontend: Clean Architecture + MVVM│   │   │   ├── DashboardView

│   │   │   └── UserProfileViewSet

```│   │   │

UI (Flutter Widgets)│   │   ├── serializers.py       # DTOs e validação

      ↓│   │   │   ├── Nested serialization

ViewModels (ChangeNotifier) + Commands│   │   │   ├── Computed fields

      ↓│   │   │   └── Write-only fields

Repositories (Data abstraction)│   │   │

      ↓│   │   ├── services.py          # Lógica de negócio (2118 linhas)

Services (API Client - Dio)│   │   │   ├── calculate_summary() - Indicadores

      ↓│   │   │   ├── update_mission_progress() - Validação

Django REST API│   │   │   ├── apply_mission_reward() - XP

```│   │   │   ├── cashflow_series() - Análises

│   │   │   ├── category_breakdown() - Relatórios

### Tarefas Assíncronas (Celery)│   │   │   └── assign_missions_automatically() - IA

│   │   │

```│   │   ├── ai_services.py       # Integração Gemini (1448 linhas)

Celery Beat (Agendador)│   │   │   ├── generate_missions_for_user()

      ↓│   │   │   ├── suggest_category()

Daily User Snapshots (23:59)│   │   │   ├── 5 cenários de missões

Daily Mission Snapshots (23:59)│   │   │   └── Prompts contextualizados

Monthly Snapshots (último dia do mês)│   │   │

      ↓│   │   ├── tasks.py             # Celery tasks (627 linhas)

PostgreSQL│   │   │   ├── create_daily_user_snapshots

```│   │   │   ├── create_daily_mission_snapshots

│   │   │   └── create_monthly_snapshots

## Desenvolvimento│   │   │

│   │   ├── permissions.py       # Controle de acesso

**Desenvolvedor**: Marcos Eduardo de Neiva Santos  │   │   ├── throttling.py        # Rate limiting customizado

**Instituição**: Instituto Federal do Piauí (IFPI)  │   │   ├── mixins.py            # UUID support

**Curso**: Tecnologia em Análise e Desenvolvimento de Sistemas  │   │   ├── authentication.py    # JWT helpers

**Ano**: 2024/2025│   │   ├── signals.py           # Django signals

│   │   │

## Contexto Acadêmico│   │   ├── migrations/          # 37 migrações

│   │   │   ├── 0001_initial.py

Este projeto foi desenvolvido como Trabalho de Conclusão de Curso (TCC) e está disponível para fins educacionais e acadêmicos.│   │   │   ├── 0030_convert_to_uuid_pk_safe.py

│   │   │   ├── 0034_isolate_categories.py
│   │   │   ├── 0036_performance_indexes.py
│   │   │   └── 0037_add_snapshot_models.py
│   │   │
│   │   └── tests/               # Testes automatizados
│   │       ├── test_category_isolation.py
│   │       ├── test_rate_limiting.py
│   │       └── test_uuid_integration.py
│   │
│   ├── requirements.txt         # 14 dependências Python
│   ├── manage.py                # Django CLI
│   ├── create_admin.py          # Script setup admin
│   └── .env.example             # Template de configuração
│
├── Front/                        # Frontend Flutter
│   ├── lib/
│   │   ├── main.dart            # Entry point
│   │   ├── app.dart             # MaterialApp config
│   │   │
│   │   ├── core/                # Shared core
│   │   │   ├── network/
│   │   │   │   └── api_client.dart (refresh automático)
│   │   │   ├── storage/
│   │   │   │   └── secure_storage_service.dart
│   │   │   ├── models/
│   │   │   │   ├── user.dart
│   │   │   │   ├── category.dart
│   │   │   │   ├── transaction.dart
│   │   │   │   └── mission.dart
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── theme/
│   │   │   ├── utils/
│   │   │   └── widgets/
│   │   │
│   │   └── features/            # Módulos funcionais
│   │       ├── auth/            # Login, registro
│   │       ├── onboarding/      # Tutorial inicial
│   │       ├── home/            # Dashboard principal
│   │       ├── dashboard/       # Indicadores
│   │       ├── transactions/    # CRUD transações
│   │       ├── missions/        # Sistema de missões
│   │       ├── progress/        # Metas e progresso
│   │       ├── analytics/       # Gráficos e análises
│   │       ├── friends/         # Sistema social
│   │       ├── settings/        # Configurações
│   │       └── shared/          # Componentes compartilhados
│   │
│   ├── android/                 # Build Android
│   ├── ios/                     # Build iOS
│   ├── web/                     # Build Web
│   ├── pubspec.yaml             # Dependências (7 packages)
│   └── analysis_options.yaml    # Linting
│
├── DOC_LATEX/                    # Documentação acadêmica
│   ├── projeto.tex              # Documento principal LaTeX
│   ├── bibliografia.bib         # Referências bibliográficas
│   └── imagens/                 # Diagramas e screenshots
│
├── scripts/                      # Scripts de automação
│
├── Procfile                      # Configuração Railway
├── railway.json                  # Deploy config
├── runtime.txt                   # Python version
├── VALIDACOES_MODELOS_COMPLETAS.md
├── VALIDACOES_SISTEMA_PAGAMENTO.md
└── README.md                     # Este arquivo
```


---

## Configuração e Instalação

### Pré-requisitos

**Backend:**
- Python 3.11+
- PostgreSQL 14+ (ou SQLite para desenvolvimento)
- Redis 5+ (para Celery)
- Conta Google Cloud (API Key do Gemini)

**Frontend:**
- Flutter 3.5+
- Dart SDK 3.5+
- Android Studio / Xcode (para mobile)
- Chrome (para web)

### Instalação do Backend (Django)

**1. Clone o repositório**

```bash
git clone <url-do-repositorio>
cd TCC/Api
```

**2. Crie e ative o ambiente virtual**

```bash
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac
```

**3. Instale as dependências**

```bash
pip install -r requirements.txt
```

**4. Configure as variáveis de ambiente**

Crie um arquivo `.env` baseado no `.env.example`:

```env
# Django Core
DJANGO_SECRET_KEY=sua-chave-secreta-aqui-use-gerador
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

# Database PostgreSQL
DB_NAME=genapp_db
DB_USER=postgres
DB_PASSWORD=sua-senha-segura
DB_HOST=localhost
DB_PORT=5432
DB_REQUIRE_SSL=False
DB_CONN_MAX_AGE=60

# Google Gemini AI
GEMINI_API_KEY=sua-chave-gemini-aqui

# Redis & Celery
REDIS_URL=redis://localhost:6379/0
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=django-db

# JWT Tokens
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=15
JWT_REFRESH_TOKEN_LIFETIME_DAYS=7

# Rate Limiting
THROTTLE_ANON_RATE=100
THROTTLE_USER_RATE=2000
```

**5. Execute as migrações**

```bash
python manage.py migrate
```

**6. Crie categorias padrão do sistema (opcional)**

```bash
python manage.py shell
>>> from finance.services import create_default_categories
>>> from django.contrib.auth import get_user_model
>>> User = get_user_model()
>>> admin = User.objects.first()  # ou crie um usuário
>>> create_default_categories(admin)
```

**7. Crie um superusuário**

```bash
python manage.py createsuperuser
# OU use o script auxiliar:
python create_admin.py
```

**8. Inicie o servidor de desenvolvimento**

```bash
python manage.py runserver
```

O backend estará disponível em `http://localhost:8000`

**9. Inicie o Celery (em terminais separados)**

Terminal 1 - Worker:
```bash
celery -A config worker -l info --pool=solo  # Windows
# celery -A config worker -l info  # Linux/Mac
```

Terminal 2 - Beat (agendador):
```bash
celery -A config beat -l info
```

### Instalação do Frontend (Flutter)

**1. Navegue até o diretório**

```bash
cd TCC/Front
```

**2. Instale as dependências**

```bash
flutter pub get
```

**3. Configure a URL da API (opcional)**

O app detecta automaticamente:
- **Web**: usa a origem atual ou `localhost:8000`
- **Android**: usa `10.0.2.2:8000` (emulador)
- **iOS/Desktop**: usa `localhost:8000`

Para override manual, compile com:
```bash
flutter run --dart-define=API_BASE_URL=http://seu-servidor:8000
```

**4. Execute o aplicativo**

Para desenvolvimento:
```bash
flutter run
```

Para plataforma específica:
```bash
flutter run -d chrome        # Web
flutter run -d windows       # Windows Desktop
flutter run -d android       # Android
flutter run -d ios           # iOS
```

**5. Build para produção**

```bash
# Web
flutter build web --release

# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

---

## Uso do Sistema

### Primeiro Acesso

1. **Registro de Conta**
   - Abra o app Flutter
   - Clique em "Criar Conta"
   - Preencha: nome, email, senha
   - Confirme o email (se configurado)

2. **Tutorial Inicial (Onboarding)**
   - Configure suas metas iniciais (TPS, RDR, ILI)
   - Crie suas primeiras categorias personalizadas
   - Registre sua primeira transação
   - Receba missões de integração

3. **Configuração Inicial**
   - Defina categorias de receitas e despesas
   - Configure notificações (opcional)
   - Adicione amigos (opcional)

### Workflow Diário Recomendado

**Manhã:**
1. Abra o app e veja resumo de ontem
2. Confira missões ativas do dia
3. Verifique metas próximas de vencimento

**Durante o Dia:**
1. Registre transações conforme ocorrem
2. Use sugestões de categoria da IA
3. Vincule pagamentos a despesas/dívidas quando aplicável

**Noite (antes das 23:59):**
1. Revise transações do dia
2. Complete missões diárias
3. Acompanhe progresso de indicadores

**Semanal:**
1. Analise gráficos de evolução
2. Ajuste orçamentos de categorias
3. Planeje próxima semana baseado em insights

**Mensal:**
1. Revise relatório mensal completo
2. Atualize metas financeiras
3. Celebre conquistas e níveis alcançados

### Funcionalidades Principais

#### 📊 Dashboard

**Indicadores em Tempo Real:**
- TPS, RDR, ILI calculados automaticamente
- Cache de 5 minutos para performance
- Gráficos de evolução temporal

**Acesso:**
- Menu principal → "Dashboard"
- Refresh manual: arraste para baixo
- Invalidação automática ao criar/editar transações

#### 💰 Transações

**Criar Transação:**
1. Botão "+" no canto inferior
2. Selecione tipo (Receita/Despesa/Dívida)
3. Preencha:
   - Descrição (sugestão automática de categoria via IA)
   - Valor
   - Data
   - Categoria
   - Recorrência (opcional)
4. Salvar

**Transações Recorrentes:**
- Configure: Diária, Semanal, Mensal
- Defina valor e unidade (1-365)
- Data de término opcional
- Campos preparados para criação automática futura

**Vinculação de Transações:**
- Pagamento de despesas: vincule receita → despesa
- Pagamento de dívidas: vincule receita → dívida
- Pagamento em lote: selecione múltiplas despesas
- Rastreamento de origem de recursos

#### 🎯 Metas

**Criar Meta:**
1. Menu → "Progresso" → "Nova Meta"
2. Defina:
   - Título e descrição
   - Valor alvo
   - Valor inicial (opcional)
   - Prazo
   - Categorias rastreadas
3. Salvar

**Acompanhamento:**
- Progresso automático baseado em transações das categorias
- Visualização percentual e valores
- Alertas visuais in-app de progresso

#### 🎮 Missões

**Tipos de Missões:**
- **Integração**: Primeiros passos (níveis 1-5)
- **TPS**: Melhorar poupança
- **RDR**: Reduzir dívidas
- **ILI**: Construir reserva
- **Avançadas**: Desafios complexos (nível 16+)

**Validação Automática:**
- Snapshots diários às 23:59
- Verificação de progresso contínuo
- Detecção de violações de critérios
- Rastreamento de streaks

**Recompensas:**
- XP base: 50-500 pontos
- Multiplicador por dificuldade
- Bônus por streak
- Progressão de nível automática

#### 👥 Sistema Social

**Adicionar Amigos:**
1. Menu → "Amigos" → "Adicionar"
2. Buscar por username
3. Enviar convite
4. Aguardar aceitação

**Funcionalidades:**
- Comparar níveis e XP
- Ver conquistas (sem valores financeiros)
- Leaderboard entre amigos
- Motivação mútua

---

## Desenvolvimento e Testes

### Testes Backend

**Executar todos os testes:**
```bash
cd Api
python manage.py test
```

**Testes específicos:**
```bash
# Isolamento de categorias
python manage.py test finance.tests.test_category_isolation

# Rate limiting
python manage.py test finance.tests.test_rate_limiting

# Integração UUID
python manage.py test finance.tests.test_uuid_integration
```

**Cobertura de código:**
```bash
pip install coverage
coverage run --source='finance' manage.py test
coverage report
coverage html  # Gera relatório HTML em htmlcov/
```

### Testes Frontend

**Executar testes:**
```bash
cd Front
flutter test
```

**Testes de widget:**
```bash
flutter test test/widget_test.dart
```

### Debugging

**Backend:**
- Django Debug Toolbar (se DEBUG=True)
- Logs em `console` e arquivos
- Admin panel: `http://localhost:8000/admin`

**Frontend:**
- Flutter DevTools
- Debug mode: `flutter run --debug`
- Logs: `print()` statements
- Network inspector

### Performance

**Backend - Otimizações Implementadas:**
- ✅ Cache de indicadores (5 min TTL)
- ✅ Indexes em queries frequentes
- ✅ Select/prefetch related
- ✅ Aggregation queries otimizadas
- ✅ Connection pooling
- ✅ Rate limiting por operação

**Frontend - Otimizações:**
- ✅ Cache de responses
- ✅ Paginação de listas
- ✅ Lazy loading de imagens
- ✅ Debouncing de inputs
- ✅ State management eficiente

---

## Deploy

### Railway (Usado em Desenvolvimento)

O projeto inclui configuração para deploy no Railway:

**Arquivos:**
- `Procfile`: Define processos (web, worker, beat)
- `railway.json`: Configurações de build
- `runtime.txt`: Python 3.11

**Processos:**
```
web: gunicorn config.wsgi --bind 0.0.0.0:$PORT
worker: celery -A config worker -l info
beat: celery -A config beat -l info
```

**Variáveis de Ambiente:**
- Configure todas as variáveis do `.env.example`
- Adicione `DATABASE_URL` (provisionado automaticamente)
- Defina `DJANGO_ALLOWED_HOSTS` com domínio do Railway

**Notas:**
- Railway foi usado apenas para testes e demonstração
- Para produção, considere AWS, Google Cloud, Azure ou Digital Ocean
- PostgreSQL e Redis devem ser provisionados separadamente

### Deploy Manual (Produção)

**Preparação:**
1. Configure servidor Linux (Ubuntu 22.04 LTS recomendado)
2. Instale: Python 3.11, PostgreSQL 14, Redis, Nginx
3. Configure firewall (UFW)
4. Obtenha certificado SSL (Let's Encrypt)

**Backend:**
```bash
# Clonar repo
git clone <repo> /var/www/genapp
cd /var/www/genapp/Api

# Ambiente virtual
python3.11 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Configurar .env (produção)
DEBUG=False
ALLOWED_HOSTS=seu-dominio.com
DATABASE_URL=postgresql://...

# Migrações e collectstatic
python manage.py migrate
python manage.py collectstatic --noinput

# Gunicorn + systemd
sudo nano /etc/systemd/system/genapp.service
sudo systemctl enable genapp
sudo systemctl start genapp

# Celery worker + beat (systemd)
sudo nano /etc/systemd/system/genapp-worker.service
sudo nano /etc/systemd/system/genapp-beat.service
```

**Frontend (Web):**
```bash
cd Front
flutter build web --release
# Servir com Nginx
sudo cp -r build/web/* /var/www/html/genapp
```

**Nginx:**
```nginx
server {
    listen 80;
    server_name seu-dominio.com;
    
    # Frontend
    location / {
        root /var/www/html/genapp;
        try_files $uri $uri/ /index.html;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # Static files
    location /static/ {
        alias /var/www/genapp/Api/static/;
    }
}
```

---

## Segurança

### Medidas Implementadas

**Backend:**
- ✅ JWT com refresh token rotation
- ✅ Token blacklist em logout
- ✅ Rate limiting por endpoint
- ✅ CORS configurado corretamente
- ✅ SQL injection protection (ORM)
- ✅ XSS protection (serializers)
- ✅ CSRF protection
- ✅ Isolamento de dados por usuário
- ✅ Validações em 3 camadas
- ✅ SELECT FOR UPDATE em operações críticas

**Frontend:**
- ✅ Secure storage para tokens
- ✅ Auto-refresh de tokens
- ✅ Validação de inputs
- ✅ Sanitização de dados
- ✅ HTTPS enforced em produção

---

## Troubleshooting

### Problemas Comuns

**Backend não inicia:**
```bash
# Verificar portas em uso
netstat -ano | findstr :8000

# Verificar logs
python manage.py runserver --verbosity 3

# Recriar banco (ATENÇÃO: apaga dados)
python manage.py flush
python manage.py migrate
```

**Celery não processa tasks:**
```bash
# Verificar conexão Redis
redis-cli ping

# Listar tasks registradas
celery -A config inspect registered

# Logs detalhados
celery -A config worker -l debug
```

**Flutter não conecta ao backend:**
- Verifique URL no `api_client.dart`
- Android: use `10.0.2.2` para localhost
- iOS: adicione permissões de rede no `Info.plist`
- Web: configure CORS no Django

**Erro "category não encontrada":**
- Execute script de criação de categorias padrão
- Verifique isolamento de categorias por usuário

**Missões não são geradas:**
- Verifique GEMINI_API_KEY no `.env`
- Teste API Gemini: `python manage.py shell`
- Verifique logs do Celery Beat

---

## Licença e Uso Acadêmico

Este projeto foi desenvolvido como **Trabalho de Conclusão de Curso (TCC)** do curso de Tecnologia em Análise e Desenvolvimento de Sistemas do Instituto Federal do Piauí (IFPI).

**Licença:** Este código é disponibilizado para fins **educacionais e acadêmicos**.

## Referências Bibliográficas

1. **Educação Financeira:**
   - KIYOSAKI, Robert T. *Pai Rico, Pai Pobre*. Alta Books, 2017.
   - CERBASI, Gustavo. *Investimentos Inteligentes*. Thomas Nelson Brasil, 2013.

2. **Gamificação:**
   - DETERDING, S. et al. *Gamification: Toward a Definition*. CHI 2011.
   - ZICHERMANN, G.; CUNNINGHAM, C. *Gamification by Design*. O'Reilly, 2011.

3. **Tecnologias:**
   - Django Documentation: https://docs.djangoproject.com/
   - Flutter Documentation: https://docs.flutter.dev/
   - Google Gemini API: https://ai.google.dev/

---

## Contato e Contribuições

**Desenvolvedor:** Marcos Eduardo de Neiva Santos  
**Instituição:** Instituto Federal do Piauí (IFPI)  
**Orientador:** Ricardo  
**Curso:** Tecnologia em Análise e Desenvolvimento de Sistemas  
**Ano:** 2024/2025

**Repositório:** GitHub - [Link quando disponível]  
**Email:** [Contato quando disponível]

---

## Agradecimentos

- **Google Gemini** pela API de IA generativa
- **Comunidade Django** pelo framework robusto e documentação
- **Comunidade Flutter** pela excelente ferramenta multiplataforma
- **Professor Orientador** pela orientação e suporte
- **Colegas de curso** pelas contribuições e testes
- **Usuários beta** pelos feedbacks valiosos
- **Instituto Federal do Piauí** pela formação acadêmica

---

## Changelog

### v1.0.0 (Atual - TCC)
- ✅ Sistema completo de transações com UUID
- ✅ Vinculação de transações (pagamentos)
- ✅ Indicadores financeiros (TPS, RDR, ILI)
- ✅ Gamificação com XP e níveis
- ✅ Missões geradas por IA (Gemini 2.0 Flash)
- ✅ Sistema de metas financeiras
- ✅ Snapshots diários e mensais
- ✅ Sistema social (amizades)
- ✅ 37 migrações de banco de dados
- ✅ Testes automatizados
- ✅ Deploy em Railway (demo)

### Próximas Versões (Roadmap)
- 🔮 Notificações push nativas (atualmente: dialogs in-app)
- 🔮 Exportação de relatórios PDF/Excel
- 🔮 Criação automática de transações recorrentes
- 🔮 Integração com Open Banking
- 🔮 Machine Learning para previsões financeiras
- 🔮 App mobile nativo otimizado
- 🔮 Modo offline com sincronização
- 🔮 Múltiplos idiomas (i18n completo)

---

**⭐ Se este projeto foi útil, considere dar uma estrela no GitHub!**

**📚 Documentação completa disponível em:** `DOC_LATEX/projeto.tex`
