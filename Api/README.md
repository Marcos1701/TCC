# GenApp API - Backend

Este repositório contém o código-fonte do *backend* do projeto **GenApp**, parte integrante do Trabalho de Conclusão de Curso (TCC) do curso de Tecnologia em Análise e Desenvolvimento de Sistemas do Instituto Federal do Piauí (IFPI).

O sistema fornece a API RESTful que alimenta o aplicativo móvel, gerenciando a lógica de negócios, autenticação, transações financeiras e o motor de gamificação.

## Tecnologias Utilizadas

- **Linguagem:** Python 3.9+
- **Framework:** Django 4.2+ & Django REST Framework
- **Banco de Dados:** PostgreSQL
- **Autenticação:** JWT (JSON Web Tokens)
- **Assincronismo:** Celery & Redis (para geração de missões e tarefas em background)

## Configuração do Ambiente

Siga os passos abaixo para executar o projeto localmente.

### 1. Pré-requisitos
Certifique-se de ter instalado:
- Python 3.9 ou superior
- PostgreSQL (ou acesso a um banco de dados compatível)
- Redis (opcional, necessário apenas se for testar as filas do Celery)

### 2. Instalação das Dependências

Crie um ambiente virtual para isolar as dependências do projeto:

```bash
# Windows
python -m venv venv
.\venv\Scripts\activate

# Linux/Mac
python3 -m venv venv
source venv/bin/activate
```

Instale os pacotes necessários:

```bash
pip install -r requirements.txt
```

### 3. Configuração de Variáveis de Ambiente

Crie um arquivo `.env` na raiz do projeto (baseado no `.env.example`) e configure as credenciais do banco de dados e chave secreta:

```ini
# Exemplo básico
DEBUG=True
SECRET_KEY=sua-chave-secreta-aqui
DB_NAME=genapp_db
DB_USER=postgres
DB_PASSWORD=sua_senha
DB_HOST=localhost
DB_PORT=5432
```

### 4. Banco de Dados

Aplique as migrações para criar a estrutura do banco de dados:

```bash
python manage.py makemigrations
python manage.py migrate
```

### 5. Execução

Para iniciar o servidor de desenvolvimento:

```bash
python manage.py runserver
```

A API estará disponível em `http://127.0.0.1:8000/`.

## Criação de Usuário Administrador

Para acessar o painel administrativo do Django (`/admin`), crie um superusuário:

```bash
python manage.py createsuperuser
```
Ou utilize o script facilitador (caso configurado):
```bash
python create_admin.py
```

## Estrutura do Projeto

- `finance/`: Aplicação principal contendo Models (Transação, Missão, Meta), Views e Serializers.
- `config/`: Configurações globais do projeto Django.
- `seed_*.py`: Scripts para popular o banco de dados com dados de teste.
