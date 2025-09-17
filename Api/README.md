# GenApp API

Backend Django alinhado com a proposta do GenApp.

## Primeiros passos

1. Crie e ative um ambiente virtual.
2. Instale dependências: `pip install -r requirements.txt`.
3. Configure variáveis (`DJANGO_SECRET_KEY`, `POSTGRES_*`, `CORS_ALLOWED_ORIGINS`).
4. Gere e aplique migrações:
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```
5. Crie um superusuário e rode o servidor:
   ```bash
   python manage.py createsuperuser
   python manage.py runserver
   ```

## Apps inclusos

- `finance`: modelos de transações, metas, missões e perfis com endpoints REST.

## Autenticação

A API usa JWT via `djangorestframework-simplejwt`. Gere tokens com o endpoint padrão (`/api/token/`) e envie como `Authorization: Bearer <token>`.
