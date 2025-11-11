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
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --user --no-cache-dir -r requirements.txt

# Stage 2: Runtime stage
FROM python:3.11-slim

# Definir variáveis de ambiente
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/home/appuser/.local/bin:$PATH

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

# Definir diretório de trabalho
WORKDIR /app

# Copiar código da aplicação
COPY --chown=appuser:appuser . .

# Criar diretório para arquivos estáticos e media
RUN mkdir -p static media && \
    chown -R appuser:appuser static media

# Mudar para usuário não-root
USER appuser

# Expor porta
EXPOSE 8000

# Usar ENTRYPOINT + CMD para expansão de variáveis
ENTRYPOINT ["/bin/sh", "-c"]
CMD ["python manage.py migrate --noinput && python manage.py collectstatic --noinput --clear && exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 4 --timeout 120 --access-logfile - --error-logfile -"]
