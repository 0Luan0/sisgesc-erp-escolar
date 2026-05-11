-- ============================================================
-- SISGESC — ETL OLTP → OLAP
-- Estrategia: full reload (TRUNCATE + INSERT)
-- Idempotente: rodar N vezes produz o mesmo resultado
-- Ordem: dims primeiro, fato por ultimo (integridade referencial)
-- ============================================================

USE erp_escolar_olap;

-- ============================================================
-- STEP 0: limpar fato antes das dims (ordem inversa das FKs)
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ft_movimentacao_rh;
TRUNCATE TABLE ft_folha_rh;
TRUNCATE TABLE ft_desempenho_academico;
TRUNCATE TABLE ft_receita_mensalidade;
TRUNCATE TABLE dim_funcionario;
TRUNCATE TABLE dim_materia;
TRUNCATE TABLE dim_tempo;
TRUNCATE TABLE dim_aluno;
TRUNCATE TABLE dim_curso;
TRUNCATE TABLE dim_unidade;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STEP 1: dim_tempo
-- Gera 1 linha por periodo YYYYMM presente em todas as fontes:
--   mensalidade (receita), folha_pagamentos (RH) e datas de
--   admissao/desligamento (movimentacao de pessoal)
-- ============================================================
INSERT INTO erp_escolar_olap.dim_tempo (SK_tempo, ano, mes, nome_mes, trimestre, semestre)
SELECT DISTINCT
    p.periodo_num                                                     AS SK_tempo,
    CAST(LEFT(p.periodo_num, 4) AS UNSIGNED)                          AS ano,
    CAST(RIGHT(p.periodo_num, 2) AS UNSIGNED)                         AS mes,
    ELT(CAST(RIGHT(p.periodo_num, 2) AS UNSIGNED),
        'Janeiro', 'Fevereiro', 'Marco', 'Abril',
        'Maio', 'Junho', 'Julho', 'Agosto',
        'Setembro', 'Outubro', 'Novembro', 'Dezembro')                AS nome_mes,
    CEIL(CAST(RIGHT(p.periodo_num, 2) AS UNSIGNED) / 3.0)             AS trimestre,
    CASE WHEN CAST(RIGHT(p.periodo_num, 2) AS UNSIGNED) <= 6
         THEN 1 ELSE 2 END                                            AS semestre
FROM (
    SELECT CAST(REPLACE(ms.periodo, '-', '') AS UNSIGNED) AS periodo_num
    FROM erp_escolar.mensalidade ms
    UNION
    SELECT CAST(REPLACE(fp.periodo, '-', '') AS UNSIGNED)
    FROM erp_escolar.folha_pagamentos fp
    UNION
    SELECT CAST(DATE_FORMAT(f.data_admissao, '%Y%m') AS UNSIGNED)
    FROM erp_escolar.funcionario f
    UNION
    SELECT CAST(DATE_FORMAT(f.data_desligamento, '%Y%m') AS UNSIGNED)
    FROM erp_escolar.funcionario f
    WHERE f.data_desligamento IS NOT NULL
) p
ORDER BY p.periodo_num;

-- ============================================================
-- STEP 2: dim_unidade
-- Agrupamento de cursos por area academica (nao existe no OLTP)
-- Mapeamento fixo: curso → unidade academica
-- ============================================================
INSERT INTO erp_escolar_olap.dim_unidade (nome_unidade) VALUES
    ('Tecnologia da Informacao'),
    ('Ciencias da Saude'),
    ('Gestao e Negocios');

-- ============================================================
-- STEP 3: dim_curso
-- ============================================================
INSERT INTO erp_escolar_olap.dim_curso (codigo_curso, nome_curso, nivel_ensino)
SELECT c.codigo_curso, c.nome_curso, c.nivel_ensino
FROM erp_escolar.curso c
WHERE c.ativo = TRUE
ORDER BY c.codigo_curso;

-- ============================================================
-- STEP 4: dim_aluno
-- Snapshot: captura nome e curso no momento da matricula ativa
-- ============================================================
INSERT INTO erp_escolar_olap.dim_aluno (rga, nome_completo, ano_ingresso, curso_ingresso)
SELECT
    a.rga,
    CONCAT(a.nome, ' ', a.sobrenome),
    m.ano_ingresso,
    m.fk_curso
