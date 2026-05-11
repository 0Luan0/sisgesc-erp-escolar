-- ============================================================
-- SISGESC — Teste de Carga e Duplicidade
-- Objetivo: verificar se INSERT IGNORE + constraints UNIQUE
-- impedem duplicacao sob volume (1000 registros por tabela-alvo)
-- Executar DEPOIS de run_all.sql
-- Limpa os dados de teste ao final (DELETE dos RGAs/RGFs de teste)
-- ============================================================

USE erp_escolar;

-- ============================================================
-- FASE 1: CONTAGEM INICIAL (baseline)
-- ============================================================
SELECT 'BASELINE' AS fase,
  (SELECT COUNT(*) FROM aluno)      AS aluno,
  (SELECT COUNT(*) FROM matricula)  AS matricula,
  (SELECT COUNT(*) FROM pagamento)  AS pagamento,
  (SELECT COUNT(*) FROM funcionario) AS funcionario,
  (SELECT COUNT(*) FROM historico_salario) AS historico_salario;

-- ============================================================
-- FASE 2: INSERT de 1000 alunos de teste
-- RGAs T0000001–T0001000 (prefixo T = teste, nao conflita com A)
-- CPFs 00000000001–00000001000
-- ============================================================
INSERT IGNORE INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT
  CONCAT('T', LPAD(n, 7, '0'))          AS rga,
  LPAD(n, 11, '0')                      AS cpf,
  CONCAT('AlunoCarga', n)               AS nome,
  'Teste'                               AS sobrenome,
  DATE_SUB('2000-01-01', INTERVAL (n MOD 10) YEAR) AS data_nascimento,
  'Ativo'                               AS status
FROM seq;

-- ============================================================
-- FASE 3: INSERT de 1000 matriculas vinculadas aos alunos de teste
-- ============================================================
INSERT IGNORE INTO matricula (fk_rga, fk_curso, data_matricula, status, ano_ingresso)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT
  CONCAT('T', LPAD(n, 7, '0'))          AS fk_rga,
  ELT(1 + (n MOD 3), 'ADS', 'ENF', 'LOG') AS fk_curso,
  '2024-01-15'                          AS data_matricula,
  'Cursando'                            AS status,
  2024                                  AS ano_ingresso
FROM seq;

-- ============================================================
-- FASE 4: INSERT de 1000 pagamentos de teste
-- Vinculados ao contrato 1 (existe no DML), periodo de teste '2099-01'
-- (periodo fora do range real para nao interferir nos dados)
-- ============================================================

-- mensalidade auxiliar para suportar os pagamentos de teste
INSERT IGNORE INTO mensalidade (fk_id_contrato, periodo, valor_base, valor_desconto, data_vencimento, status)
VALUES (1, '2099-01', 100.00, 0.00, '2099-01-10', 'Pendente');

INSERT IGNORE INTO pagamento (fk_id_contrato, periodo, metodo, data_pagamento, valor_pago, status)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT
  1                       AS fk_id_contrato,
  '2099-01'               AS periodo,
  ELT(1 + (n MOD 5), 'Pix', 'Boleto', 'Cartao', 'Transferencia', 'Dinheiro') AS metodo,
  '2099-01-05'            AS data_pagamento,
  10.00                   AS valor_pago,
  'Pago'                  AS status
FROM seq;
-- NOTA: pagamentos com mesmo (fk_id_contrato, periodo, metodo, data_pagamento, valor_pago)
-- nao tem UNIQUE constraint — por design, multiplos pagamentos parciais sao permitidos.
-- Por isso o count de pagamento pode crescer (1000 inserts validos, sem duplicatas naturais).

-- ============================================================
-- FASE 5: CONTAGEM APOS PRIMEIRA INSERCAO
-- ============================================================
SELECT 'APOS_1a_INSERCAO' AS fase,
  (SELECT COUNT(*) FROM aluno)      AS aluno,
  (SELECT COUNT(*) FROM matricula)  AS matricula,
  (SELECT COUNT(*) FROM pagamento)  AS pagamento,
  (SELECT COUNT(*) FROM funcionario) AS funcionario,
  (SELECT COUNT(*) FROM historico_salario) AS historico_salario;

-- ============================================================
-- FASE 6: SEGUNDA INSERCAO (mesmos dados — deve ser ignorada)
-- Testa se INSERT IGNORE + UNIQUE constraints funcionam sob volume
-- ============================================================
INSERT IGNORE INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT
  CONCAT('T', LPAD(n, 7, '0'))          AS rga,
  LPAD(n, 11, '0')                      AS cpf,
  CONCAT('AlunoCarga', n)               AS nome,
  'Teste'                               AS sobrenome,
  DATE_SUB('2000-01-01', INTERVAL (n MOD 10) YEAR) AS data_nascimento,
  'Ativo'                               AS status
