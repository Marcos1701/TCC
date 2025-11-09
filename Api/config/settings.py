import os
from datetime import timedelta
from pathlib import Path
from typing import Optional

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "on", "yes", "sim"}


def env_list(name: str, default: Optional[str] = None) -> list[str]:
    raw = os.getenv(name, default or "")
    return [item.strip() for item in raw.split(",") if item.strip()]


def env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


load_dotenv(BASE_DIR / ".env")

SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", "unsafe-secret-key")
DEBUG = env_bool("DJANGO_DEBUG", False)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")
if not ALLOWED_HOSTS:
    ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "django_celery_beat",
    "django_celery_results",
    "finance",
]

# Django Debug Toolbar (apenas em DEBUG mode)
if DEBUG:
    INSTALLED_APPS += ["debug_toolbar"]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# Django Debug Toolbar Middleware (apenas em DEBUG mode)
if DEBUG:
    MIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")
    INTERNAL_IPS = ["127.0.0.1", "localhost"]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

db_name = os.getenv("DB_NAME") or os.getenv("POSTGRES_DB")
if db_name:
    db_user = os.getenv("DB_USER") or os.getenv("POSTGRES_USER", "postgres")
    db_password = os.getenv("DB_PASSWORD") or os.getenv("POSTGRES_PASSWORD", "postgres")
    db_host = os.getenv("DB_HOST") or os.getenv("POSTGRES_HOST", "localhost")
    db_port = os.getenv("DB_PORT") or os.getenv("POSTGRES_PORT", "5432")
    DATABASES = {
        "default": {
            "ENGINE": os.getenv("DB_ENGINE", "django.db.backends.postgresql"),
            "NAME": db_name,
            "USER": db_user,
            "PASSWORD": db_password,
            "HOST": db_host,
            "PORT": db_port,
        }
    }
    require_ssl_default = db_host not in {"localhost", "127.0.0.1"}
    if env_bool("DB_REQUIRE_SSL", require_ssl_default):
        ssl_mode = os.getenv("DB_SSLMODE", "require").strip()
        if ssl_mode:
            DATABASES["default"]["OPTIONS"] = {"sslmode": ssl_mode}
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

CONN_MAX_AGE = env_int("DB_CONN_MAX_AGE", 60 if db_name else 0)

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "pt-br"
TIME_ZONE = "America/Sao_Paulo"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "static"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

AUTHENTICATION_BACKENDS = (
    "django.contrib.auth.backends.ModelBackend",
)

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticated",
    ),
    "DEFAULT_RENDERER_CLASSES": (
        "rest_framework.renderers.JSONRenderer",
    ),
    "DEFAULT_PARSER_CLASSES": (
        "rest_framework.parsers.JSONParser",
    ),
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        # Taxas gerais
        "anon": f"{env_int('THROTTLE_ANON_RATE', 100)}/day",
        "user": f"{env_int('THROTTLE_USER_RATE', 2000)}/day",
        
        # Taxas específicas por operação (implementadas em throttling.py)
        "burst": "30/minute",  # Prevenir burst attacks
        "transaction_create": "100/hour",  # Criação de transações
        "category_create": "20/hour",  # Criação de categorias
        "link_create": "50/hour",  # Vinculação de transações
        "goal_create": "10/hour",  # Criação de metas
        "dashboard_refresh": "60/hour",  # Refresh de indicadores
        "sensitive": "10/hour",  # Operações sensíveis
    },
    # Paginação padrão para melhor performance
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.LimitOffsetPagination",
    "PAGE_SIZE": 50,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env_int("JWT_ACCESS_TOKEN_LIFETIME_MINUTES", 15)),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env_int("JWT_REFRESH_TOKEN_LIFETIME_DAYS", 7)),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
    "UPDATE_LAST_LOGIN": True,
}

# ============================================================================
# CACHE CONFIGURATION
# ============================================================================
# Usa database backend por padrão (fácil setup)
# Para produção, recomenda-se Redis: pip install django-redis
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.db.DatabaseCache',
        'LOCATION': 'django_cache_table',
        'TIMEOUT': 300,  # 5 minutos padrão
        'OPTIONS': {
            'MAX_ENTRIES': 1000,
        }
    }
}

