-- ============================================================
-- SISGESC — Ponto de entrada unico
-- Executa todas as fases na ordem correta
-- Uso: mysql -u root -p < run_all.sql
-- Pre-requisito: usuario com privilegios CREATE DATABASE
-- ============================================================

-- FASE 1: estrutura OLTP (cria banco + tabelas + views + triggers)
SOURCE 01_ddl_estrutura.sql;

-- FASE 2: carga inicial idempotente (INSERT IGNORE em todas as tabelas)
SOURCE 02_dml_carga.sql;

-- FASE 3: consultas OLTP (SELECTs simples + subselects)
SOURCE 03_oltp_consultas.sql;

-- FASE 4: estrutura OLAP (cria banco erp_escolar_olap + dims + fato)
SOURCE 04_olap_star_schema.sql;

-- FASE 5: ETL OLTP -> OLAP (full reload + validacao cruzada inline)
SOURCE 05_etl_carga_olap.sql;

-- FASE 6: indices estrategicos + EXPLAIN antes/depois + consistencia
SOURCE 06_validacao.sql;
