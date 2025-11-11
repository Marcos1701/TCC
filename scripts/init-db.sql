-- Script de inicialização do banco de dados PostgreSQL
-- Executado automaticamente na primeira criação do container

-- Criar extensão UUID (caso não exista)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Criar extensão para índices otimizados
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Configurar encoding e locale
ALTER DATABASE finance_db SET timezone TO 'America/Sao_Paulo';

-- Log de inicialização
DO $$
BEGIN
    RAISE NOTICE 'Database initialized successfully for GenApp';
    RAISE NOTICE 'Extensions: uuid-ossp, pg_trgm';
    RAISE NOTICE 'Timezone: America/Sao_Paulo';
END $$;
