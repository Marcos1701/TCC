# GenApp - Gestão Financeira Gamificada com IA

> **Trabalho de Conclusão de Curso (TCC)**  
> **Curso:** Tecnologia em Análise e Desenvolvimento de Sistemas - IFPI  
> **Aluno:** Marcos Eduardo de Neiva Santos  
> **Orientador:** Prof. Ricardo Martins Ramos

O **GenApp** é um sistema de gestão financeira pessoal que integra conceitos de gamificação e inteligência artificial para promover a educação financeira e o engajamento do usuário.

## 📋 Sobre o Projeto

O objetivo principal é auxiliar usuários, especialmente jovens adultos, a desenvolverem hábitos financeiros saudáveis através de métricas claras e um sistema de missões adaptativo.

### Diferenciais
- **Gamificação Inteligente:** Níveis, XP e conquistas baseados no comportamento real.
- **Missões via IA:** Integração com Google Gemini para gerar desafios personalizados baseados no perfil financeiro (ex: "Poupar 10% da renda" para quem tem TPS baixa).
- **Indicadores Científicos:**
  - **TPS (Taxa de Poupança Pessoal):** Capacidade de poupança mensal.
  - **RDR (Razão Dívida-Renda):** Nível de comprometimento com dívidas.
  - **ILI (Índice de Liquidez Imediata):** Saúde da reserva de emergência (em meses).

## 🚀 Como Rodar o Projeto

A maneira mais simples de executar todo o sistema (Backend, Frontend, Banco de Dados e Serviços) é utilizando o **Docker**.

### Pré-requisitos
- [Docker](https://www.docker.com/) e [Docker Compose](https://docs.docker.com/compose/) instalados.

### Passos

1. **Clone o repositório:**
   ```bash
   git clone <url-do-repositorio>
   cd TCC
   ```

2. **Configure as variáveis de ambiente:**
   Copie o arquivo de exemplo e, se necessário, adicione sua chave da API do Google Gemini.
   ```bash
   cp .env.example .env
   # Edite o arquivo .env para adicionar GOOGLE_API_KEY se desejar testar a IA
   ```

3. **Inicie os containers:**
   ```bash
   docker-compose up -d --build
   ```

4. **Execute as migrações do banco de dados:**
   ```bash
   docker-compose exec api python manage.py migrate
   docker-compose exec api python manage.py createcachetable
   ```

5. **Crie um superusuário (opcional, para acesso administrativo):**
   ```bash
   docker-compose exec api python manage.py createsuperuser
   ```

### Acessando a Aplicação
- **App (Frontend):** [http://localhost:3000](http://localhost:3000)
- **API (Backend):** [http://localhost:8000](http://localhost:8000)
- **Painel Admin:** [http://localhost:8000/admin](http://localhost:8000/admin)

## 🏗️ Estrutura do Projeto

O repositório é um monorepo organizado da seguinte forma:

```
TCC/
├── Api/              # Backend (Django REST Framework)
│   ├── finance/      # Lógica de negócios (Models, Views, Services)
│   └── config/       # Configurações do projeto
├── Front/            # Frontend (Flutter Mobile/Web)
│   ├── lib/          # Código-fonte Dart
│   └── assets/       # Imagens e recursos
├── Latex_Doc/        # Documentação acadêmica (LaTeX)
├── scripts/          # Scripts auxiliares de infraestrutura
└── docker-compose.yml # Orquestração dos containers
```

## 🛠️ Tecnologias Principais

- **Backend:** Python, Django, Django REST Framework, Celery, Redis.
- **Frontend:** Flutter, Dart, Riverpod/Provider (State Management).
- **Banco de Dados:** PostgreSQL.
- **IA:** Google Generative AI (Gemini Flash).
- **Infraestrutura:** Docker.
