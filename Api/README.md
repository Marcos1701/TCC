# GenApp API

Backend Django alinhado ao plano descrito no relatório: calcula TPS/RDR, distribui missões gamificadas e mantém o histórico financeiro dos usuários.

## Primeiros passos
1. Crie/ative um ambiente virtual Python 3.11+.
2. Instale dependências: `pip install -r requirements.txt`.
3. Garanta um PostgreSQL 13+ online e exporte:
   ```bash
   export DJANGO_SECRET_KEY='sua-chave'
   export POSTGRES_DB=genapp POSTGRES_USER=genapp POSTGRES_PASSWORD=genapp
   export POSTGRES_HOST=localhost POSTGRES_PORT=5432
   ```
4. Aplique as migrações existentes (já incluem seeds de missões iniciais):
   ```bash
   python manage.py migrate
   ```
5. (Opcional) Crie um superusuário e suba o servidor:
   ```bash
   python manage.py createsuperuser
   python manage.py runserver
   ```

## Apps inclusos
- `finance`: modelos de transações, categorias (receita, despesa, dívida), missões, metas e perfis.

## Indicadores calculados
- **TPS (Taxa de Poupança Pessoal)**: `(renda líquida - despesas) / renda líquida`.
- **RDR (Razão Dívida-Renda)**: `pagamentos mensais de dívida / renda bruta`.
- A API retorna diagnóstico textual, meta alvo e histórico mensal de cada indicador para alimentar o dashboard Flutter.

## Endpoints chave
- `POST /api/auth/register/` – cria usuário, perfil, metas padrão (TPS ≥ 15%, RDR ≤ 35%) e categorias sugeridas.
- `POST /api/token/` / `POST /api/token/refresh/` – fluxo JWT do DRF SimpleJWT.
- `GET/PUT /api/profile/` – consulta e ajusta metas personalizadas.
- `GET /api/dashboard/` – série temporal de TPS/RDR, saldo, distribuição por categoria e missões recomendadas.
- `GET/POST /api/transactions/` – CRUD de receitas, despesas e dívidas.
- `GET /api/missions/` + `GET/POST /api/mission-progress/` – catálogo e progresso das missões.
- `GET/POST /api/goals/` – metas financeiras do usuário.

## Segurança e LGPD
- Senhas com PBKDF2 + salt (padrão Django).
- Tokens JWT curtos com refresh token separado.
- Cabeçalhos de segurança, HSTS e TLS previstos na implantação.
- Logs de auditoria, MFA e rate limiting prontos para extensão conforme recomenda o trabalho.

## Próximas evoluções sugeridas
- Importação segura de extratos bancários.
- Conteúdo educativo para reforçar decisões financeiras.
- Modelos de recomendação mais sofisticados (IA) conforme previsto no capítulo de trabalhos futuros.
