FROM debian:bookworm-slim AS build

ARG FLUTTER_VERSION=3.24.5
ARG API_BASE_URL=https://tcc-production-d286.up.railway.app

LABEL maintainer="GenApp Team"
LABEL description="Flutter Web Application Build"

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

RUN useradd -m -s /bin/bash builder && \
    mkdir -p /opt/flutter && \
    chown -R builder:builder /opt/flutter

ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"
ENV PUB_CACHE=/home/builder/.pub-cache

USER builder

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    flutter precache --web && \
    flutter config --no-analytics && \
    flutter doctor -v

WORKDIR /home/builder/app

COPY --chown=builder:builder pubspec.yaml pubspec.lock* ./

RUN flutter pub get || (rm -f pubspec.lock && flutter pub get)

COPY --chown=builder:builder . .

ENV API_BASE_URL=${API_BASE_URL}

RUN flutter clean && flutter pub get

RUN flutter build web \
    --release \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --source-maps \
    --no-tree-shake-icons || \
    (echo "Build failed, trying without source-maps..." && \
     flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL})

RUN ls -la build/web/ && \
    test -f build/web/index.html || (echo "Build verification failed!" && exit 1)

FROM nginx:1.25-alpine AS production

LABEL maintainer="GenApp Team"
LABEL description="Flutter Web Application Production"

RUN apk add --no-cache wget

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

RUN rm -f /etc/nginx/conf.d/default.conf

COPY --chown=appuser:appgroup <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen [::]:80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Permissions-Policy "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()" always;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml application/xml+rss application/json application/javascript application/wasm;

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|wasm)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    location ~* \.(html|json)$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
    }

    location = /flutter_service_worker.js {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /health {
        access_log off;
        return 200 '{"status":"healthy","service":"genapp-frontend"}';
        add_header Content-Type application/json;
    }

    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }

    error_page 404 /index.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOF

COPY --from=build --chown=appuser:appgroup /home/builder/app/build/web /usr/share/nginx/html

RUN chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid && \
    mkdir -p /var/cache/nginx/client_temp && \
    chown -R appuser:appgroup /var/cache/nginx

USER appuser

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