FROM erp_escolar.aluno     a
JOIN erp_escolar.matricula m ON m.fk_rga = a.rga
WHERE m.status = 'Cursando'
ORDER BY a.rga;

-- ============================================================
-- STEP 5: ft_receita_mensalidade
-- Grain: 1 linha por mensalidade
-- Join com pagamento: LEFT JOIN para manter mensalidades nao pagas (valor_pago = 0)
-- dim_unidade: mapeamento curso → area via CASE
-- ============================================================
INSERT INTO erp_escolar_olap.ft_receita_mensalidade
    (fk_SK_tempo, fk_SK_aluno, fk_SK_curso, fk_SK_unidade,
     valor_base, valor_desconto, valor_liquido, valor_pago,
     status_mensalidade, tem_bolsa)
SELECT
    -- dim_tempo: chave YYYYMM
    CAST(REPLACE(ms.periodo, '-', '') AS UNSIGNED)            AS fk_SK_tempo,

    -- dim_aluno: surrogate via lookup
    da.SK_aluno                                            AS fk_SK_aluno,

    -- dim_curso: surrogate via lookup
    dc.SK_curso                                            AS fk_SK_curso,

    -- dim_unidade: derivada do curso (nao existe FK direta no OLTP)
    du.SK_unidade                                          AS fk_SK_unidade,

    -- metricas
    ms.valor_base,
    ms.valor_desconto,
    ms.valor_base - ms.valor_desconto                         AS valor_liquido,
    COALESCE(p.valor_pago, 0.00)                              AS valor_pago,

    -- degenerate dimensions
    ms.status                                                 AS status_mensalidade,
    CASE WHEN ms.valor_desconto > 0 THEN 1 ELSE 0 END         AS tem_bolsa

FROM erp_escolar.mensalidade  ms
JOIN erp_escolar.contrato     ct  ON ct.pk_id_contrato  = ms.fk_id_contrato
JOIN erp_escolar.matricula    m   ON m.pk_id_matricula  = ct.fk_id_matricula
JOIN erp_escolar.aluno        a   ON a.rga              = m.fk_rga

-- lookup dims
JOIN erp_escolar_olap.dim_aluno  da  ON da.rga          = a.rga
JOIN erp_escolar_olap.dim_curso  dc  ON dc.codigo_curso = m.fk_curso
JOIN erp_escolar_olap.dim_unidade du ON du.nome_unidade = CASE m.fk_curso
    WHEN 'ADS' THEN 'Tecnologia da Informacao'
    WHEN 'ENF' THEN 'Ciencias da Saude'
    WHEN 'LOG' THEN 'Gestao e Negocios'
    END

-- pagamento efetivo: LEFT JOIN com subquery agregada para suportar pagamentos parcelados
-- sem o GROUP BY, multiplos pagamentos no mesmo periodo geram linhas duplicadas na fato
LEFT JOIN (
    SELECT fk_id_contrato, periodo, SUM(valor_pago) AS valor_pago
    FROM erp_escolar.pagamento
    WHERE status = 'Pago'
    GROUP BY fk_id_contrato, periodo
) p ON p.fk_id_contrato = ms.fk_id_contrato
   AND p.periodo        = ms.periodo
ORDER BY ms.periodo, a.rga;

-- ============================================================
-- STEP 6: dim_materia
-- ============================================================
INSERT INTO erp_escolar_olap.dim_materia (codigo_materia, nome_materia, carga_horaria)
SELECT codigo_materia, nome_materia, carga_horaria
FROM erp_escolar.materia
WHERE ativo = TRUE
ORDER BY codigo_materia;

-- ============================================================
-- STEP 7: dim_funcionario
-- Snapshot: nome e cargo no momento da carga
-- ============================================================
INSERT INTO erp_escolar_olap.dim_funcionario
    (rgf, nome_completo, codigo_cargo, nome_cargo, nome_departamento, nivel_cargo, data_admissao)
SELECT
    f.rgf,
    CONCAT(f.nome, ' ', f.sobrenome),
    f.codigo_cargo,
    cg.nome_cargo,
    cg.nome_departamento,
    cg.nivel,
    f.data_admissao
FROM erp_escolar.funcionario f
JOIN erp_escolar.cargo cg ON cg.codigo_cargo = f.codigo_cargo
ORDER BY f.rgf;

