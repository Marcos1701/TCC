# GenApp API

Backend Django alinhado com a proposta do GenApp.

## Primeiros passos

1. Garanta o Python 3.9+ com `pip` atualizado (recomendado `python -m pip install --upgrade pip`).
2. Crie e ative um ambiente virtual.
3. Instale dependências: `pip install -r requirements.txt`.
   - O pacote `psycopg` já vem incluído e funciona tanto com SQLite quanto com PostgreSQL.
   - Para ganhos de performance usando PostgreSQL, você pode instalar opcionalmente o módulo nativo: `pip install "psycopg[c]"`.
4. Configure variáveis (`DJANGO_SECRET_KEY`, `POSTGRES_*`, `CORS_ALLOWED_ORIGINS`).
5. Gere e aplique migrações:

   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

6. Crie um superusuário e rode o servidor:

   ```bash
   python manage.py createsuperuser
   python manage.py runserver
   ```

## Apps inclusos

- `finance`: modelos de transações, metas, missões e perfis com endpoints REST.

## Autenticação

A API usa JWT via `djangorestframework-simplejwt`. Gere tokens com o endpoint padrão (`/api/token/`) e envie como `Authorization: Bearer <token>`.
Existe também `/api/auth/register/` para cadastro inicial e `/api/profile/` (GET/PUT) para ajustar metas de TPS/RDR.

