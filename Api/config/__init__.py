"""
Configuração principal do projeto.

Este módulo carrega o Celery quando o Django inicia.
"""

# Importar Celery app para que Django o carregue automaticamente
from .celery import app as celery_app

__all__ = ('celery_app',)
