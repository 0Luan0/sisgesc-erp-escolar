-- ============================================================
-- SISGESC — Consultas OLTP
-- Fase 3: SELECTs simples + subselects com agregacao e correlacao
-- Executar apos 01_ddl_estrutura.sql e 02_dml_carga.sql
-- ============================================================

USE erp_escolar;

-- ============================================================
-- BLOCO 1: SELECTs simples
-- ============================================================

-- Q01: Alunos ativos com curso e ano de ingresso
SELECT
    a.rga,
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    c.nome_curso,
    m.ano_ingresso,
    m.status AS status_matricula
FROM aluno a
JOIN matricula m ON m.fk_rga = a.rga
JOIN curso   c ON c.codigo_curso = m.fk_curso
WHERE a.status = 'Ativo'
ORDER BY c.nome_curso, a.sobrenome;

-- Q02: Funcionarios ativos com cargo, departamento e salario
SELECT
    f.rgf,
    CONCAT(f.nome, ' ', f.sobrenome) AS funcionario,
    cg.nome_cargo,
    cg.nome_departamento,
    cg.nivel,
    hs.salario AS salario_atual
FROM funcionario f
JOIN cargo            cg ON cg.codigo_cargo = f.codigo_cargo
JOIN historico_salario hs ON hs.fk_rgf = f.rgf AND hs.data_fim IS NULL
WHERE f.status = 'Ativo'
ORDER BY cg.nome_departamento, f.sobrenome;

-- Q03: Turmas do semestre 2024/1 com professor, materia e turno
SELECT
    t.pk_id_turma                          AS id_turma,
    c.nome_curso,
    mat.nome_materia,
    CONCAT(f.nome, ' ', f.sobrenome)       AS professor,
    t.turno,
    t.limite_alunos,
    ca.ano,
    ca.semestre
FROM turma t
JOIN curso               c   ON c.codigo_curso  = t.fk_curso
JOIN materia             mat ON mat.codigo_materia = t.fk_materia
JOIN funcionario         f   ON f.rgf            = t.fk_rgf
JOIN calendario_academico ca  ON ca.pk_id_calendario = t.fk_id_calendario
WHERE ca.ano = 2024 AND ca.semestre = 1
ORDER BY c.nome_curso, mat.nome_materia;

-- Q04: Mensalidades pendentes ou atrasadas — inadimplencia atual
SELECT
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    c.nome_curso,
    ms.periodo,
    ms.valor_base - ms.valor_desconto AS valor_liquido,
    ms.data_vencimento,
    ms.status
FROM mensalidade ms
JOIN contrato    ct ON ct.pk_id_contrato = ms.fk_id_contrato
JOIN matricula   m  ON m.pk_id_matricula = ct.fk_id_matricula
JOIN aluno       a  ON a.rga             = m.fk_rga
JOIN curso       c  ON c.codigo_curso    = m.fk_curso
WHERE ms.status IN ('Pendente', 'Atrasado')
ORDER BY ms.status DESC, ms.data_vencimento;

-- ============================================================
-- BLOCO 2: Subselects com agregacao
-- ============================================================

-- Q05: Total pago por aluno no ano de 2024 (soma de pagamentos confirmados)
SELECT
    CONCAT(a.nome, ' ', a.sobrenome)     AS aluno,
    c.nome_curso,
    COUNT(p.pk_id_pagamento)             AS parcelas_pagas,
    SUM(p.valor_pago)                    AS total_pago_2024
FROM aluno     a
JOIN matricula  m  ON m.fk_rga          = a.rga
JOIN contrato   ct ON ct.fk_id_matricula = m.pk_id_matricula
JOIN pagamento  p  ON p.fk_id_contrato   = ct.pk_id_contrato
JOIN curso      c  ON c.codigo_curso     = m.fk_curso
WHERE p.status = 'Pago'
  AND YEAR(p.data_pagamento) = 2024
GROUP BY a.rga, c.codigo_curso
ORDER BY total_pago_2024 DESC;

-- Q06: Nota final por aluno por turma (media ponderada via view)
-- vw_nota_final ja calcula SUM(nota*peso)/SUM(peso)
SELECT
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    mat.nome_materia,
    ROUND(nf.nota_final, 2)          AS nota_final,
    CASE
        WHEN nf.nota_final >= 7.0 THEN 'Aprovado'
        WHEN nf.nota_final >= 5.0 THEN 'Recuperacao'
        ELSE 'Reprovado'
    END AS situacao
