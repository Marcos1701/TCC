# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM debian:bookworm-slim AS build

# Argumentos de build
ARG FLUTTER_VERSION=3.24.5
ARG API_BASE_URL=https://tcc-production-d286.up.railway.app

# Metadados
LABEL maintainer="GenApp Team"
LABEL description="Flutter Web Application Build"

# Install dependencies for Flutter
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa \
        ca-certificates \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user for building (to avoid Flutter warning)
RUN useradd -m -s /bin/bash builder && \
    mkdir -p /opt/flutter && \
    chown -R builder:builder /opt/flutter

# Set Flutter environment
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"
ENV PUB_CACHE=/home/builder/.pub-cache

# Switch to builder user
USER builder

# Download and install Flutter SDK
# Usando stable channel com versão específica compatível com SDK ^3.5.2
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    flutter precache --web && \
    flutter config --no-analytics && \
    flutter doctor -v

# Set working directory
WORKDIR /home/builder/app

# Copy pubspec files to leverage Docker cache
COPY --chown=builder:builder pubspec.yaml pubspec.lock* ./

# Get dependencies (permite falha se pubspec.lock não existir)
RUN flutter pub get || (rm -f pubspec.lock && flutter pub get)

# Copy the rest of the application
COPY --chown=builder:builder . .

# Set API_BASE_URL environment variable (já definido no ARG acima)
ENV API_BASE_URL=${API_BASE_URL}

# Clean any previous builds to avoid cache issues
RUN flutter clean && flutter pub get

# Build the Flutter web application
RUN flutter build web \
    --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --source-maps \
    --no-tree-shake-icons || \
    (echo "Build failed, trying without source-maps..." && \
     flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL})

# Verify build output exists
RUN ls -la build/web/ && \
    test -f build/web/index.html || (echo "Build verification failed!" && exit 1)

# ==========================================
# Stage 2: Production Stage (Nginx)
# ==========================================
FROM nginx:1.25-alpine AS production

# Metadados
LABEL maintainer="GenApp Team"
LABEL description="Flutter Web Application Production"

# Instalar wget para healthcheck
RUN apk add --no-cache wget

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Remove default nginx config
RUN rm -f /etc/nginx/conf.d/default.conf

# Create nginx configuration file
COPY --chown=appuser:appgroup <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/xml+rss application/json application/javascript application/wasm;

    # Cache static assets (JS, CSS, images, fonts, wasm)
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Disable cache for HTML and JSON
    location ~* \.(html|json)$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
    }

    # Flutter service worker - no cache
    location = /flutter_service_worker.js {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Handle Flutter web routing (SPA fallback)
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 '{"status":"healthy","service":"genapp-frontend"}';
        add_header Content-Type application/json;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    # Error pages
    error_page 404 /index.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

# Copy built Flutter web app from build stage
COPY --from=build --chown=appuser:appgroup /home/builder/app/build/web /usr/share/nginx/html

# Set proper permissions for nginx to run as non-root
RUN chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid && \
    # Criar diretórios necessários para nginx
    mkdir -p /var/cache/nginx/client_temp && \
    chown -R appuser:appgroup /var/cache/nginx

# Switch to non-root user
USER appuser

# Expose port (Railway usa PORT env var, nginx escuta na 80)
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]