FROM seq;

INSERT IGNORE INTO matricula (fk_rga, fk_curso, data_matricula, status, ano_ingresso)
WITH RECURSIVE seq AS (
  SELECT 1 AS n
  UNION ALL
  SELECT n + 1 FROM seq WHERE n < 1000
)
SELECT
  CONCAT('T', LPAD(n, 7, '0'))          AS fk_rga,
  ELT(1 + (n MOD 3), 'ADS', 'ENF', 'LOG') AS fk_curso,
  '2024-01-15'                          AS data_matricula,
  'Cursando'                            AS status,
  2024                                  AS ano_ingresso
FROM seq;

INSERT IGNORE INTO mensalidade (fk_id_contrato, periodo, valor_base, valor_desconto, data_vencimento, status)
VALUES (1, '2099-01', 100.00, 0.00, '2099-01-10', 'Pendente');

-- ============================================================
-- FASE 7: CONTAGEM APOS SEGUNDA INSERCAO
-- ESPERADO: numeros identicos a FASE 5
-- Se aluno ou matricula cresceram: UNIQUE constraint falhou
-- ============================================================
SELECT 'APOS_2a_INSERCAO' AS fase,
  (SELECT COUNT(*) FROM aluno)      AS aluno,
  (SELECT COUNT(*) FROM matricula)  AS matricula,
  (SELECT COUNT(*) FROM pagamento)  AS pagamento,
  (SELECT COUNT(*) FROM funcionario) AS funcionario,
  (SELECT COUNT(*) FROM historico_salario) AS historico_salario;

-- ============================================================
-- FASE 8: VALIDACAO — compara 1a e 2a insercao lado a lado
-- Diferenca deve ser 0 em todas as colunas de interesse
-- ============================================================
SELECT
  'aluno'     AS tabela,
  (SELECT COUNT(*) FROM aluno WHERE rga LIKE 'T%') AS registros_teste,
  CASE WHEN (SELECT COUNT(*) FROM aluno WHERE rga LIKE 'T%') = 1000
       THEN 'OK — 1000 inseridos, duplicatas ignoradas'
       ELSE 'ERRO — quantidade inesperada'
  END AS resultado
UNION ALL SELECT
  'matricula',
  (SELECT COUNT(*) FROM matricula m JOIN aluno a ON a.rga = m.fk_rga WHERE a.rga LIKE 'T%'),
  CASE WHEN (SELECT COUNT(*) FROM matricula m JOIN aluno a ON a.rga = m.fk_rga WHERE a.rga LIKE 'T%') = 1000
       THEN 'OK — 1000 inseridos, duplicatas ignoradas'
       ELSE 'ERRO — quantidade inesperada'
  END
UNION ALL SELECT
  'mensalidade_2099-01',
  (SELECT COUNT(*) FROM mensalidade WHERE periodo = '2099-01'),
  CASE WHEN (SELECT COUNT(*) FROM mensalidade WHERE periodo = '2099-01') = 1
       THEN 'OK — INSERT IGNORE bloqueou duplicata (PK composta)'
       ELSE 'ERRO — PK composta nao impediu duplicata'
  END;

-- ============================================================
-- FASE 9: LIMPEZA — remove todos os dados de teste
-- DELETE em cascata via FK: matricula e pagamentos sao removidos
-- antes do aluno por causa das FKs
-- ============================================================

-- pagamento de teste (periodo 2099-01)
DELETE FROM pagamento   WHERE periodo = '2099-01';
DELETE FROM mensalidade WHERE periodo = '2099-01';

-- matriculas dos alunos de teste
DELETE FROM matricula WHERE fk_rga LIKE 'T%';

-- alunos de teste
DELETE FROM aluno WHERE rga LIKE 'T%';

-- ============================================================
-- FASE 10: CONTAGEM FINAL — deve ser identica ao BASELINE
-- ============================================================
SELECT 'POS_LIMPEZA' AS fase,
  (SELECT COUNT(*) FROM aluno)      AS aluno,
  (SELECT COUNT(*) FROM matricula)  AS matricula,
  (SELECT COUNT(*) FROM pagamento)  AS pagamento,
  (SELECT COUNT(*) FROM funcionario) AS funcionario,
  (SELECT COUNT(*) FROM historico_salario) AS historico_salario;

-- Se BASELINE = POS_LIMPEZA em todas as colunas: teste passou integralmente
