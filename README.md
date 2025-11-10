# GenApp - Gestão Financeira Gamificada com IA

Sistema completo de gestão de finanças pessoais com gamificação inteligente e geração automática de missões utilizando inteligência artificial.

---

## Sobre o Projeto

**GenApp** é um Trabalho de Conclusão de Curso (TCC) desenvolvido no Instituto Federal do Piauí que revoluciona a gestão de finanças pessoais ao combinar:

- 📊 **Controle Financeiro Robusto**: Sistema completo de transações, categorias e indicadores
- 🎮 **Gamificação Inteligente**: XP, níveis e missões que evoluem com o usuário
- 🤖 **IA Generativa**: Google Gemini 2.0 Flash para missões personalizadas
- 📈 **Análise Avançada**: Indicadores financeiros baseados em literatura especializada
- 🔗 **Sistema de Vinculação**: Rastreamento preciso de pagamentos e origens de recursos

O sistema incentiva hábitos financeiros saudáveis através de mecanismos de gamificação adaptativos, onde missões são geradas dinamicamente com base no perfil, comportamento e evolução financeira do usuário.

---

## Funcionalidades Principais

### 💰 Gestão Financeira Completa

**Transações e Categorização**
- Registro de receitas, despesas e dívidas com suporte a UUID
- Sistema de categorias hierárquico com 5 grupos principais:
  - Receitas: Regulares, Extras
  - Despesas: Essenciais, Estilo de Vida
  - Investimentos e Poupança
  - Dívidas e Metas
- Transações recorrentes (diárias, semanais, mensais)
- Descrições detalhadas com sugestões via IA
- Isolamento total de dados entre usuários

**Sistema de Vinculação de Transações**
- Rastreamento preciso de origem e destino de recursos
- Pagamento em lote de múltiplas despesas
- Vinculação de receitas a pagamentos de dívidas
- Prevenção de dupla contagem nos indicadores
- Proteção contra race conditions com locks de banco de dados

### 📊 Indicadores Financeiros Científicos

**TPS (Taxa de Poupança Pessoal)**
- Fórmula: `((Receitas - Despesas - Pagamentos de Dívidas) / Receitas) × 100`
- Mede percentual efetivamente poupado após todas as obrigações
- Meta recomendada: ≥15%

**RDR (Razão Dívida/Renda)**
- Fórmula: `(Pagamentos de Dívidas / Receitas) × 100`
- Mede comprometimento da renda com dívidas
- Classificação:
  - ✅ Saudável: ≤35%
  - ⚠️ Atenção: 35-42%
  - 🚨 Crítico: ≥42%

**ILI (Índice de Liquidez Imediata)**
- Fórmula: `Reservas Líquidas / Média Despesas Essenciais (3 meses)`
- Mede quantos meses a reserva cobre despesas essenciais
- Meta recomendada: ≥6 meses

**Cache Inteligente**
- Indicadores calculados sob demanda e cacheados
- Invalidação automática em mudanças relevantes
- Performance otimizada: redução de 60% em queries

### 🎮 Sistema de Gamificação Adaptativo

**Sistema de XP e Níveis**
- Progressão exponencial baseada em fórmula: `100 × (nivel²)`
- 1000+ níveis possíveis
- XP ganho por:
  - Completar missões (50-500 XP)
  - Registrar transações diariamente
  - Atingir metas financeiras
  - Manter consistência

**Missões Personalizadas por IA**
- Geração via Google Gemini 2.0 Flash
- 5 tipos de missões:
  - `ONBOARDING`: Integração inicial (níveis 1-5)
  - `TPS_IMPROVEMENT`: Melhoria de poupança
  - `RDR_REDUCTION`: Redução de dívidas
  - `ILI_BUILDING`: Construção de reserva
  - `ADVANCED`: Desafios avançados (nível 16+)
- Adaptação por faixa de usuário:
  - **Iniciantes** (1-5): Criação de hábitos básicos
  - **Intermediários** (6-15): Otimização financeira
  - **Avançados** (16+): Estratégias complexas

