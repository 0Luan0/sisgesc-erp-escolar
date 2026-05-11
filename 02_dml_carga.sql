-- ============================================================
-- SISGESC — DML Carga Inicial
-- Idempotente: INSERT IGNORE em todas as tabelas
-- Rodar 2x produz exatamente a mesma contagem
-- Observacao: MySQL suprime SIGNAL de trigger com INSERT IGNORE
-- (erro convertido em warning, linha descartada silenciosamente)
-- ============================================================
-- PROVA DE IDEMPOTENCIA:
--   Execute este script duas vezes seguidas (sem reset entre elas).
--   Na 1a execucao: coluna ANTES sera 0 em todas as tabelas operacionais.
--   Na 2a execucao: coluna ANTES tera os mesmos valores da coluna DEPOIS
--   da execucao anterior — provando que nenhum dado foi duplicado.
-- ============================================================

USE erp_escolar;

-- ============================================================
-- CONTAGEM ANTES DA CARGA
-- (na 2a execucao, estes numeros devem ser identicos aos da secao DEPOIS)
-- ============================================================
SELECT 'ANTES' AS fase,
  (SELECT COUNT(*) FROM departamento)            AS departamento,
  (SELECT COUNT(*) FROM cargo)                   AS cargo,
  (SELECT COUNT(*) FROM funcionario)             AS funcionario,
  (SELECT COUNT(*) FROM professor)               AS professor,
  (SELECT COUNT(*) FROM aluno)                   AS aluno,
  (SELECT COUNT(*) FROM matricula)               AS matricula,
  (SELECT COUNT(*) FROM curso)                   AS curso,
  (SELECT COUNT(*) FROM turma)                   AS turma,
  (SELECT COUNT(*) FROM contrato)                AS contrato,
  (SELECT COUNT(*) FROM mensalidade)             AS mensalidade,
  (SELECT COUNT(*) FROM pagamento)               AS pagamento,
  (SELECT COUNT(*) FROM folha_pagamentos)        AS folha_pagamentos,
  (SELECT COUNT(*) FROM folha_evento)            AS folha_evento,
  (SELECT COUNT(*) FROM ferias)                  AS ferias,
  (SELECT COUNT(*) FROM ponto)                   AS ponto,
  (SELECT COUNT(*) FROM conjuge_funcionario)     AS conjuge_funcionario;

-- ============================================================
-- MODULO RH — Departamentos e Cargos
-- ============================================================

INSERT IGNORE INTO departamento (nome_departamento, descricao, ativo) VALUES
  ('Pedagogia',        'Coordenacao academica e docencia',           TRUE),
  ('Administrativo',   'Gestao administrativa e financeira',         TRUE),
  ('Tecnologia',       'Infraestrutura, redes e sistemas internos',  TRUE),
  ('Recursos Humanos', 'Gestao de pessoas, folha e compliance',      TRUE);

INSERT IGNORE INTO cargo (codigo_cargo, nome_cargo, nome_departamento, nivel, salario_base, ativo) VALUES
  ('PRF', 'Professor',               'Pedagogia',        'Pleno',  4500.00, TRUE),
  ('COO', 'Coordenador Academico',   'Pedagogia',        'Senior', 7200.00, TRUE),
  ('ADM', 'Auxiliar Administrativo', 'Administrativo',   'Junior', 2400.00, TRUE),
  ('GES', 'Gestor Financeiro',       'Administrativo',   'Senior', 6800.00, TRUE),
  ('TEC', 'Tecnico de TI',           'Tecnologia',       'Pleno',  4100.00, TRUE),
  ('RHC', 'Analista de RH',          'Recursos Humanos', 'Pleno',  3900.00, TRUE);

-- ============================================================
-- Eventos de folha
-- ============================================================

INSERT IGNORE INTO evento_folha (nome_evento, tipo) VALUES
  ('Vale Refeicao',   'Provento'),
  ('Salario Familia', 'Provento'),
  ('Hora Extra',      'Provento'),
  ('INSS',            'Desconto'),
  ('IRRF',            'Desconto'),
  ('Vale Transporte', 'Desconto'),
  ('Plano de Saude',  'Desconto');

-- ============================================================
-- Funcionarios
-- ============================================================

INSERT IGNORE INTO funcionario
  (rgf, cpf, nome, sobrenome, data_nascimento, codigo_cargo, data_admissao, data_desligamento, status)
VALUES
  ('F0001', '12345678901', 'Carlos',   'Souza',    '1985-03-15', 'PRF', '2020-01-10', NULL, 'Ativo'),
  ('F0002', '23456789012', 'Ana',      'Lima',     '1988-07-22', 'PRF', '2021-03-01', NULL, 'Ativo'),
  ('F0003', '34567890123', 'Pedro',    'Rocha',    '1979-11-05', 'COO', '2018-06-15', NULL, 'Ativo'),
  ('F0004', '45678901234', 'Julia',    'Mendes',   '1990-04-18', 'GES', '2022-02-01', NULL, 'Ativo'),
  ('F0005', '56789012345', 'Marcos',   'Oliveira', '1992-09-30', 'TEC', '2023-01-10', NULL, 'Ativo'),
  ('F0006', '67890123456', 'Fernanda', 'Costa',    '1987-12-01', 'RHC', '2019-08-20', NULL, 'Ativo');

-- professor e papel de funcionario (1:1, PK herdada)
INSERT IGNORE INTO professor (fk_rgf, formacao, especialidade, ativo) VALUES
  ('F0001', 'Mestrado em Ciencia da Computacao', 'Banco de Dados e Sistemas Distribuidos', TRUE),
  ('F0002', 'Especializacao em Enfermagem',       'Anatomia e Fisiologia Humana',           TRUE);

INSERT IGNORE INTO documentos_trabalhistas
  (fk_rgf, pis, numero_ctps, serie_ctps, titulo_eleitor)
VALUES
  ('F0001', '10020030041', '1234567', '0001', '123456789012'),
  ('F0002', '20030040052', '2345678', '0002', '234567890123'),
  ('F0003', '30040050063', '3456789', '0003', '345678901234'),
  ('F0004', '40050060074', '4567890', '0004', '456789012345'),
  ('F0005', '50060070085', '5678901', '0005', '567890123456'),
  ('F0006', '60070080096', '6789012', '0006', '678901234567');