-- ============================================================
-- STEP 8: ft_desempenho_academico
-- Grain: 1 linha por (matricula, turma) = aluno x materia x semestre
-- Subqueries pre-agregadas para evitar produto cartesiano entre
-- avaliacao/nota e frequencia quando ambas tem N linhas por turma
-- ============================================================
INSERT INTO erp_escolar_olap.ft_desempenho_academico
    (fk_SK_aluno, fk_SK_curso, fk_SK_materia, ano_letivo, semestre_letivo,
     nota_final, total_aulas, total_presencas, percentual_presenca, status_turma)
SELECT
    da.SK_aluno,
    dc.SK_curso,
    dm.SK_materia,
    ca.ano,
    ca.semestre,
    notas.nota_final,
    COALESCE(freq.total_aulas, 0)      AS total_aulas,
    COALESCE(freq.total_presencas, 0)  AS total_presencas,
    CASE
        WHEN COALESCE(freq.total_aulas, 0) > 0
        THEN ROUND(COALESCE(freq.total_presencas, 0) * 100.0 / freq.total_aulas, 2)
        ELSE 0.00
    END                                AS percentual_presenca,
    mt.status                          AS status_turma
FROM erp_escolar.matricula_turma         mt
JOIN erp_escolar.turma                   t   ON t.pk_id_turma       = mt.fk_id_turma
JOIN erp_escolar.matricula               m   ON m.pk_id_matricula   = mt.fk_id_matricula
JOIN erp_escolar.aluno                   a   ON a.rga               = m.fk_rga
JOIN erp_escolar.calendario_academico    ca  ON ca.pk_id_calendario = t.fk_id_calendario
JOIN erp_escolar_olap.dim_aluno          da  ON da.rga              = a.rga
JOIN erp_escolar_olap.dim_curso          dc  ON dc.codigo_curso     = m.fk_curso
JOIN erp_escolar_olap.dim_materia        dm  ON dm.codigo_materia   = t.fk_materia
-- nota final ponderada pre-agregada por (matricula, turma)
LEFT JOIN (
    SELECT
        n.fk_id_matricula,
        av.fk_id_turma,
        ROUND(SUM(n.nota_atividade * av.peso) / NULLIF(SUM(av.peso), 0), 2) AS nota_final
    FROM erp_escolar.nota      n
    JOIN erp_escolar.avaliacao av ON av.pk_id_avaliacao = n.fk_id_avaliacao
    GROUP BY n.fk_id_matricula, av.fk_id_turma
) notas ON notas.fk_id_matricula = mt.fk_id_matricula
       AND notas.fk_id_turma     = mt.fk_id_turma
-- frequencia pre-agregada por (matricula, turma)
LEFT JOIN (
    SELECT
        fk_id_matricula,
        fk_id_turma,
        COUNT(*)                                          AS total_aulas,
        SUM(CASE WHEN presente = TRUE THEN 1 ELSE 0 END) AS total_presencas
    FROM erp_escolar.frequencia
    GROUP BY fk_id_matricula, fk_id_turma
) freq ON freq.fk_id_matricula = mt.fk_id_matricula
      AND freq.fk_id_turma     = mt.fk_id_turma
ORDER BY ca.ano, ca.semestre, da.SK_aluno;

-- ============================================================
-- STEP 9: ft_folha_rh
-- Grain: 1 linha por (funcionario, periodo mensal)
-- salario_liquido = bruto + proventos - descontos (snapshot OLAP)
-- ============================================================
INSERT INTO erp_escolar_olap.ft_folha_rh
    (fk_SK_funcionario, fk_SK_tempo, salario_bruto,
     total_proventos, total_descontos, salario_liquido, status_folha)
SELECT
    df.SK_funcionario,
    CAST(REPLACE(fp.periodo, '-', '') AS UNSIGNED)                                          AS fk_SK_tempo,
    fp.salario_bruto,
    COALESCE(SUM(CASE WHEN ef.tipo = 'Provento' THEN fe.valor ELSE 0 END), 0)              AS total_proventos,
    COALESCE(SUM(CASE WHEN ef.tipo = 'Desconto' THEN fe.valor ELSE 0 END), 0)              AS total_descontos,
    fp.salario_bruto
        + COALESCE(SUM(CASE WHEN ef.tipo = 'Provento' THEN fe.valor ELSE 0 END), 0)
        - COALESCE(SUM(CASE WHEN ef.tipo = 'Desconto' THEN fe.valor ELSE 0 END), 0)       AS salario_liquido,
    fp.status
