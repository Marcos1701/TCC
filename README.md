# GenApp - Gestão Financeira Gamificada com IA

Sistema de gestão de finanças pessoais com gamificação e geração automática de missões utilizando inteligência artificial.

---

## Sobre o Projeto

GenApp é um Trabalho de Conclusão de Curso (TCC) que combina gestão financeira pessoal com elementos de gamificação para incentivar hábitos financeiros saudáveis. O sistema utiliza o Google Gemini para gerar missões personalizadas baseadas no perfil e comportamento financeiro do usuário.

### Funcionalidades Principais

- **Gestão de Transações**: Registro e categorização de receitas e despesas
- **Indicadores Financeiros**: ILI (Índice de Liberdade Individual), reservas, independência financeira
- **Sistema de Gamificação**: XP, níveis, missões e conquistas
- **Missões Personalizadas**: Geradas por IA com base no comportamento do usuário
- **Metas Financeiras**: Criação e acompanhamento de objetivos
- **Sistema Social**: Amizades e comparação de progresso (opcional)
- **Análises Visuais**: Gráficos e relatórios financeiros

### Tecnologias Utilizadas

**Backend:**
- Django 4.2 + Django REST Framework
- PostgreSQL (banco de dados)
- Celery + Redis (tarefas assíncronas)
- Google Gemini API (geração de missões)
- JWT (autenticação)

**Frontend:**
- Flutter 3.5
- Dio (requisições HTTP)
- FL Chart (visualizações)
- Flutter Secure Storage (armazenamento seguro)

---

## Estrutura do Projeto

```
TCC/
├── Api/                    # Backend Django
│   ├── config/            # Configurações do projeto
│   ├── finance/           # App principal
│   │   ├── models.py     # Modelos de dados
│   │   ├── views.py      # Endpoints da API
│   │   ├── serializers.py # Serialização de dados
│   │   ├── services.py   # Lógica de negócio
│   │   ├── ai_services.py # Integração com Gemini
│   │   ├── tasks.py      # Tarefas Celery
│   │   └── migrations/   # Migrações do banco
│   └── requirements.txt  # Dependências Python
│
├── Front/                 # Frontend Flutter
│   ├── lib/
│   │   ├── core/         # Configurações, modelos, serviços
│   │   ├── features/     # Funcionalidades por módulo
│   │   └── presentation/ # Telas e widgets
│   └── pubspec.yaml      # Dependências Flutter
│
└── DOC_LATEX/            # Documentação do TCC
```

---

## Configuração e Instalação

### Pré-requisitos

- Python 3.11+
- PostgreSQL 14+
- Redis
- Flutter 3.5+
- Chave de API do Google Gemini

### Backend (Django)

1. **Clone o repositório**
```bash
git clone <url-do-repositorio>
cd TCC/Api
```

2. **Crie e ative o ambiente virtual**
```bash
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/Mac
```

3. **Instale as dependências**
```bash
pip install -r requirements.txt
```

4. **Configure as variáveis de ambiente**

Crie um arquivo `.env` baseado no `.env.example`:
```env
DJANGO_SECRET_KEY=sua-chave-secreta
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1

DB_NAME=genapp_db
DB_USER=postgres
DB_PASSWORD=sua-senha
DB_HOST=localhost
DB_PORT=5432

GEMINI_API_KEY=sua-chave-gemini

REDIS_URL=redis://localhost:6379/0
```

5. **Execute as migrações**
```bash
python manage.py migrate
```

6. **Crie um superusuário**
```bash
python manage.py createsuperuser
```

7. **Inicie o servidor**
```bash
python manage.py runserver
```

8. **Inicie o Celery** (em outro terminal)
```bash
# Worker
celery -A config worker -l info

# Beat (agendador)
celery -A config beat -l info
```

### Frontend (Flutter)

1. **Navegue até o diretório**
```bash
cd TCC/Front
```

2. **Instale as dependências**
```bash
flutter pub get
```

3. **Configure a URL da API**

Edite o arquivo de configuração da API conforme seu ambiente (desenvolvimento/produção).

4. **Execute o aplicativo**
```bash
flutter run
```

Para web:
```bash
flutter run -d chrome
```

---

## Uso

### Primeiro Acesso

1. Execute o backend e frontend conforme instruções acima
2. Acesse a aplicação Flutter
3. Crie uma conta de usuário
4. Complete o tutorial inicial para configurar suas categorias padrão
5. Comece a registrar suas transações

### Funcionalidades Principais

**Transações**
- Registre receitas e despesas
- Categorize suas transações
- Adicione descrições e tags

**Missões**
- Missões são geradas automaticamente com base no seu perfil
- Complete missões para ganhar XP e subir de nível
- Missões diárias, semanais e mensais

**Indicadores**
- ILI: Índice de Liberdade Individual
- Taxa de Reservas
- Taxa de Independência Financeira
- Acompanhe sua evolução ao longo do tempo

**Metas**
- Defina objetivos financeiros
- Acompanhe o progresso
- Receba notificações de marcos alcançados

---

## Testes

### Backend

```bash
cd Api
python manage.py test
```

Testes específicos:
```bash
python manage.py test finance.tests.test_category_isolation
python manage.py test finance.tests.test_rate_limiting
python manage.py test finance.tests.test_uuid_integration
```

### Frontend

```bash
cd Front
flutter test
```

---

## Deploy

O projeto foi configurado para deploy no Railway durante a fase de testes e demonstração. Os arquivos de configuração incluem:

- `Procfile`: Processos para o Railway
- `railway.json`: Configurações específicas
- `runtime.txt`: Versão do Python

**Nota**: O Railway foi utilizado apenas para testes e validação da aplicação em ambiente de produção. Para uso em produção definitivo, recomenda-se avaliar outras plataformas ou infraestrutura própria.

---

## Arquitetura

### Backend (MVVM + Repository Pattern)

- **Models**: Definição de entidades (User, Transaction, Mission, etc.)
- **Serializers**: Transformação de dados para API REST
- **Views**: Endpoints da API
- **Services**: Lógica de negócio isolada
- **Repositories**: Camada de acesso a dados (implícito via Django ORM)

### Frontend (Clean Architecture)

- **Core**: Configurações, utilitários, modelos
- **Features**: Módulos funcionais (auth, transactions, missions, etc.)
- **Presentation**: UI (views, widgets, controllers)

### Fluxo de Dados

```
Flutter App → API REST → Django Views → Services → Models → PostgreSQL
                                    ↓
                                 Celery → Redis → Tasks (IA, notificações)
```

---

## Licença

Este projeto foi desenvolvido como Trabalho de Conclusão de Curso (TCC) e é disponibilizado para fins acadêmicos e educacionais.

---

## Contato

**Desenvolvedor**: Marcos Eduardo de Neiva Santos
**Instituição**: Instituto Federal do Piauí
**Orientador**: Ricardo

---

## Agradecimentos

- Google Gemini pela API de IA
- Comunidade Django e Flutter
- Orientador e professores
- Colegas e participantes dos testes