**Tipos de Validação de Missões**
- `SNAPSHOT`: Comparação pontual (inicial vs atual)
- `TEMPORAL`: Manter critério por período
- `CATEGORY_REDUCTION`: Reduzir gasto em categoria específica
- `CATEGORY_LIMIT`: Não exceder limite de categoria
- `GOAL_PROGRESS`: Progredir em meta específica
- `SAVINGS_INCREASE`: Aumentar poupança
- `CONSISTENCY`: Manter streaks/consistência

**Sistema de Snapshots**
- Snapshots diários automáticos (Celery Beat às 23:59)
- Snapshots mensais consolidados
- Rastreamento de progresso histórico
- Validação temporal de missões

### 🎯 Metas Financeiras

**Gestão de Objetivos**
- Criação de metas com valores-alvo e prazos
- Categorias rastreadas para cálculo automático de progresso
- Valor inicial e progresso incremental
- Visualização de progresso percentual
- Notificações de marcos alcançados

**Tipos de Metas Suportadas**
- Reserva de emergência
- Compra de bens (casa, carro, equipamentos)
- Viagens e experiências
- Educação e cursos
- Investimentos

### 👥 Sistema Social (Opcional)

**Amizades**
- Sistema de convites e aceitação
- Comparação de níveis e progresso
- Leaderboard entre amigos
- Privacidade: usuário controla visibilidade

### 📈 Análises e Visualizações

**Dashboards Interativos:**
- Resumo financeiro mensal e anual
- Indicadores em tempo real com cache inteligente
- Gráficos de evolução de indicadores (FL Chart)
- Breakdown por categoria
- Séries temporais de cashflow
- Insights automáticos baseados em padrões

**Relatórios:**
- Relatório de pagamentos de dívidas por período (endpoint `payment_report`)
- Histórico completo de transações com filtros avançados
- Evolução de indicadores ao longo do tempo via snapshots
- Estatísticas por categoria e tipo de transação

---

## Tecnologias Utilizadas

### Backend (Django)

**Framework e Core**
- **Django 4.2**: Framework web robusto e maduro
- **Django REST Framework 3.14**: API REST completa e documentada
- **PostgreSQL 14+**: Banco de dados relacional com suporte a UUID
- **Psycopg 3.2**: Driver PostgreSQL otimizado

**Autenticação e Segurança**
- **Simple JWT 5.3**: Autenticação via JSON Web Tokens
- **Token Blacklist**: Revogação de tokens em logout
- **CORS Headers 4.4**: Controle de acesso entre origens
- **Rate Limiting**: Proteção contra abuso com throttling customizado

**Inteligência Artificial**
- **Google Generative AI 0.8**: Integração com Gemini 2.0 Flash
- Geração de missões contextualizadas
- Sugestões de categorias para transações
- Custo: ~$0.01/mês (tier gratuito: 1500 req/dia)

**Tarefas Assíncronas**
- **Celery 5.3**: Processamento distribuído de tarefas
- **Redis 5.0**: Message broker e backend de resultados
- **Celery Beat 2.5**: Agendamento de tarefas periódicas
- **Celery Results 2.5**: Armazenamento de resultados no Django DB

**Deploy e Produção**
- **Gunicorn 21.0**: WSGI HTTP Server
- **WhiteNoise 6.5**: Servir arquivos estáticos
- **Python-dotenv 1.0**: Gerenciamento de variáveis de ambiente

### Frontend (Flutter)

**Framework e UI**
- **Flutter 3.5+**: Framework multiplataforma (iOS, Android, Web)
- **Dart 3.5**: Linguagem de programação otimizada
- **Material Design 3**: Design system moderno
- **Google Fonts 6.2**: Tipografia customizada

**Networking e Estado**
- **Dio 5.4**: Cliente HTTP com interceptors
- **Flutter Secure Storage 9.2**: Armazenamento seguro de tokens
- **Shared Preferences 2.2**: Preferências do usuário
- **ChangeNotifier**: Gerenciamento de estado (MVVM)

**Visualização**
- **FL Chart 0.68**: Gráficos interativos e animados
- **Confetti 0.7**: Efeitos de celebração em conquistas
- **Intl 0.19**: Internacionalização e formatação

