# GenApp Monorepo

Este repositório guarda o app Flutter e a API Django do GenApp.

## Pastas

- `Front/`: código do aplicativo Flutter.
- `Api/`: API em Django com o app `finance` (transações, metas, missões).

## Passos rápidos

### Flutter

```bash
cd Front
flutter pub get
flutter run
```

### Django

```bash
cd Api
python -m venv .venv
source .venv/bin/activate  # ou .venv\\Scripts\\activate no Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

Endpoints principais disponíveis após autenticação JWT:

- `GET /api/dashboard/`: resumo com TPS, RDR e totais.
- `GET/POST /api/transactions/`: CRUD de transações.
- `GET /api/missions/`: missões ativas.
- `GET/POST /api/mission-progress/`: progresso gamificado.
- `GET/POST /api/goals/`: metas financeiras.
- `POST /api/token/`: gera par token/refresh.
