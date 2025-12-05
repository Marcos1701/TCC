from .settings import *

# Use SQLite for tests
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db_test.sqlite3",
    }
}

# Disable migrations for finance app to avoid SQLite compatibility issues
# Django will create tables directly from models
MIGRATION_MODULES = {
    'finance': None,
}

# Disable Celery for tests
CELERY_BROKER_URL = 'memory://'
CELERY_RESULT_BACKEND = 'cache+memory://'