**Arquitetura**
- **Clean Architecture**: Separação clara de responsabilidades
- **MVVM Pattern**: ViewModels e Views
- **Repository Pattern**: Abstração de fontes de dados

---

## Arquitetura do Sistema

### Backend: MVVM + Repository Pattern

```
┌─────────────────────────────────────────────────────────────┐
│                         API REST                            │
│                  (Django REST Framework)                    │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    VIEWS (ViewSets)                         │
│  • CategoryViewSet     • MissionViewSet                     │
│  • TransactionViewSet  • GoalViewSet                        │
│  • DashboardView       • UserProfileViewSet                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│               SERIALIZERS (Validação)                       │
│  • Transformação de dados                                   │
│  • Validação de entrada                                     │
│  • Nested serialization                                     │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                 SERVICES (Lógica de Negócio)                │
│  • calculate_summary()    • update_mission_progress()       │
│  • cashflow_series()      • apply_mission_reward()          │
│  • category_breakdown()   • assign_missions_automatically() │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    MODELS (ORM)                             │
│  • UserProfile    • Transaction    • Mission                │
│  • Category       • TransactionLink                         │
│  • Goal           • MissionProgress                         │
│  • Friendship     • Snapshots (Daily/Monthly)               │
└─────────────────┬───────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────────┐
│                    PostgreSQL                               │
│  • UUID Primary Keys  • Indexes otimizados                  │
│  • Constraints       • Isolamento de dados                  │
└─────────────────────────────────────────────────────────────┘
```

**Tarefas Assíncronas (Celery)**
```
┌──────────────────────────────────────────────────────────┐
│                    CELERY BEAT                           │
│              (Agendador de Tarefas)                      │
└──────────────────┬───────────────────────────────────────┘
                   │
       ┌───────────┼───────────┐
       │           │           │
       ▼           ▼           ▼
  Daily User   Daily      Monthly
  Snapshots   Mission    Snapshots
  (23:59)     Snapshots  (Último dia)
              (23:59)
```

### Frontend: Clean Architecture + MVVM

```
┌──────────────────────────────────────────────────────────┐
│                  Flutter App (UI)                        │
├──────────────────────────────────────────────────────────┤
│  Presentation Layer                                      │
│    ├── Pages/Screens                                     │
│    └── Widgets                                           │
├──────────────────────────────────────────────────────────┤
│  Feature Layer (Domain Logic)                            │
│    ├── ViewModels (ChangeNotifier)                       │
│    └── Commands (User Actions)                           │
├──────────────────────────────────────────────────────────┤
│  Core Layer                                              │
│    ├── Repositories (Data abstraction)                   │
│    ├── Services (API Client, Storage)                    │
│    ├── Models (DTOs)                                     │
│    └── Network (Dio + Interceptors)                      │
└──────────────────────────────────────────────────────────┘
```

### Fluxo de Dados Completo

```
User Action (UI)
      │
      ▼
  ViewModel (Command)
      │
      ▼
  Repository
      │
      ▼
  API Client (Dio) ──────────► Django REST API
      │                              │
      │                              ▼
      │                        JWT Authentication
      │                              │
      │                              ▼
      │                         ViewSet/View
      │                              │
      │                              ▼
      │                         Serializer
      │                              │
      │                              ▼
      │                         Services (Business Logic)
      │                              │
      │                              ▼
      │                         Models (ORM)
      │                              │
      │                              ▼
      │                         PostgreSQL
      │                              │
      ▼◄────────────────────────────┘
Response (JSON)
      │
      ▼
  Model Parsing
      │
      ▼
  State Update (notifyListeners)
      │
      ▼
  UI Rebuild (Flutter)
```

### Integração com IA (Gemini)

```
Celery Beat (Agendador)
      │
      ▼
Task: Verificar Usuários sem Missões
      │
      ▼
AI Service (ai_services.py)
      │
      ├──► Analisar Perfil do Usuário
      │      - Nível atual
      │      - Indicadores (TPS, RDR, ILI)
      │      - Histórico de transações
      │      - Missões já completadas
      │
      ├──► Determinar Cenário
      │      - BEGINNER / INTERMEDIATE / ADVANCED
      │      - Focus: TPS / RDR / ILI / MIXED
      │
      ├──► Chamar Gemini API
      │      - Prompt contextualizado
      │      - JSON Schema validation
      │      - Retry logic
      │
      └──► Criar Missões Personalizadas
           - Salvar no banco
           - Atribuir ao usuário
           - Iniciar MissionProgress
```

