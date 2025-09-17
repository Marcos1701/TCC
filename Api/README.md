# GenApp API

Este diretório guarda a API Django do GenApp.

## Primeiros passos

1. Crie e ative um ambiente virtual.
2. Instale as dependências:
   ```bash
   pip install -r requirements.txt
   ```
3. Defina variáveis de ambiente básicas (`DJANGO_SECRET_KEY`, `POSTGRES_DB` etc.).
4. Rode as migrações:
   ```bash
   python manage.py migrate
   ```
5. Inicie o servidor:
   ```bash
   python manage.py runserver
   ```