FROM erp_escolar.folha_pagamentos                fp
JOIN erp_escolar_olap.dim_funcionario            df  ON df.rgf        = fp.fk_rgf
LEFT JOIN erp_escolar.folha_evento               fe  ON fe.fk_rgf     = fp.fk_rgf
                                                    AND fe.periodo    = fp.periodo
LEFT JOIN erp_escolar.evento_folha               ef  ON ef.nome_evento = fe.nome_evento
GROUP BY df.SK_funcionario, fp.fk_rgf, fp.periodo, fp.salario_bruto, fp.status
ORDER BY fp.periodo, fp.fk_rgf;

-- ============================================================
-- STEP 10: ft_movimentacao_rh
-- Grain: 1 linha por evento de admissao ou desligamento
-- Permite calculo de headcount, tempo medio de empresa, turnover
-- ============================================================
INSERT INTO erp_escolar_olap.ft_movimentacao_rh
    (fk_SK_funcionario, fk_SK_tempo, tipo_movimentacao, dias_empresa, data_evento)
SELECT
    df.SK_funcionario,
    CAST(DATE_FORMAT(f.data_admissao, '%Y%m') AS UNSIGNED) AS fk_SK_tempo,
    'Admissao'                                             AS tipo_movimentacao,
    0                                                      AS dias_empresa,
    f.data_admissao                                        AS data_evento
FROM erp_escolar.funcionario          f
JOIN erp_escolar_olap.dim_funcionario df ON df.rgf = f.rgf

UNION ALL

SELECT
    df.SK_funcionario,
    CAST(DATE_FORMAT(f.data_desligamento, '%Y%m') AS UNSIGNED) AS fk_SK_tempo,
    'Desligamento'                                              AS tipo_movimentacao,
    DATEDIFF(f.data_desligamento, f.data_admissao)              AS dias_empresa,
    f.data_desligamento                                         AS data_evento
FROM erp_escolar.funcionario          f
JOIN erp_escolar_olap.dim_funcionario df ON df.rgf = f.rgf
WHERE f.data_desligamento IS NOT NULL
ORDER BY data_evento;

-- ============================================================
-- STEP 11: evidencia de carga OLAP
-- ============================================================
SELECT 'dim_tempo'                 AS tabela, COUNT(*) AS registros FROM dim_tempo
UNION ALL SELECT 'dim_aluno',                COUNT(*) FROM dim_aluno
UNION ALL SELECT 'dim_curso',                COUNT(*) FROM dim_curso
UNION ALL SELECT 'dim_unidade',              COUNT(*) FROM dim_unidade
UNION ALL SELECT 'dim_materia',              COUNT(*) FROM dim_materia
UNION ALL SELECT 'dim_funcionario',          COUNT(*) FROM dim_funcionario
UNION ALL SELECT 'ft_receita_mensalidade',   COUNT(*) FROM ft_receita_mensalidade
UNION ALL SELECT 'ft_desempenho_academico',  COUNT(*) FROM ft_desempenho_academico
UNION ALL SELECT 'ft_folha_rh',              COUNT(*) FROM ft_folha_rh
UNION ALL SELECT 'ft_movimentacao_rh',       COUNT(*) FROM ft_movimentacao_rh;

-- ============================================================
-- STEP 12: validacao cruzada OLTP x OLAP
-- SUM(valor_pago) deve ser identico nos dois bancos
-- Esta consulta deve retornar diferenca = 0.00 em todas as linhas
-- ============================================================
SELECT
    'OLTP' AS origem,
    COUNT(*)        AS total_registros,
    SUM(COALESCE(p.valor_pago, 0)) AS soma_valor_pago
FROM erp_escolar.mensalidade ms
JOIN erp_escolar.contrato  ct ON ct.pk_id_contrato = ms.fk_id_contrato
LEFT JOIN (
    SELECT fk_id_contrato, periodo, SUM(valor_pago) AS valor_pago
    FROM erp_escolar.pagamento
    WHERE status = 'Pago'
    GROUP BY fk_id_contrato, periodo
) p ON p.fk_id_contrato = ms.fk_id_contrato
   AND p.periodo        = ms.periodo

UNION ALL

SELECT
    'OLAP' AS origem,
    COUNT(*)         AS total_registros,
    SUM(valor_pago)  AS soma_valor_pago
FROM erp_escolar_olap.ft_receita_mensalidade;