---

## Estrutura do Projeto

```
TCC/
├── Api/                           # Backend Django
│   ├── config/                   # Configurações do projeto
│   │   ├── settings.py          # Settings com suporte a env vars
│   │   ├── celery.py            # Configuração Celery Beat
│   │   ├── urls.py              # Roteamento principal
│   │   └── wsgi.py / asgi.py    # Entry points
│   │
│   ├── finance/                  # App principal (core business)
│   │   ├── models.py            # 12 modelos de dados
│   │   │   ├── UserProfile
│   │   │   ├── Category (5 grupos, isolamento)
│   │   │   ├── Transaction (UUID PK, recorrência)
│   │   │   ├── TransactionLink (vinculação)
│   │   │   ├── Goal (metas financeiras)
│   │   │   ├── Mission (5 tipos, 7 validações)
│   │   │   ├── MissionProgress (rastreamento)
│   │   │   ├── Friendship (social)
│   │   │   └── Snapshots (Daily/Monthly)
│   │   │
│   │   ├── views.py             # 15+ ViewSets e endpoints
│   │   │   ├── CategoryViewSet
│   │   │   ├── TransactionViewSet
│   │   │   ├── TransactionLinkViewSet (bulk_payment)
│   │   │   ├── MissionViewSet
│   │   │   ├── GoalViewSet
│   │   │   ├── DashboardView
│   │   │   └── UserProfileViewSet
│   │   │
│   │   ├── serializers.py       # DTOs e validação
│   │   │   ├── Nested serialization
│   │   │   ├── Computed fields
│   │   │   └── Write-only fields
│   │   │
│   │   ├── services.py          # Lógica de negócio (2118 linhas)
│   │   │   ├── calculate_summary() - Indicadores
│   │   │   ├── update_mission_progress() - Validação
│   │   │   ├── apply_mission_reward() - XP
│   │   │   ├── cashflow_series() - Análises
│   │   │   ├── category_breakdown() - Relatórios
│   │   │   └── assign_missions_automatically() - IA
│   │   │
│   │   ├── ai_services.py       # Integração Gemini (1448 linhas)
│   │   │   ├── generate_missions_for_user()
│   │   │   ├── suggest_category()
│   │   │   ├── 5 cenários de missões
│   │   │   └── Prompts contextualizados
│   │   │
│   │   ├── tasks.py             # Celery tasks (627 linhas)
│   │   │   ├── create_daily_user_snapshots
│   │   │   ├── create_daily_mission_snapshots
│   │   │   └── create_monthly_snapshots
│   │   │
│   │   ├── permissions.py       # Controle de acesso
│   │   ├── throttling.py        # Rate limiting customizado
│   │   ├── mixins.py            # UUID support
│   │   ├── authentication.py    # JWT helpers
│   │   ├── signals.py           # Django signals
│   │   │
│   │   ├── migrations/          # 37 migrações
│   │   │   ├── 0001_initial.py
│   │   │   ├── 0030_convert_to_uuid_pk_safe.py
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

### Boas Práticas

1. **Nunca commite** `.env` ou secrets
2. **Use senhas fortes** para banco de dados
3. **Rotacione** API keys periodicamente
4. **Monitore** logs de acesso suspeito
5. **Atualize** dependências regularmente
6. **Faça backup** do banco de dados

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

**Você pode:**
- ✅ Estudar e aprender com o código
- ✅ Usar como referência para projetos acadêmicos
- ✅ Modificar e experimentar localmente
- ✅ Citar em trabalhos acadêmicos

**Você não pode (sem autorização):**
- ❌ Usar comercialmente
- ❌ Redistribuir como próprio
- ❌ Hospedar publicamente sem créditos
- ❌ Remover atribuições

**Para uso comercial ou outras licenças, entre em contato.**

---

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
