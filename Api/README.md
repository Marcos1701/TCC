# GenApp API

Backend Django alinhado com a proposta do GenApp.

## Primeiros passos

1. Garanta o Python 3.9+ com `pip` atualizado (recomendado `python -m pip install --upgrade pip`).
2. Crie e ative um ambiente virtual.
3. Instale dependências: `pip install -r requirements.txt`.
   - O driver padrão é `psycopg 3.1.20` com o extra `binary`, que já traz `libpq` embutido.
   - Se desejar as otimizações em C (`psycopg[c]`), substitua o extra no `requirements.txt` após confirmar a presença das dependências nativas.
4. Configure variáveis (`DJANGO_SECRET_KEY`, `DB_*`, `CORS_ALLOWED_ORIGINS`).
   - Utilize o arquivo `.env` (ex.: copie `.env.example`) com as chaves `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`.
   - Ambientes remotos como Supabase exigem SSL. Defina `DB_REQUIRE_SSL=true` ou ajuste `DB_SSLMODE` conforme necessidade.
   
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

A API usa JWT via `djangorestframework-simplejwt`. Gere tokens com o endpoint `/api/token/` informando email e senha, e envie como `Authorization: Bearer <token>`.
Existe também `/api/auth/register/` para cadastro inicial e `/api/profile/` (GET/PUT) para ajustar metas de TPS/RDR. Tanto login quanto cadastro retornam os tokens já com o payload do usuário autenticado.