# Para usar Redis em produção, descomente e configure:
# CACHES = {
#     'default': {
#         'BACKEND': 'django_redis.cache.RedisCache',
#         'LOCATION': env('REDIS_URL', 'redis://127.0.0.1:6379/1'),
#         'OPTIONS': {
#             'CLIENT_CLASS': 'django_redis.client.DefaultClient',
#         },
#         'KEY_PREFIX': 'finance',
#         'TIMEOUT': 300,
#     }
# }

CORS_ALLOWED_ORIGINS = env_list(
    "CORS_ALLOWED_ORIGINS",
    "http://localhost:3000,http://127.0.0.1:3000,https://tcc-production-d286.up.railway.app",
)
CORS_ALLOW_ALL_ORIGINS = env_bool("CORS_ALLOW_ALL_ORIGINS", False)
CORS_ALLOW_CREDENTIALS = env_bool("CORS_ALLOW_CREDENTIALS", True)

# Gemini AI Configuration
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")

CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", not DEBUG)
SESSION_COOKIE_SECURE = env_bool("DJANGO_SESSION_COOKIE_SECURE", not DEBUG)
CSRF_COOKIE_SECURE = env_bool("DJANGO_CSRF_COOKIE_SECURE", not DEBUG)

if env_bool("DJANGO_USE_X_FORWARDED_PROTO", False):
    SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")

LOG_LEVEL = os.getenv("DJANGO_LOG_LEVEL", "INFO")

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "verbose": {
            "format": "[{levelname}] {name}: {message}",
            "style": "{",
        }
    },
    "handlers": {
        "console": {
            "class": "logging.StreamHandler",
            "formatter": "verbose",
        }
    },
    "root": {
        "handlers": ["console"],
        "level": LOG_LEVEL.upper(),
    },
}

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"


# ============================================================================
# CELERY CONFIGURATION
# ============================================================================

# Broker e Backend - Railway usa variáveis de ambiente do Redis
# Railway automaticamente injeta REDIS_URL quando você adiciona o serviço Redis
CELERY_BROKER_URL = os.getenv('REDIS_URL', os.getenv('CELERY_BROKER_URL', 'redis://localhost:6379/0'))

# Para Railway: usar mesma URL do Redis para results (mais simples)
# Em desenvolvimento local: usar django-db
if os.getenv('RAILWAY_ENVIRONMENT'):
    # Produção no Railway - usar Redis para tudo
    CELERY_RESULT_BACKEND = os.getenv('REDIS_URL', 'redis://localhost:6379/0')
else:
    # Desenvolvimento local - usar Django DB
    CELERY_RESULT_BACKEND = 'django-db'

# Celery Beat Scheduler (usar Django DB em ambos os ambientes)
CELERY_BEAT_SCHEDULER = 'django_celery_beat.schedulers:DatabaseScheduler'

# Timezone
CELERY_TIMEZONE = 'America/Sao_Paulo'
CELERY_ENABLE_UTC = True

# Serialização
CELERY_TASK_SERIALIZER = 'json'
CELERY_ACCEPT_CONTENT = ['json']
CELERY_RESULT_SERIALIZER = 'json'

# Configurações de Task
CELERY_TASK_TRACK_STARTED = True
CELERY_TASK_TIME_LIMIT = 30 * 60  # 30 minutos
CELERY_TASK_SOFT_TIME_LIMIT = 25 * 60  # 25 minutos
CELERY_TASK_ACKS_LATE = True  # Reconhecer task apenas após conclusão
CELERY_WORKER_PREFETCH_MULTIPLIER = 4

# Resultados
CELERY_RESULT_EXTENDED = True
CELERY_RESULT_EXPIRES = 60 * 60 * 24  # Resultados expiram em 24 horas

# Worker
CELERY_WORKER_MAX_TASKS_PER_CHILD = 1000  # Reiniciar worker após 1000 tasks