-- 1 conta principal por funcionario
INSERT IGNORE INTO conta_banco_funcionario
  (pk_id_conta, fk_rgf, banco, agencia, conta, digito_conta, tipo_conta, principal, ativo)
VALUES
  (1, 'F0001', 'Banco do Brasil', '0001-9', '12345-6', '6', 'Corrente',  TRUE, TRUE),
  (2, 'F0002', 'Itau',            '0342-7', '23456-7', '7', 'Corrente',  TRUE, TRUE),
  (3, 'F0003', 'Bradesco',        '1234-5', '34567-8', '8', 'Corrente',  TRUE, TRUE),
  (4, 'F0004', 'Caixa',           '5678-1', '45678-9', '9', 'Salario',   TRUE, TRUE),
  (5, 'F0005', 'Nubank',          '0000-1', '56789-0', '0', 'Corrente',  TRUE, TRUE),
  (6, 'F0006', 'Santander',       '9876-5', '67890-1', '1', 'Poupanca',  TRUE, TRUE);

-- 1 entrada vigente por funcionario (data_fim NULL = salario atual)
-- TR_historico_salario_vigente suprimido pelo INSERT IGNORE na 2a execucao
INSERT IGNORE INTO historico_salario
  (pk_id_historico, fk_rgf, salario, data_inicio, data_fim, motivo_alteracao)
VALUES
  (1, 'F0001', 4500.00, '2020-01-10', NULL, 'Admissao'),
  (2, 'F0002', 4500.00, '2021-03-01', NULL, 'Admissao'),
  (3, 'F0003', 7200.00, '2018-06-15', NULL, 'Admissao'),
  (4, 'F0004', 6800.00, '2022-02-01', NULL, 'Admissao'),
  (5, 'F0005', 4100.00, '2023-01-10', NULL, 'Admissao'),
  (6, 'F0006', 3900.00, '2019-08-20', NULL, 'Admissao');

INSERT IGNORE INTO dependente
  (rgd, fk_rgf, cpf, nome, sobrenome, data_nascimento, parentesco, dependente_ir, dependente_plano_saude, ativo)
VALUES
  ('D0001', 'F0001', '98765432100', 'Beatriz', 'Souza', '2010-06-01', 'Filho Biologico', TRUE,  TRUE,  TRUE),
  ('D0002', 'F0003', '87654321000', 'Carla',   'Rocha', '1982-02-14', 'Conjuge',         FALSE, TRUE,  TRUE),
  ('D0003', 'F0006', '76543210900', 'Helena',  'Costa', '2015-11-20', 'Filho Biologico', TRUE,  TRUE,  TRUE);

-- periodos aquisitivos para quem tem mais de 1 ano de casa
INSERT IGNORE INTO periodo_aquisitivo
  (pk_id_periodo, fk_rgf, data_inicio, data_fim, dias_direito)
VALUES
  (1, 'F0001', '2020-01-10', '2021-01-09', 30),
  (2, 'F0001', '2021-01-10', '2022-01-09', 30),
  (3, 'F0003', '2018-06-15', '2019-06-14', 30),
  (4, 'F0006', '2019-08-20', '2020-08-19', 30);

-- TR_ferias_dentro_periodo: datas dentro do periodo aquisitivo
-- f1: F0001 periodo 2 (2021-01-10 a 2022-01-09) — julho/2021 ok
-- f2: F0003 periodo 3 (2018-06-15 a 2019-06-14) — janeiro/2019 ok
-- f3: F0006 periodo 4 (2019-08-20 a 2020-08-19) — janeiro/2020 ok
INSERT IGNORE INTO ferias (pk_id_ferias, fk_id_periodo, data_inicio, data_fim, status) VALUES
  (1, 2, '2021-07-05', '2021-07-25', 'Concluida'),
  (2, 3, '2019-01-07', '2019-01-27', 'Concluida'),
  (3, 4, '2020-01-06', '2020-01-26', 'Concluida');

-- registros de ponto: ordem cronologica por funcionario (trigger de alternancia)
-- padrao simples: Entrada → Saida por dia
INSERT IGNORE INTO ponto (fk_rgf, data_hora, tipo) VALUES
  ('F0001', '2024-03-04 07:55:00', 'Entrada'),
  ('F0001', '2024-03-04 17:05:00', 'Saida'),
  ('F0001', '2024-03-05 07:58:00', 'Entrada'),
  ('F0001', '2024-03-05 17:02:00', 'Saida'),
  ('F0002', '2024-03-04 08:01:00', 'Entrada'),
  ('F0002', '2024-03-04 17:00:00', 'Saida'),
  ('F0002', '2024-03-05 08:00:00', 'Entrada'),
  ('F0002', '2024-03-05 17:10:00', 'Saida'),
  ('F0003', '2024-03-04 08:30:00', 'Entrada'),
  ('F0003', '2024-03-04 18:00:00', 'Saida'),
  ('F0003', '2024-03-05 08:25:00', 'Entrada'),
  ('F0003', '2024-03-05 17:55:00', 'Saida'),
  ('F0004', '2024-03-04 09:00:00', 'Entrada'),
  ('F0004', '2024-03-04 18:05:00', 'Saida'),
  ('F0004', '2024-03-05 09:02:00', 'Entrada'),
  ('F0004', '2024-03-05 18:00:00', 'Saida'),
  ('F0005', '2024-03-04 08:50:00', 'Entrada'),
  ('F0005', '2024-03-04 17:50:00', 'Saida'),
  ('F0005', '2024-03-05 08:55:00', 'Entrada'),
  ('F0005', '2024-03-05 17:48:00', 'Saida'),
  ('F0006', '2024-03-04 08:45:00', 'Entrada'),
  ('F0006', '2024-03-04 17:45:00', 'Saida'),
  ('F0006', '2024-03-05 08:40:00', 'Entrada'),
  ('F0006', '2024-03-05 17:50:00', 'Saida');

INSERT IGNORE INTO ocorrencia_desconto
  (pk_id_ocorrencia, fk_rgf, tipo_ocorrencia, data_ocorrencia, minutos)
VALUES
  (1, 'F0002', 'Atraso',          '2024-02-15', 20),
  (2, 'F0005', 'Saida antecipada', '2024-02-20', 30);

