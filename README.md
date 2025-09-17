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

- `POST /api/auth/register/`: cria usuário e devolve tokens.
- `POST /api/token/`: gera par token/refresh.
- `GET /api/profile/`: dados do perfil, metas de TPS/RDR e XP.
- `PUT /api/profile/`: ajusta metas de TPS/RDR.
- `GET /api/dashboard/`: resumo com TPS, RDR, séries e recomendações de missões.
- `GET/POST /api/transactions/`: CRUD de transações.
- `GET/POST /api/mission-progress/`: progresso gamificado.
- `GET /api/missions/`: catálogo de missões disponíveis.
- `GET/POST /api/goals/`: metas financeiras.
