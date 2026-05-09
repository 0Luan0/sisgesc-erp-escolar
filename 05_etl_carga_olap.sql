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
TRUNCATE TABLE ft_receita_mensalidade;
TRUNCATE TABLE dim_tempo;
TRUNCATE TABLE dim_aluno;
TRUNCATE TABLE dim_curso;
TRUNCATE TABLE dim_unidade;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- STEP 1: dim_tempo
-- Gera 1 linha por periodo YYYYMM presente nas mensalidades OLTP
-- ============================================================
INSERT INTO erp_escolar_olap.dim_tempo (pk_id_tempo, ano, mes, nome_mes, trimestre, semestre)
SELECT DISTINCT
    CAST(REPLACE(ms.periodo, '-', '') AS UNSIGNED)  AS pk_id_tempo,
    CAST(LEFT(ms.periodo, 4) AS UNSIGNED)            AS ano,
    CAST(RIGHT(ms.periodo, 2) AS UNSIGNED)           AS mes,
    ELT(CAST(RIGHT(ms.periodo, 2) AS UNSIGNED),
        'Janeiro', 'Fevereiro', 'Marco', 'Abril',
        'Maio', 'Junho', 'Julho', 'Agosto',
        'Setembro', 'Outubro', 'Novembro', 'Dezembro') AS nome_mes,
    CEIL(CAST(RIGHT(ms.periodo, 2) AS UNSIGNED) / 3.0) AS trimestre,
    CASE
        WHEN CAST(RIGHT(ms.periodo, 2) AS UNSIGNED) <= 6 THEN 1
        ELSE 2
    END                                              AS semestre
FROM erp_escolar.mensalidade ms
ORDER BY pk_id_tempo;

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
    (fk_id_tempo, fk_id_aluno, fk_id_curso, fk_id_unidade,
     valor_base, valor_desconto, valor_liquido, valor_pago,
     status_mensalidade, tem_bolsa)
SELECT
    -- dim_tempo: chave YYYYMM
    CAST(REPLACE(ms.periodo, '-', '') AS UNSIGNED)            AS fk_id_tempo,

    -- dim_aluno: surrogate via lookup
    da.pk_id_aluno                                            AS fk_id_aluno,

    -- dim_curso: surrogate via lookup
    dc.pk_id_curso                                            AS fk_id_curso,

    -- dim_unidade: derivada do curso (nao existe FK direta no OLTP)
    du.pk_id_unidade                                          AS fk_id_unidade,

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
-- STEP 6: evidencia de carga OLAP
-- ============================================================
SELECT 'dim_tempo'              AS tabela, COUNT(*) AS registros FROM dim_tempo
UNION ALL SELECT 'dim_aluno',             COUNT(*) FROM dim_aluno
UNION ALL SELECT 'dim_curso',             COUNT(*) FROM dim_curso
UNION ALL SELECT 'dim_unidade',           COUNT(*) FROM dim_unidade
UNION ALL SELECT 'ft_receita_mensalidade',COUNT(*) FROM ft_receita_mensalidade;

-- ============================================================
-- STEP 7: validacao cruzada OLTP x OLAP
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
