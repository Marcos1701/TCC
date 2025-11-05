# ==========================================
# Stage 1: Build Stage
# ==========================================
FROM debian:bullseye-slim AS build

# Install dependencies for Flutter
RUN apt-get update && \
    apt-get install -y \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        libglu1-mesa && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set Flutter version and installation directory
ARG FLUTTER_VERSION=3.24.3
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

# Download and install Flutter SDK
RUN git clone --depth 1 --branch ${FLUTTER_VERSION} https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    flutter precache --web && \
    flutter doctor -v && \
    rm -rf ${FLUTTER_HOME}/.pub-cache/hosted/pub.dartlang.org

# Set working directory
WORKDIR /app

# Copy pubspec files to leverage Docker cache
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Build argument for API URL
ARG API_BASE_URL=https://tcc-production-d286.up.railway.app
ENV API_BASE_URL=${API_BASE_URL}

# Build the Flutter web application
RUN flutter build web \
    --release \
    --web-renderer canvaskit \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# ==========================================
# Stage 2: Production Stage (Nginx)
# ==========================================
FROM nginx:1.25-alpine AS production

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy custom nginx configuration
COPY --chown=appuser:appgroup <<'EOF' /etc/nginx/conf.d/default.conf
server {
    listen 80;
    server_name _;
    
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;

    # Cache static assets
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Disable cache for HTML
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
    }

    # Handle Flutter web routing
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Copy built Flutter web app from build stage
COPY --from=build --chown=appuser:appgroup /app/build/web /usr/share/nginx/html

# Set proper permissions
RUN chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