-- folha: 3 meses para todos os funcionarios
INSERT IGNORE INTO folha_pagamentos (fk_rgf, periodo, salario_bruto, data_pagamento, status) VALUES
  ('F0001', '2024-01', 4500.00, '2024-01-31', 'Paga'),
  ('F0001', '2024-02', 4500.00, '2024-02-29', 'Paga'),
  ('F0001', '2024-03', 4500.00, '2024-03-29', 'Paga'),
  ('F0002', '2024-01', 4500.00, '2024-01-31', 'Paga'),
  ('F0002', '2024-02', 4500.00, '2024-02-29', 'Paga'),
  ('F0002', '2024-03', 4500.00, '2024-03-29', 'Paga'),
  ('F0003', '2024-01', 7200.00, '2024-01-31', 'Paga'),
  ('F0003', '2024-02', 7200.00, '2024-02-29', 'Paga'),
  ('F0003', '2024-03', 7200.00, '2024-03-29', 'Paga'),
  ('F0004', '2024-01', 6800.00, '2024-01-31', 'Paga'),
  ('F0004', '2024-02', 6800.00, '2024-02-29', 'Paga'),
  ('F0004', '2024-03', 6800.00, '2024-03-29', 'Paga'),
  ('F0005', '2024-01', 4100.00, '2024-01-31', 'Paga'),
  ('F0005', '2024-02', 4100.00, '2024-02-29', 'Paga'),
  ('F0005', '2024-03', 4100.00, '2024-03-29', 'Paga'),
  ('F0006', '2024-01', 3900.00, '2024-01-31', 'Paga'),
  ('F0006', '2024-02', 3900.00, '2024-02-29', 'Paga'),
  ('F0006', '2024-03', 3900.00, '2024-03-29', 'Paga');

-- eventos: proventos e descontos por folha
-- valor sempre positivo; sinal determinado pelo tipo em evento_folha
INSERT IGNORE INTO folha_evento (fk_rgf, periodo, nome_evento, valor) VALUES
  -- F0001 (PRF, 4500.00)
  ('F0001', '2024-01', 'Vale Refeicao',   440.00),
  ('F0001', '2024-01', 'INSS',            495.00),
  ('F0001', '2024-01', 'IRRF',            338.00),
  ('F0001', '2024-01', 'Vale Transporte', 220.00),
  ('F0001', '2024-02', 'Vale Refeicao',   440.00),
  ('F0001', '2024-02', 'INSS',            495.00),
  ('F0001', '2024-02', 'IRRF',            338.00),
  ('F0001', '2024-02', 'Vale Transporte', 220.00),
  ('F0001', '2024-03', 'Vale Refeicao',   440.00),
  ('F0001', '2024-03', 'INSS',            495.00),
  ('F0001', '2024-03', 'IRRF',            338.00),
  ('F0001', '2024-03', 'Vale Transporte', 220.00),
  -- F0002 (PRF, 4500.00) — tem dependente IR
  ('F0002', '2024-01', 'Vale Refeicao',   440.00),
  ('F0002', '2024-01', 'Salario Familia',  89.00),
  ('F0002', '2024-01', 'INSS',            495.00),
  ('F0002', '2024-01', 'IRRF',            338.00),
  ('F0002', '2024-01', 'Vale Transporte', 220.00),
  ('F0002', '2024-02', 'Vale Refeicao',   440.00),
  ('F0002', '2024-02', 'Salario Familia',  89.00),
  ('F0002', '2024-02', 'INSS',            495.00),
  ('F0002', '2024-02', 'IRRF',            338.00),
  ('F0002', '2024-02', 'Vale Transporte', 220.00),
  ('F0002', '2024-03', 'Vale Refeicao',   440.00),
  ('F0002', '2024-03', 'Salario Familia',  89.00),
  ('F0002', '2024-03', 'INSS',            495.00),
  ('F0002', '2024-03', 'IRRF',            338.00),
  ('F0002', '2024-03', 'Vale Transporte', 220.00),
  -- F0003 (COO, 7200.00)
  ('F0003', '2024-01', 'Vale Refeicao',   440.00),
  ('F0003', '2024-01', 'INSS',            792.00),
  ('F0003', '2024-01', 'IRRF',           1116.68),
  ('F0003', '2024-01', 'Plano de Saude',  180.00),
  ('F0003', '2024-02', 'Vale Refeicao',   440.00),
  ('F0003', '2024-02', 'INSS',            792.00),
  ('F0003', '2024-02', 'IRRF',           1116.68),
  ('F0003', '2024-02', 'Plano de Saude',  180.00),
  ('F0003', '2024-03', 'Vale Refeicao',   440.00),
  ('F0003', '2024-03', 'INSS',            792.00),
  ('F0003', '2024-03', 'IRRF',           1116.68),
  ('F0003', '2024-03', 'Plano de Saude',  180.00),
  -- F0004 (GES, 6800.00)
  ('F0004', '2024-01', 'Vale Refeicao',   440.00),
  ('F0004', '2024-01', 'INSS',            748.00),
  ('F0004', '2024-01', 'IRRF',           1016.36),
  ('F0004', '2024-01', 'Plano de Saude',  180.00),
  ('F0004', '2024-02', 'Vale Refeicao',   440.00),
  ('F0004', '2024-02', 'INSS',            748.00),
  ('F0004', '2024-02', 'IRRF',           1016.36),
  ('F0004', '2024-02', 'Plano de Saude',  180.00),
  ('F0004', '2024-03', 'Vale Refeicao',   440.00),
  ('F0004', '2024-03', 'INSS',            748.00),
  ('F0004', '2024-03', 'IRRF',           1016.36),
  ('F0004', '2024-03', 'Plano de Saude',  180.00),
  -- F0005 (TEC, 4100.00)
  ('F0005', '2024-01', 'Vale Refeicao',   440.00),
  ('F0005', '2024-01', 'INSS',            492.00),
  ('F0005', '2024-01', 'IRRF',            346.18),
  ('F0005', '2024-01', 'Vale Transporte', 220.00),
  ('F0005', '2024-02', 'Vale Refeicao',   440.00),
  ('F0005', '2024-02', 'INSS',            492.00),
  ('F0005', '2024-02', 'IRRF',            346.18),
  ('F0005', '2024-02', 'Vale Transporte', 220.00),
  ('F0005', '2024-03', 'Vale Refeicao',   440.00),
  ('F0005', '2024-03', 'INSS',            492.00),
  ('F0005', '2024-03', 'IRRF',            346.18),
  ('F0005', '2024-03', 'Vale Transporte', 220.00),
  -- F0006 (RHC, 3900.00) — tem dependente IR
  ('F0006', '2024-01', 'Vale Refeicao',   440.00),
  ('F0006', '2024-01', 'Salario Familia',  89.00),
  ('F0006', '2024-01', 'INSS',            468.00),
  ('F0006', '2024-01', 'IRRF',            286.44),
  ('F0006', '2024-01', 'Vale Transporte', 220.00),
  ('F0006', '2024-02', 'Vale Refeicao',   440.00),
  ('F0006', '2024-02', 'Salario Familia',  89.00),
  ('F0006', '2024-02', 'INSS',            468.00),
  ('F0006', '2024-02', 'IRRF',            286.44),
  ('F0006', '2024-02', 'Vale Transporte', 220.00),
  ('F0006', '2024-03', 'Vale Refeicao',   440.00),
  ('F0006', '2024-03', 'Salario Familia',  89.00),
  ('F0006', '2024-03', 'INSS',            468.00),
  ('F0006', '2024-03', 'IRRF',            286.44),
  ('F0006', '2024-03', 'Vale Transporte', 220.00);

