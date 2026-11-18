-- Runs once on first boot of the Kamal pgvector accessory (empty data volume).
CREATE EXTENSION IF NOT EXISTS vector;

CREATE DATABASE rag_service_production_cache OWNER rag_service;
CREATE DATABASE rag_service_production_queue OWNER rag_service;
CREATE DATABASE rag_service_production_cable OWNER rag_service;
