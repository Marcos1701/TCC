# Stage 1: Build stage
FROM python:3.11-slim as builder

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /app

# Copiar requirements e instalar dependências Python
COPY Api/requirements.txt .
RUN pip install --upgrade pip && \
    pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Instalar apenas dependências de runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

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

# Copiar código da aplicação (apenas o diretório Api)
COPY --chown=appuser:appuser Api/ .

# Criar diretório para arquivos estáticos e media
RUN mkdir -p static media && \
    chown -R appuser:appuser static media

# Copiar script de entrypoint e torná-lo executável (antes de mudar para non-root user)
COPY --chown=appuser:appuser Api/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Mudar para usuário não-root
USER appuser

# Expor porta
EXPOSE 8000

# Script de entrypoint padrão (pode ser sobrescrito para worker/beat)
ENTRYPOINT ["/docker-entrypoint.sh"]

# Comando padrão: API com Gunicorn
CMD ["gunicorn"]
