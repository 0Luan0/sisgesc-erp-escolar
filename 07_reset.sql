-- ============================================================
-- SCRIPT DE RESET — limpa tudo para execucao do zero
-- Ordem inversa de dependencia (FKs primeiro)
-- ============================================================

USE erp_escolar;

-- desliga checagem de FK temporariamente pra evitar erro de ordem
SET FOREIGN_KEY_CHECKS = 0;

-- views
DROP VIEW IF EXISTS vw_valor_mensalidade;
DROP VIEW IF EXISTS vw_nota_final;
DROP VIEW IF EXISTS vw_salario_liquido;

-- financeiro
DROP TABLE IF EXISTS pagamento_avista_mensalidade;
DROP TABLE IF EXISTS pagamento_a_vista;
DROP TABLE IF EXISTS pagamento;
DROP TABLE IF EXISTS atraso_mensalidade;
DROP TABLE IF EXISTS mensalidade;
DROP TABLE IF EXISTS bolsa;
DROP TABLE IF EXISTS contrato;

-- academico
DROP TABLE IF EXISTS frequencia;
DROP TABLE IF EXISTS nota;
DROP TABLE IF EXISTS avaliacao;
DROP TABLE IF EXISTS matricula_turma;
DROP TABLE IF EXISTS turma;
DROP TABLE IF EXISTS matricula;
DROP TABLE IF EXISTS aluno;
DROP TABLE IF EXISTS calendario_academico;
DROP TABLE IF EXISTS curso_materia_revisao;
DROP TABLE IF EXISTS curso_materia;
DROP TABLE IF EXISTS materia;
DROP TABLE IF EXISTS curso;

-- rh
DROP TABLE IF EXISTS abono_ferias;
DROP TABLE IF EXISTS ferias;
DROP TABLE IF EXISTS periodo_aquisitivo;
DROP TABLE IF EXISTS historico_salario;
DROP TABLE IF EXISTS folha_ocorrencia;
DROP TABLE IF EXISTS folha_evento;
DROP TABLE IF EXISTS folha_pagamentos;
DROP TABLE IF EXISTS ocorrencia_desconto;
DROP TABLE IF EXISTS ponto;
DROP TABLE IF EXISTS conta_banco_funcionario;
DROP TABLE IF EXISTS dependente;
DROP TABLE IF EXISTS documentos_trabalhistas;
DROP TABLE IF EXISTS professor;
DROP TABLE IF EXISTS funcionario;
DROP TABLE IF EXISTS evento_folha;
DROP TABLE IF EXISTS cargo;
DROP TABLE IF EXISTS departamento;

-- tabelas de apoio
DROP TABLE IF EXISTS nivel_ensino;
DROP TABLE IF EXISTS metodo_pagamento;
DROP TABLE IF EXISTS tipo_ponto;
DROP TABLE IF EXISTS nivel_cargo;
DROP TABLE IF EXISTS tipo_evento_folha;
DROP TABLE IF EXISTS tipo_parentesco;
DROP TABLE IF EXISTS tipo_ocorrencia;
DROP TABLE IF EXISTS tipo_conta_bancaria;
DROP TABLE IF EXISTS turno;
DROP TABLE IF EXISTS status_folha;
DROP TABLE IF EXISTS status_ferias;
DROP TABLE IF EXISTS status_pagamento;
DROP TABLE IF EXISTS status_mensalidade;
DROP TABLE IF EXISTS status_contrato;
DROP TABLE IF EXISTS status_funcionario;
DROP TABLE IF EXISTS status_matricula_turma;
DROP TABLE IF EXISTS status_matricula;
DROP TABLE IF EXISTS status_aluno;

SET FOREIGN_KEY_CHECKS = 1;

-- banco OLAP (drop direto — sem dependencias externas)
DROP DATABASE IF EXISTS erp_escolar_olap;

-- opcional: dropar o banco OLTP inteiro
-- DROP DATABASE IF EXISTS erp_escolar;
