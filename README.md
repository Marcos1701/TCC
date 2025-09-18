# GenApp Monorepo

Plataforma completa para organizar finanças pessoais com os pilares descritos no TCC: registro manual de transações, cálculo automático da Taxa de Poupança Pessoal (TPS) e da Razão Dívida-Renda (RDR) e um pacote de missões gamificadas para incentivar o hábito financeiro.

## Por que existe
- 78,8% das famílias brasileiras estavam endividadas em ago/2025 segundo a PEIC/CNC, reforçando a necessidade de planejamento.
- O app aplica os conceitos de autonomia, competência e pertencimento da Teoria da Autodeterminação (Deci & Ryan, 1985) usando gamificação.
- Missões, badges e feedback visual seguem as diretrizes apontadas nos estudos de Nguyen-Viet (2025) e Maratou et al. (2023).

## Estrutura do repositório
- `Front/`: aplicativo Flutter com dashboards, missões, metas e fluxo de autenticação escuro.
- `Api/`: backend Django + Django REST Framework conectando diretamente a um PostgreSQL.
- `lib/` e `pubspec.yaml`: casca mínima que delega tudo para `Front/` (necessário para a estrutura do repositório).

## Tecnologias principais
- **Flutter 3.24+** com `dio`, `fl_chart`, `flutter_secure_storage`, `intl` e `google_fonts`.
- **Django 5 + DRF** com autenticação JWT (`djangorestframework-simplejwt`).
- **PostgreSQL** como banco relacional obrigatório.
- Deploy seguro pensado para HTTPS/TLS, hashing PBKDF2 e conformidade com LGPD.

## Executando o Flutter
```bash
cd Front
flutter pub get
flutter run
```

## Executando a API
```bash
cd Api
python -m venv .venv
source .venv/bin/activate  # ou .venv\\Scripts\\activate no Windows
pip install -r requirements.txt
export DJANGO_SECRET_KEY='sua-chave'
export POSTGRES_DB=genapp POSTGRES_USER=genapp POSTGRES_PASSWORD=genapp
export POSTGRES_HOST=localhost POSTGRES_PORT=5432
python manage.py migrate
python manage.py runserver
```

> A API requer um PostgreSQL ativo (13+). Ajuste as variáveis `POSTGRES_*` para o seu ambiente antes de rodar.

## Endpoints relevantes
Todos exigem autenticação JWT (obtenha com `POST /api/token/`).

| Método | Endpoint | Descrição |
| ------ | -------- | --------- |
| POST | `/api/auth/register/` | Cria usuário, perfil e categorias padrões alinhadas ao diagnóstico TPS/RDR. |
| POST | `/api/token/` | Gera par access/refresh token. |
| POST | `/api/token/refresh/` | Atualiza o token de acesso. |
| GET/PUT | `/api/profile/` | Ajusta metas-alvo de TPS e RDR e devolve XP gamificado. |
| GET | `/api/dashboard/` | Retorna série temporal, diagnósticos, missões sugeridas e indicadores TPS/RDR. |
| GET/POST | `/api/transactions/` | CRUD de receitas, despesas e dívidas. |
| GET/POST | `/api/mission-progress/` | Atualiza avanço em missões personalizadas. |
| GET | `/api/missions/` | Lista missões disponíveis com foco em poupança ou redução de dívidas. |
| GET/POST | `/api/goals/` | Gerencia metas financeiras de curto/médio prazo. |

## Segurança e privacidade
- Senhas com PBKDF2 + salt por usuário (padrão Django).
- Tokens JWT guardados no dispositivo via `flutter_secure_storage`, conforme boas práticas LGPD.
- Comunicação prevista para HTTPS com HSTS e bloqueio de downgrade.
- Possibilidade de MFA, rate limiting e auditoria conforme sugerido no trabalho.

## Próximos passos sugeridos
- Integração segura com extratos bancários (fora do escopo do MVP, previsto para trabalhos futuros).
- Conteúdo educativo adicional e motor de recomendações inteligente.
