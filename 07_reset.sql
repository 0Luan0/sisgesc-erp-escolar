-- ============================================================
-- SCRIPT DE RESET — limpa tudo para execucao do zero
-- DROP DATABASE elimina todos os objetos de uma vez (tabelas,
-- views, triggers, indices). Nao precisa de USE nem de DROPs
-- individuais — e mais simples e funciona em MySQL limpo.
-- ============================================================

-- FK_CHECKS off para evitar conflito de ordem entre bancos
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS erp_escolar_olap;
DROP DATABASE IF EXISTS erp_escolar;

SET FOREIGN_KEY_CHECKS = 1;