FROM vw_nota_final nf
JOIN matricula  m   ON m.pk_id_matricula = nf.fk_id_matricula
JOIN aluno      a   ON a.rga             = m.fk_rga
JOIN turma      t   ON t.pk_id_turma     = nf.fk_id_turma
JOIN materia    mat ON mat.codigo_materia = t.fk_materia
ORDER BY mat.nome_materia, nota_final DESC;

-- Q07: Quantidade de alunos matriculados por curso
SELECT
    c.codigo_curso,
    c.nome_curso,
    c.nivel_ensino,
    COUNT(m.pk_id_matricula) AS total_matriculas,
    SUM(CASE WHEN m.status = 'Cursando' THEN 1 ELSE 0 END) AS cursando_atualmente
FROM curso c
LEFT JOIN matricula m ON m.fk_curso = c.codigo_curso
WHERE c.ativo = TRUE
GROUP BY c.codigo_curso
ORDER BY total_matriculas DESC;

-- Q08: Funcionarios com salario acima da media geral de salarios ativos
SELECT
    CONCAT(f.nome, ' ', f.sobrenome) AS funcionario,
    cg.nome_cargo,
    hs.salario,
    ROUND(media.media_geral, 2)      AS media_geral
FROM funcionario f
JOIN cargo             cg  ON cg.codigo_cargo = f.codigo_cargo
JOIN historico_salario hs  ON hs.fk_rgf = f.rgf AND hs.data_fim IS NULL
JOIN (
    SELECT AVG(salario) AS media_geral
    FROM historico_salario
    WHERE data_fim IS NULL
) media ON hs.salario > media.media_geral
WHERE f.status = 'Ativo'
ORDER BY hs.salario DESC;

-- ============================================================
-- BLOCO 3: Subselects correlacionados
-- ============================================================

-- Q09: Alunos com percentual de presenca abaixo de 75% em alguma turma
-- 75% e o minimo legal de frequencia (RN-15 do sistema)
SELECT
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    mat.nome_materia,
    COUNT(fr.data_aula)                                           AS total_aulas,
    SUM(CASE WHEN fr.presente = TRUE THEN 1 ELSE 0 END)          AS presencas,
    ROUND(
        SUM(CASE WHEN fr.presente = TRUE THEN 1 ELSE 0 END)
        / COUNT(fr.data_aula) * 100, 1
    )                                                             AS pct_frequencia
FROM frequencia     fr
JOIN matricula_turma mt  ON mt.fk_id_matricula = fr.fk_id_matricula
                        AND mt.fk_id_turma     = fr.fk_id_turma
JOIN matricula       m   ON m.pk_id_matricula  = fr.fk_id_matricula
JOIN aluno           a   ON a.rga              = m.fk_rga
JOIN turma           t   ON t.pk_id_turma      = fr.fk_id_turma
JOIN materia         mat ON mat.codigo_materia  = t.fk_materia
GROUP BY fr.fk_id_matricula, fr.fk_id_turma
HAVING pct_frequencia < 75
ORDER BY pct_frequencia ASC;

-- Q10: Cursos cuja receita mensal media supera a media geral de todos os cursos
-- subselect correlacionado: compara cada curso com o conjunto todo
SELECT
    c.nome_curso,
    ROUND(AVG(ms.valor_base - ms.valor_desconto), 2) AS receita_media_mensal
FROM curso    c
JOIN matricula m  ON m.fk_curso       = c.codigo_curso
JOIN contrato  ct ON ct.fk_id_matricula = m.pk_id_matricula
JOIN mensalidade ms ON ms.fk_id_contrato = ct.pk_id_contrato
WHERE ms.status = 'Pago'
GROUP BY c.codigo_curso
HAVING receita_media_mensal > (
    SELECT AVG(valor_base - valor_desconto)
    FROM mensalidade
    WHERE status = 'Pago'
)
ORDER BY receita_media_mensal DESC;

-- Q11: Professores que ministram mais de uma materia no semestre 2024/1
SELECT
    CONCAT(f.nome, ' ', f.sobrenome) AS professor,
    COUNT(DISTINCT t.fk_materia)     AS qtd_materias,
    GROUP_CONCAT(mat.nome_materia ORDER BY mat.nome_materia SEPARATOR ', ') AS materias
FROM turma t
JOIN funcionario f   ON f.rgf             = t.fk_rgf
JOIN materia     mat ON mat.codigo_materia = t.fk_materia
JOIN calendario_academico ca ON ca.pk_id_calendario = t.fk_id_calendario
WHERE ca.ano = 2024 AND ca.semestre = 1
GROUP BY t.fk_rgf
HAVING qtd_materias > 1
ORDER BY qtd_materias DESC;