-- ocorrencias vinculadas a folha
INSERT IGNORE INTO folha_ocorrencia (fk_rgf, periodo, pk_id_ocorrencia) VALUES
  ('F0002', '2024-02', 1),
  ('F0005', '2024-02', 2);


-- ============================================================
-- MODULO ACADEMICO
-- ============================================================

INSERT IGNORE INTO curso (codigo_curso, nome_curso, descricao, nivel_ensino, ativo) VALUES
  ('ADS', 'Analise e Desenvolvimento de Sistemas',
          'Forma profissionais para desenvolvimento de software e gestao de sistemas.',
          'Tecnologo', TRUE),
  ('ENF', 'Enfermagem',
          'Habilita enfermeiros para atuacao hospitalar e atencao basica.',
          'Bacharelado', TRUE),
  ('LOG', 'Logistica',
          'Capacita para planejamento e controle de cadeias de suprimentos.',
          'Tecnico', TRUE);

INSERT IGNORE INTO materia (codigo_materia, nome_materia, carga_horaria, ativo) VALUES
  ('BD001', 'Banco de Dados',                    80, TRUE),
  ('PG001', 'Programacao Orientada a Objetos',   80, TRUE),
  ('RE001', 'Redes de Computadores',             60, TRUE),
  ('AN001', 'Anatomia Humana',                   80, TRUE),
  ('FA001', 'Farmacologia Basica',               60, TRUE),
  ('OG001', 'Organizacao e Gestao',              60, TRUE);

INSERT IGNORE INTO curso_materia (codigo_curso, codigo_materia, obrigatoria, semestre_recomendado) VALUES
  ('ADS', 'BD001', TRUE,  1),
  ('ADS', 'PG001', TRUE,  1),
  ('ADS', 'RE001', TRUE,  2),
  ('ENF', 'AN001', TRUE,  1),
  ('ENF', 'FA001', TRUE,  2),
  ('LOG', 'OG001', TRUE,  1),
  ('LOG', 'RE001', FALSE, 2);

-- calendario institucional (fk_curso NULL = vale para todos)
-- UNIQUE(ano, semestre, fk_curso) nao bloqueia NULL no MySQL
-- TR_calendario_unico_institucional garante unicidade do NULL via trigger
-- INSERT IGNORE suprime o SIGNAL do trigger na 2a execucao
INSERT IGNORE INTO calendario_academico
  (pk_id_calendario, ano, semestre, data_inicio, data_fim, descricao, fk_curso, ativo)
VALUES
  (1, 2024, 1, '2024-02-01', '2024-07-15', 'Semestre letivo 2024/1', NULL, TRUE),
  (2, 2024, 2, '2024-08-01', '2025-01-31', 'Semestre letivo 2024/2', NULL, TRUE);

