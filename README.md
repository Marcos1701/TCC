# GenApp Monorepo

Este repositório guarda o app Flutter e a API Django do GenApp.

## Pastas

- `Front/`: código do aplicativo Flutter.
- `Api/`: API em Django com dependências iniciais.

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