-- Q12: Consistencia financeira — soma de pagamentos bate com mensalidades Pagas por contrato
-- verifica se o total pago = SUM(valor_base - valor_desconto) das mensalidades quitadas
SELECT
    ct.pk_id_contrato                                   AS contrato,
    CONCAT(a.nome, ' ', a.sobrenome)                    AS aluno,
    SUM(ms.valor_base - ms.valor_desconto)              AS soma_mensalidades_pagas,
    (
        SELECT COALESCE(SUM(p2.valor_pago), 0)
        FROM pagamento p2
        WHERE p2.fk_id_contrato = ct.pk_id_contrato
          AND p2.status = 'Pago'
    )                                                   AS soma_pagamentos_registrados,
    SUM(ms.valor_base - ms.valor_desconto)
        - (
            SELECT COALESCE(SUM(p2.valor_pago), 0)
            FROM pagamento p2
            WHERE p2.fk_id_contrato = ct.pk_id_contrato
              AND p2.status = 'Pago'
          )                                             AS diferenca
FROM contrato  ct
JOIN mensalidade ms ON ms.fk_id_contrato  = ct.pk_id_contrato
JOIN matricula   m  ON m.pk_id_matricula  = ct.fk_id_matricula
JOIN aluno       a  ON a.rga              = m.fk_rga
WHERE ms.status = 'Pago'
GROUP BY ct.pk_id_contrato
ORDER BY diferenca DESC;

-- ============================================================
-- BLOCO 4: Controle Transacional (ACID)
-- Principio ACID:
--   Atomicidade  — ou executa tudo, ou nao executa nada
--   Consistencia — o banco permanece integro antes e apos
--   Isolamento   — transacoes concorrentes nao se interferem
--   Durabilidade — apos COMMIT, o dado e permanente
-- ============================================================

-- ----------------------------------------------------------
-- Cenario 1: ROLLBACK — desfazendo uma operacao com erro
-- Simula tentativa de cadastro que precisa ser desfeita
-- ----------------------------------------------------------

SELECT COUNT(*) AS total_alunos_antes FROM aluno;

START TRANSACTION;

INSERT INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES ('A0000001', '99999999901', 'Aluno', 'Rollback', '2000-01-01', 'Ativo');

-- erro detectado antes do commit (ex: CPF invalido na validacao da aplicacao)
ROLLBACK;

-- validacao: registro NAO deve existir apos ROLLBACK
SELECT COUNT(*) AS total_alunos_apos_rollback FROM aluno;
-- resultado esperado: mesmo valor do total_alunos_antes

SELECT rga FROM aluno WHERE rga = 'A0000001';
-- resultado esperado: 0 linhas — atomicidade garantida

-- ----------------------------------------------------------
-- Cenario 2: COMMIT — confirmando uma operacao valida
-- Mesmo INSERT, agora confirmado com COMMIT
-- ----------------------------------------------------------

START TRANSACTION;

INSERT INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES ('A0000001', '99999999901', 'Aluno', 'Commit', '2000-01-01', 'Ativo');

COMMIT;

-- validacao: registro DEVE existir apos COMMIT
SELECT rga, nome, sobrenome, status
FROM aluno
WHERE rga = 'A0000001';
-- resultado esperado: 1 linha — durabilidade confirmada

-- limpeza do registro de teste
DELETE FROM aluno WHERE rga = 'A0000001';

-- ----------------------------------------------------------
-- Cenario 3 (diferencial): Transacao com multiplas operacoes
-- Simula matricula atomica: aluno + matricula devem ser inseparaveis
-- Se um INSERT falhar, o outro tambem deve ser desfeito
-- ----------------------------------------------------------

START TRANSACTION;

INSERT INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES ('A0000099', '88888888801', 'Novo', 'Aluno', '2001-06-15', 'Ativo');

INSERT INTO matricula (fk_rga, fk_curso, data_matricula, status, ano_ingresso)
VALUES ('A0000099', 'ADS', CURDATE(), 'Cursando', 2024);

-- simulando deteccao de inconsistencia antes do commit
-- (ex: documentacao pendente, regra de negocio violada)
ROLLBACK;

-- validacao: nenhuma das duas operacoes deve ter persistido
SELECT rga  FROM aluno    WHERE rga    = 'A0000099';  -- esperado: 0 linhas
SELECT fk_rga FROM matricula WHERE fk_rga = 'A0000099';  -- esperado: 0 linhas
-- conclusao: atomicidade garante que aluno nunca existe sem matricula
