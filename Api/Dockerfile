# Stage 1: Build stage
FROM python:3.11-slim AS builder

# Argumentos de build para configuração
ARG BUILDPLATFORM
ARG TARGETPLATFORM

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalar dependências do sistema (incluindo netcat para healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Criar diretório de trabalho
WORKDIR /app

# Copiar requirements e instalar dependências Python
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    # Variáveis padrão para produção (podem ser sobrescritas)
    PORT=8000 \
    WORKERS=4 \
    TIMEOUT=120

# Instalar apenas dependências de runtime (incluindo netcat para healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Criar usuário não-root ANTES de copiar arquivos
RUN useradd -m -u 1000 appuser && \
    mkdir -p /app /app/static /app/media && \
    chown -R appuser:appuser /app

# Copiar dependências instaladas do builder para o diretório do appuser
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local

# Atualizar PATH para incluir binários do Python instalados pelo usuário
ENV PATH=/home/appuser/.local/bin:$PATH

# Definir diretório de trabalho
WORKDIR /app

# Copiar código da aplicação
COPY --chown=appuser:appuser . .

# Criar diretório para arquivos estáticos e media
RUN mkdir -p static media && \
    chown -R appuser:appuser static media

# Copiar script de entrypoint e torná-lo executável (antes de mudar para non-root user)
# O script já foi copiado para /app junto com Api/, então apenas movemos para /
RUN cp /app/docker-entrypoint.sh /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh && \
    # Garantir que o script tenha line endings Unix (LF, não CRLF)
    sed -i 's/\r$//' /docker-entrypoint.sh

# Mudar para usuário não-root
USER appuser

# Healthcheck para garantir que a aplicação está saudável
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:${PORT:-8000}/api/health/ || exit 1

# Expor porta
EXPOSE 8000

# Script de entrypoint padrão (pode ser sobrescrito para worker/beat)
ENTRYPOINT ["/docker-entrypoint.sh"]

# Comando padrão: API com Gunicorn
CMD ["gunicorn"]