INSERT IGNORE INTO aluno
  (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES
  ('A0000001', '11122233344', 'Joao',     'Santos',    '2000-05-10', 'Ativo'),
  ('A0000002', '22233344455', 'Maria',    'Oliveira',  '2001-08-15', 'Ativo'),
  ('A0000003', '33344455566', 'Lucas',    'Pereira',   '1999-11-20', 'Ativo'),
  ('A0000004', '44455566677', 'Patricia', 'Almeida',   '2002-03-05', 'Ativo'),
  ('A0000005', '55566677788', 'Rafael',   'Costa',     '2000-07-25', 'Ativo'),
  ('A0000006', '66677788899', 'Camila',   'Ferreira',  '2001-01-12', 'Ativo'),
  ('A0000007', '77788899900', 'Bruno',    'Rodrigues', '1998-06-30', 'Ativo'),
  ('A0000008', '88899900011', 'Larissa',  'Silva',     '2003-09-18', 'Ativo');

-- TR_matricula_ativa: max 1 'Cursando' por aluno por curso
INSERT IGNORE INTO matricula
  (pk_id_matricula, fk_rga, fk_curso, data_matricula, status, ano_ingresso)
VALUES
  (1, 'A0000001', 'ADS', '2024-01-15', 'Cursando', 2024),
  (2, 'A0000002', 'ADS', '2024-01-16', 'Cursando', 2024),
  (3, 'A0000003', 'ADS', '2024-01-17', 'Cursando', 2024),
  (4, 'A0000004', 'ENF', '2024-01-18', 'Cursando', 2024),
  (5, 'A0000005', 'ENF', '2024-01-19', 'Cursando', 2024),
  (6, 'A0000006', 'LOG', '2024-01-20', 'Cursando', 2024),
  (7, 'A0000007', 'LOG', '2024-01-21', 'Cursando', 2024),
  (8, 'A0000008', 'ADS', '2024-01-22', 'Cursando', 2024);

-- turmas 2024/1 — calendario institucional (pk_id=1)
-- UQ_turma: (fk_curso, fk_materia, fk_id_calendario, turno)
INSERT IGNORE INTO turma
  (pk_id_turma, fk_rgf, fk_curso, fk_materia, fk_id_calendario, turno, limite_alunos)
VALUES
  (1, 'F0001', 'ADS', 'BD001', 1, 'Manha', 30),
  (2, 'F0001', 'ADS', 'PG001', 1, 'Manha', 30),
  (3, 'F0002', 'ADS', 'RE001', 1, 'Noite',  30),
  (4, 'F0002', 'ENF', 'AN001', 1, 'Tarde',  25),
  (5, 'F0001', 'ENF', 'FA001', 1, 'Tarde',  25),
  (6, 'F0002', 'LOG', 'OG001', 1, 'Manha', 20);

-- ADS (mat 1,2,3,8) → turmas 1,2,3 | ENF (mat 4,5) → turmas 4,5 | LOG (mat 6,7) → turma 6
INSERT IGNORE INTO matricula_turma (fk_id_matricula, fk_id_turma, status) VALUES
  (1, 1, 'Cursando'), (1, 2, 'Cursando'), (1, 3, 'Cursando'),
  (2, 1, 'Cursando'), (2, 2, 'Cursando'), (2, 3, 'Cursando'),
  (3, 1, 'Cursando'), (3, 2, 'Cursando'), (3, 3, 'Cursando'),
  (8, 1, 'Cursando'), (8, 2, 'Cursando'), (8, 3, 'Cursando'),
  (4, 4, 'Cursando'), (4, 5, 'Cursando'),
  (5, 4, 'Cursando'), (5, 5, 'Cursando'),
  (6, 6, 'Cursando'),
  (7, 6, 'Cursando');

INSERT IGNORE INTO avaliacao
  (pk_id_avaliacao, fk_id_turma, nome_atividade, peso, data_aplicacao)
VALUES
  ( 1, 1, 'Prova 1',   1.00, '2024-04-10'),
  ( 2, 1, 'Trabalho',  0.50, '2024-05-20'),
  ( 3, 2, 'Prova 1',   1.00, '2024-04-12'),
  ( 4, 2, 'Prova 2',   1.00, '2024-06-10'),
  ( 5, 3, 'Prova 1',   1.00, '2024-04-15'),
  ( 6, 4, 'Prova 1',   1.00, '2024-04-11'),
  ( 7, 4, 'Prova 2',   1.00, '2024-06-05'),
  ( 8, 5, 'Prova 1',   1.00, '2024-04-18'),
  ( 9, 6, 'Prova 1',   1.00, '2024-04-09'),
  (10, 6, 'Trabalho',  0.50, '2024-05-15');

-- TR_nota_aluno_na_turma: fk_id_matricula deve estar na turma da avaliacao
INSERT IGNORE INTO nota (fk_id_avaliacao, fk_id_matricula, nota_atividade) VALUES
  -- aval 1 e 2 (turma 1 / BD001 — matriculas 1,2,3,8)
  (1, 1, 8.50), (1, 2, 7.00), (1, 3, 9.00), (1, 8, 6.50),
  (2, 1, 9.00), (2, 2, 8.00), (2, 3, 8.50), (2, 8, 7.50),
  -- aval 3 e 4 (turma 2 / PG001)
  (3, 1, 7.50), (3, 2, 8.50), (3, 3, 7.00), (3, 8, 9.00),
  (4, 1, 8.00), (4, 2, 7.50), (4, 3, 8.00), (4, 8, 8.50),
  -- aval 5 (turma 3 / RE001)
  (5, 1, 6.50), (5, 2, 7.00), (5, 3, 8.00), (5, 8, 7.00),
  -- aval 6 e 7 (turma 4 / AN001 — matriculas 4,5)
  (6, 4, 8.00), (6, 5, 7.50),
  (7, 4, 8.50), (7, 5, 8.00),
  -- aval 8 (turma 5 / FA001)
  (8, 4, 7.00), (8, 5, 8.00),
  -- aval 9 e 10 (turma 6 / OG001 — matriculas 6,7)
  (9, 6, 9.00), (9, 7, 7.50),
  (10, 6, 8.50), (10, 7, 7.00);

-- TR_frequencia_aluno_na_turma: aluno deve estar em matricula_turma
INSERT IGNORE INTO frequencia (fk_id_matricula, fk_id_turma, data_aula, presente, justificativa) VALUES
  -- turma 1 (BD001)
  (1, 1, '2024-02-05', TRUE,  NULL),
  (1, 1, '2024-02-12', TRUE,  NULL),
  (1, 1, '2024-02-19', FALSE, 'Atestado medico'),
  (2, 1, '2024-02-05', TRUE,  NULL),
  (2, 1, '2024-02-12', TRUE,  NULL),
  (2, 1, '2024-02-19', TRUE,  NULL),
  (3, 1, '2024-02-05', TRUE,  NULL),
  (3, 1, '2024-02-12', FALSE, NULL),
  (3, 1, '2024-02-19', TRUE,  NULL),
  (8, 1, '2024-02-05', TRUE,  NULL),
  (8, 1, '2024-02-12', TRUE,  NULL),
  (8, 1, '2024-02-19', TRUE,  NULL),
  -- turma 4 (AN001)
  (4, 4, '2024-02-06', TRUE,  NULL),
  (4, 4, '2024-02-13', TRUE,  NULL),
  (4, 4, '2024-02-20', TRUE,  NULL),
  (5, 4, '2024-02-06', TRUE,  NULL),
  (5, 4, '2024-02-13', FALSE, NULL),
  (5, 4, '2024-02-20', TRUE,  NULL),
  -- turma 6 (OG001)
  (6, 6, '2024-02-07', TRUE,  NULL),
  (6, 6, '2024-02-14', TRUE,  NULL),
  (6, 6, '2024-02-21', TRUE,  NULL),
  (7, 6, '2024-02-07', TRUE,  NULL),
  (7, 6, '2024-02-14', TRUE,  NULL),
  (7, 6, '2024-02-21', FALSE, NULL);


-- ============================================================
-- MODULO FINANCEIRO
-- ============================================================

-- 1 contrato por matricula (UNIQUE fk_id_matricula)
INSERT IGNORE INTO contrato
  (pk_id_contrato, fk_id_matricula, data_assinatura, data_inicio_vigencia, data_fim_vigencia,
   valor_mensalidade_referencia, status)
VALUES
  (1, 1, '2024-01-15', '2024-02-01', NULL,  950.00, 'Ativo'),
  (2, 2, '2024-01-16', '2024-02-01', NULL,  950.00, 'Ativo'),
  (3, 3, '2024-01-17', '2024-02-01', NULL,  950.00, 'Ativo'),
  (4, 4, '2024-01-18', '2024-02-01', NULL, 1200.00, 'Ativo'),
  (5, 5, '2024-01-19', '2024-02-01', NULL, 1200.00, 'Ativo'),
  (6, 6, '2024-01-20', '2024-02-01', NULL,  750.00, 'Ativo'),
  (7, 7, '2024-01-21', '2024-02-01', NULL,  750.00, 'Ativo'),
  (8, 8, '2024-01-22', '2024-02-01', NULL,  950.00, 'Ativo');

-- bolsas: Joao Santos 25%, Camila Ferreira 50%
INSERT IGNORE INTO bolsa (pk_id_bolsa, fk_id_contrato, percentual, data_inicio, data_fim, ativo) VALUES
  (1, 1, 25.00, '2024-02-01', NULL, TRUE),
  (2, 6, 50.00, '2024-02-01', NULL, TRUE);

-- mensalidades: 6 meses por contrato (fev–jul/2024)
-- valor_desconto reflete bolsa vigente no momento da geracao (snapshot intencional)
INSERT IGNORE INTO mensalidade
  (fk_id_contrato, periodo, valor_base, valor_desconto, data_vencimento, status)
VALUES
  -- contrato 1 (ADS/Joao, 25% = 237.50 de desconto)
  (1, '2024-02', 950.00, 237.50, '2024-02-10', 'Pago'),
  (1, '2024-03', 950.00, 237.50, '2024-03-10', 'Pago'),
  (1, '2024-04', 950.00, 237.50, '2024-04-10', 'Pago'),
  (1, '2024-05', 950.00, 237.50, '2024-05-10', 'Pago'),
  (1, '2024-06', 950.00, 237.50, '2024-06-10', 'Pago'),
  (1, '2024-07', 950.00, 237.50, '2024-07-10', 'Pendente'),
  -- contrato 2 (ADS/Maria, sem bolsa)
  (2, '2024-02', 950.00, 0.00, '2024-02-10', 'Pago'),
  (2, '2024-03', 950.00, 0.00, '2024-03-10', 'Pago'),
  (2, '2024-04', 950.00, 0.00, '2024-04-10', 'Pago'),
  (2, '2024-05', 950.00, 0.00, '2024-05-10', 'Pago'),
  (2, '2024-06', 950.00, 0.00, '2024-06-10', 'Pago'),
  (2, '2024-07', 950.00, 0.00, '2024-07-10', 'Atrasado'),
  -- contrato 3 (ADS/Lucas)
  (3, '2024-02', 950.00, 0.00, '2024-02-10', 'Pago'),
  (3, '2024-03', 950.00, 0.00, '2024-03-10', 'Pago'),
  (3, '2024-04', 950.00, 0.00, '2024-04-10', 'Pago'),
  (3, '2024-05', 950.00, 0.00, '2024-05-10', 'Pago'),
  (3, '2024-06', 950.00, 0.00, '2024-06-10', 'Pago'),
  (3, '2024-07', 950.00, 0.00, '2024-07-10', 'Pendente'),
  -- contrato 4 (ENF/Patricia)
  (4, '2024-02', 1200.00, 0.00, '2024-02-10', 'Pago'),
  (4, '2024-03', 1200.00, 0.00, '2024-03-10', 'Pago'),
  (4, '2024-04', 1200.00, 0.00, '2024-04-10', 'Pago'),
  (4, '2024-05', 1200.00, 0.00, '2024-05-10', 'Pago'),
  (4, '2024-06', 1200.00, 0.00, '2024-06-10', 'Pago'),
  (4, '2024-07', 1200.00, 0.00, '2024-07-10', 'Pendente'),
  -- contrato 5 (ENF/Rafael)
  (5, '2024-02', 1200.00, 0.00, '2024-02-10', 'Pago'),
  (5, '2024-03', 1200.00, 0.00, '2024-03-10', 'Pago'),
  (5, '2024-04', 1200.00, 0.00, '2024-04-10', 'Pago'),
  (5, '2024-05', 1200.00, 0.00, '2024-05-10', 'Pago'),
  (5, '2024-06', 1200.00, 0.00, '2024-06-10', 'Pago'),
  (5, '2024-07', 1200.00, 0.00, '2024-07-10', 'Pendente'),
  -- contrato 6 (LOG/Camila, 50% = 375.00 de desconto)
  (6, '2024-02', 750.00, 375.00, '2024-02-10', 'Pago'),
  (6, '2024-03', 750.00, 375.00, '2024-03-10', 'Pago'),
  (6, '2024-04', 750.00, 375.00, '2024-04-10', 'Pago'),
  (6, '2024-05', 750.00, 375.00, '2024-05-10', 'Pago'),
  (6, '2024-06', 750.00, 375.00, '2024-06-10', 'Pago'),
  (6, '2024-07', 750.00, 375.00, '2024-07-10', 'Pendente'),
  -- contrato 7 (LOG/Bruno)
  (7, '2024-02', 750.00, 0.00, '2024-02-10', 'Pago'),
  (7, '2024-03', 750.00, 0.00, '2024-03-10', 'Pago'),
  (7, '2024-04', 750.00, 0.00, '2024-04-10', 'Pago'),
  (7, '2024-05', 750.00, 0.00, '2024-05-10', 'Pago'),
  (7, '2024-06', 750.00, 0.00, '2024-06-10', 'Pago'),
  (7, '2024-07', 750.00, 0.00, '2024-07-10', 'Pendente'),
  -- contrato 8 (ADS/Larissa)
  (8, '2024-02', 950.00, 0.00, '2024-02-10', 'Pago'),
  (8, '2024-03', 950.00, 0.00, '2024-03-10', 'Pago'),
  (8, '2024-04', 950.00, 0.00, '2024-04-10', 'Pago'),
  (8, '2024-05', 950.00, 0.00, '2024-05-10', 'Pago'),
  (8, '2024-06', 950.00, 0.00, '2024-06-10', 'Pago'),
  (8, '2024-07', 950.00, 0.00, '2024-07-10', 'Pendente');

-- atraso registrado para contrato 2 / 2024-07
INSERT IGNORE INTO atraso_mensalidade
  (fk_id_contrato, periodo, dias_atraso, valor_multa, valor_juros)
VALUES
  (2, '2024-07', 15, 14.25, 9.50);

-- pagamentos dos meses quitados (fev–jun/2024)
INSERT IGNORE INTO pagamento
  (pk_id_pagamento, fk_id_contrato, periodo, metodo, data_pagamento, valor_pago, status, id_transacao_externo)
VALUES
  -- contrato 1 (valor_final = 712.50)
  ( 1, 1, '2024-02', 'Pix',           '2024-02-08',  712.50, 'Pago', 'PIX-2024-0201'),
  ( 2, 1, '2024-03', 'Pix',           '2024-03-08',  712.50, 'Pago', 'PIX-2024-0301'),
  ( 3, 1, '2024-04', 'Pix',           '2024-04-08',  712.50, 'Pago', 'PIX-2024-0401'),
  ( 4, 1, '2024-05', 'Pix',           '2024-05-08',  712.50, 'Pago', 'PIX-2024-0501'),
  ( 5, 1, '2024-06', 'Pix',           '2024-06-08',  712.50, 'Pago', 'PIX-2024-0601'),
  -- contrato 2 (950.00)
  ( 6, 2, '2024-02', 'Boleto',        '2024-02-09',  950.00, 'Pago', 'BOL-2024-0202'),
  ( 7, 2, '2024-03', 'Boleto',        '2024-03-09',  950.00, 'Pago', 'BOL-2024-0302'),
  ( 8, 2, '2024-04', 'Boleto',        '2024-04-09',  950.00, 'Pago', 'BOL-2024-0402'),
  ( 9, 2, '2024-05', 'Boleto',        '2024-05-09',  950.00, 'Pago', 'BOL-2024-0502'),
  (10, 2, '2024-06', 'Boleto',        '2024-06-09',  950.00, 'Pago', 'BOL-2024-0602'),
  -- contrato 3 (950.00)
  (11, 3, '2024-02', 'Cartao',        '2024-02-10',  950.00, 'Pago', NULL),
  (12, 3, '2024-03', 'Cartao',        '2024-03-10',  950.00, 'Pago', NULL),
  (13, 3, '2024-04', 'Cartao',        '2024-04-10',  950.00, 'Pago', NULL),
  (14, 3, '2024-05', 'Cartao',        '2024-05-10',  950.00, 'Pago', NULL),
  (15, 3, '2024-06', 'Cartao',        '2024-06-10',  950.00, 'Pago', NULL),
  -- contrato 4 (1200.00)
  (16, 4, '2024-02', 'Pix',           '2024-02-08', 1200.00, 'Pago', 'PIX-2024-0204'),
  (17, 4, '2024-03', 'Pix',           '2024-03-08', 1200.00, 'Pago', 'PIX-2024-0304'),
  (18, 4, '2024-04', 'Pix',           '2024-04-08', 1200.00, 'Pago', 'PIX-2024-0404'),
  (19, 4, '2024-05', 'Pix',           '2024-05-08', 1200.00, 'Pago', 'PIX-2024-0504'),
  (20, 4, '2024-06', 'Pix',           '2024-06-08', 1200.00, 'Pago', 'PIX-2024-0604'),
  -- contrato 5 (1200.00)
  (21, 5, '2024-02', 'Transferencia', '2024-02-09', 1200.00, 'Pago', NULL),
  (22, 5, '2024-03', 'Transferencia', '2024-03-09', 1200.00, 'Pago', NULL),
  (23, 5, '2024-04', 'Transferencia', '2024-04-09', 1200.00, 'Pago', NULL),
  (24, 5, '2024-05', 'Transferencia', '2024-05-09', 1200.00, 'Pago', NULL),
  (25, 5, '2024-06', 'Transferencia', '2024-06-09', 1200.00, 'Pago', NULL),
  -- contrato 6 (valor_final = 375.00)
  (26, 6, '2024-02', 'Pix',           '2024-02-08',  375.00, 'Pago', 'PIX-2024-0206'),
  (27, 6, '2024-03', 'Pix',           '2024-03-08',  375.00, 'Pago', 'PIX-2024-0306'),
  (28, 6, '2024-04', 'Pix',           '2024-04-08',  375.00, 'Pago', 'PIX-2024-0406'),
  (29, 6, '2024-05', 'Pix',           '2024-05-08',  375.00, 'Pago', 'PIX-2024-0506'),
  (30, 6, '2024-06', 'Pix',           '2024-06-08',  375.00, 'Pago', 'PIX-2024-0606'),
  -- contrato 7 (750.00)
  (31, 7, '2024-02', 'Dinheiro',      '2024-02-09',  750.00, 'Pago', NULL),
  (32, 7, '2024-03', 'Dinheiro',      '2024-03-09',  750.00, 'Pago', NULL),
  (33, 7, '2024-04', 'Dinheiro',      '2024-04-09',  750.00, 'Pago', NULL),
  (34, 7, '2024-05', 'Dinheiro',      '2024-05-09',  750.00, 'Pago', NULL),
  (35, 7, '2024-06', 'Dinheiro',      '2024-06-09',  750.00, 'Pago', NULL),
  -- contrato 8 (950.00)
  (36, 8, '2024-02', 'Pix',           '2024-02-08',  950.00, 'Pago', 'PIX-2024-0208'),
  (37, 8, '2024-03', 'Pix',           '2024-03-08',  950.00, 'Pago', 'PIX-2024-0308'),
  (38, 8, '2024-04', 'Pix',           '2024-04-08',  950.00, 'Pago', 'PIX-2024-0408'),
  (39, 8, '2024-05', 'Pix',           '2024-05-08',  950.00, 'Pago', 'PIX-2024-0508'),
  (40, 8, '2024-06', 'Pix',           '2024-06-08',  950.00, 'Pago', 'PIX-2024-0608');

-- pagamentos a vista: quita uma ou mais mensalidades em transacao unica
-- fluxo: pagamento_a_vista (cabecalho) → pagamento_avista_mensalidade (N mensalidades cobertas)
-- a aplicacao e responsavel por atualizar mensalidade.status apos registrar o avista
-- (nao ha trigger automatico: avista e fluxo alternativo ao pagamento recorrente)
--
-- cenario: Lucas Mendes (contrato 3 / ADS) quita julho/2024 presencialmente em dinheiro
INSERT IGNORE INTO pagamento_a_vista
  (pk_id_avista, fk_id_contrato, metodo, valor_total, data_pagamento, status)
VALUES
  (1, 3, 'Dinheiro', 950.00, '2024-07-03', 'Pago');

-- vincula o avista as mensalidades quitadas
INSERT IGNORE INTO pagamento_avista_mensalidade
  (fk_id_avista, fk_id_contrato, periodo)
VALUES
  (1, 3, '2024-07');

-- atualiza status da mensalidade para refletir o pagamento a vista
UPDATE mensalidade
   SET status = 'Pago'
 WHERE fk_id_contrato = 3 AND periodo = '2024-07' AND status = 'Pendente';

-- pagamento parcelado: contrato 2, julho/2024 (Atrasado -> quitado em 2 parcelas)
-- demonstra que o sistema aceita multiplos registros de pagamento para um mesmo periodo
-- caso real: aluno pagou 500 no dia 05/08 e 450 no dia 20/08 para quitar a mensalidade
INSERT IGNORE INTO pagamento
  (pk_id_pagamento, fk_id_contrato, periodo, metodo, data_pagamento, valor_pago, status, id_transacao_externo)
VALUES
  (41, 2, '2024-07', 'Pix', '2024-08-05', 500.00, 'Pago', 'PIX-2024-0807A'),
  (42, 2, '2024-07', 'Pix', '2024-08-20', 450.00, 'Pago', 'PIX-2024-0807B');

-- TR_pagamento_quita_mensalidade_insert atualiza mensalidade.status automaticamente
-- apos cada INSERT: 500 -> 'Parcial', 950 (500+450) -> 'Pago'
-- nao e necessario UPDATE manual aqui


-- conjuges na empresa (RN: empresa permite — registrar para gestao de beneficios)
INSERT IGNORE INTO conjuge_funcionario (fk_rgf_1, fk_rgf_2, tipo_uniao, data_uniao) VALUES
  ('F0003', 'F0004', 'Casamento',    '2015-09-12'),
  ('F0005', 'F0006', 'Uniao Estavel','2020-03-01');


-- ============================================================
-- CONTAGEM DEPOIS DA CARGA
-- Idempotencia confirmada quando ANTES (2a execucao) = DEPOIS (1a execucao)
-- ============================================================

SELECT 'DEPOIS' AS fase,
  (SELECT COUNT(*) FROM departamento)            AS departamento,
  (SELECT COUNT(*) FROM cargo)                   AS cargo,
  (SELECT COUNT(*) FROM funcionario)             AS funcionario,
  (SELECT COUNT(*) FROM professor)               AS professor,
  (SELECT COUNT(*) FROM aluno)                   AS aluno,
  (SELECT COUNT(*) FROM matricula)               AS matricula,
  (SELECT COUNT(*) FROM curso)                   AS curso,
  (SELECT COUNT(*) FROM turma)                   AS turma,
  (SELECT COUNT(*) FROM contrato)                AS contrato,
  (SELECT COUNT(*) FROM mensalidade)             AS mensalidade,
  (SELECT COUNT(*) FROM pagamento)               AS pagamento,
  (SELECT COUNT(*) FROM folha_pagamentos)        AS folha_pagamentos,
  (SELECT COUNT(*) FROM folha_evento)            AS folha_evento,
  (SELECT COUNT(*) FROM ferias)                  AS ferias,
  (SELECT COUNT(*) FROM ponto)                   AS ponto,
  (SELECT COUNT(*) FROM conjuge_funcionario)     AS conjuge_funcionario;

-- ============================================================
-- DETALHAMENTO COMPLETO — todas as 33 tabelas operacionais
-- ============================================================

SELECT 'departamento'            AS tabela, COUNT(*) AS registros FROM departamento
UNION ALL SELECT 'cargo',                   COUNT(*) FROM cargo
UNION ALL SELECT 'evento_folha',            COUNT(*) FROM evento_folha
UNION ALL SELECT 'funcionario',             COUNT(*) FROM funcionario
UNION ALL SELECT 'professor',               COUNT(*) FROM professor
UNION ALL SELECT 'documentos_trabalhistas', COUNT(*) FROM documentos_trabalhistas
UNION ALL SELECT 'conta_banco_funcionario', COUNT(*) FROM conta_banco_funcionario
UNION ALL SELECT 'historico_salario',       COUNT(*) FROM historico_salario
UNION ALL SELECT 'dependente',              COUNT(*) FROM dependente
UNION ALL SELECT 'periodo_aquisitivo',      COUNT(*) FROM periodo_aquisitivo
UNION ALL SELECT 'ferias',                  COUNT(*) FROM ferias
UNION ALL SELECT 'ponto',                   COUNT(*) FROM ponto
UNION ALL SELECT 'ocorrencia_desconto',     COUNT(*) FROM ocorrencia_desconto
UNION ALL SELECT 'folha_pagamentos',        COUNT(*) FROM folha_pagamentos
UNION ALL SELECT 'folha_evento',            COUNT(*) FROM folha_evento
UNION ALL SELECT 'folha_ocorrencia',        COUNT(*) FROM folha_ocorrencia
UNION ALL SELECT 'curso',                   COUNT(*) FROM curso
UNION ALL SELECT 'materia',                 COUNT(*) FROM materia
UNION ALL SELECT 'curso_materia',           COUNT(*) FROM curso_materia
UNION ALL SELECT 'calendario_academico',    COUNT(*) FROM calendario_academico
UNION ALL SELECT 'aluno',                   COUNT(*) FROM aluno
UNION ALL SELECT 'matricula',               COUNT(*) FROM matricula
UNION ALL SELECT 'turma',                   COUNT(*) FROM turma
UNION ALL SELECT 'matricula_turma',         COUNT(*) FROM matricula_turma
UNION ALL SELECT 'avaliacao',               COUNT(*) FROM avaliacao
UNION ALL SELECT 'nota',                    COUNT(*) FROM nota
UNION ALL SELECT 'frequencia',              COUNT(*) FROM frequencia
UNION ALL SELECT 'contrato',                COUNT(*) FROM contrato
UNION ALL SELECT 'bolsa',                   COUNT(*) FROM bolsa
UNION ALL SELECT 'mensalidade',             COUNT(*) FROM mensalidade
UNION ALL SELECT 'atraso_mensalidade',      COUNT(*) FROM atraso_mensalidade
UNION ALL SELECT 'pagamento',               COUNT(*) FROM pagamento
UNION ALL SELECT 'pagamento_a_vista',       COUNT(*) FROM pagamento_a_vista
UNION ALL SELECT 'pagamento_avista_mens',   COUNT(*) FROM pagamento_avista_mensalidade
UNION ALL SELECT 'conjuge_funcionario',     COUNT(*) FROM conjuge_funcionario;
