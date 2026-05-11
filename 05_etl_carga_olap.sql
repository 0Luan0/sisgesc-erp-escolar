-- ============================================================
-- SISGESC — ETL OLTP → OLAP
-- Estrategia: full reload (TRUNCATE + INSERT)
-- Idempotente: rodar N vezes produz o mesmo resultado
-- Ordem: dims primeiro, fato por ultimo (integridade referencial)
-- ============================================================

USE erp_escolar_olap;

-- ============================================================
-- STEP 0: limpar fato antes das dims (ordem inversa das FKs)
-- Regra: fatos que referenciam dims novas sao truncados antes dessas dims
-- ft_pagamento      → referencia dim_metodo_pagamento
-- ft_carga_docente  → referencia dim_professor
-- ft_inadimplencia  → referencia dim_tempo, dim_aluno, dim_curso (existentes)
-- ============================================================
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ft_pagamento;
TRUNCATE TABLE ft_carga_docente;
TRUNCATE TABLE ft_inadimplencia;
TRUNCATE TABLE ft_movimentacao_rh;
TRUNCATE TABLE ft_folha_rh;
TRUNCATE TABLE ft_desempenho_academico;
TRUNCATE TABLE ft_receita_mensalidade;
TRUNCATE TABLE dim_professor;
TRUNCATE TABLE dim_metodo_pagamento;
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
--   mensalidade (receita), folha_pagamentos (RH),
--   admissao/desligamento (movimentacao de pessoal),
--   data_pagamento (ft_pagamento usa mes do pagamento efetivo, nao do periodo)
--   -> garantia: todo SK_tempo referenciado em ft_pagamento existe nesta dim
-- ============================================================
-- dia_semana e nome_dia_semana: representam o 1o dia do mes YYYYMM
-- WEEKDAY() retorna 0=Segunda...6=Domingo; +1 converte para ISO: 1=Segunda...7=Domingo
INSERT INTO erp_escolar_olap.dim_tempo (SK_tempo, ano, mes, nome_mes, trimestre, semestre, dia_semana, nome_dia_semana)
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
         THEN 1 ELSE 2 END                                            AS semestre,
    WEEKDAY(STR_TO_DATE(CONCAT(LEFT(p.periodo_num,4),'-',
                               RIGHT(p.periodo_num,2),'-01'), '%Y-%m-%d')) + 1
                                                                      AS dia_semana,
    ELT(WEEKDAY(STR_TO_DATE(CONCAT(LEFT(p.periodo_num,4),'-',
                                   RIGHT(p.periodo_num,2),'-01'), '%Y-%m-%d')) + 1,
        'Segunda-Feira', 'Terca-Feira', 'Quarta-Feira',
        'Quinta-Feira',  'Sexta-Feira', 'Sabado', 'Domingo')          AS nome_dia_semana
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
    UNION
    -- datas efetivas de pagamento: mes do cashflow pode diferir do periodo da cobranca
    -- ex: mensalidade jul/2024 paga em ago/2024 → 202408 precisa existir na dim
    SELECT CAST(DATE_FORMAT(pg.data_pagamento, '%Y%m') AS UNSIGNED)
    FROM erp_escolar.pagamento pg
    WHERE pg.status = 'Pago'
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
-- STEP 8: dim_professor
-- Subconjunto de funcionarios com papel de professor (tabela professor no OLTP)
-- Carrega apenas professores ativos: turmas com professor inativo sao excluidas
-- do ft_carga_docente (comportamento esperado — professor inativo nao leciona)
-- ============================================================
INSERT INTO erp_escolar_olap.dim_professor
    (rgf, nome_completo, formacao, especialidade, nome_departamento, data_admissao)
SELECT
    f.rgf,
    CONCAT(f.nome, ' ', f.sobrenome)  AS nome_completo,
    p.formacao,
    p.especialidade,
    cg.nome_departamento,
    f.data_admissao
FROM erp_escolar.professor   p
JOIN erp_escolar.funcionario f  ON f.rgf          = p.fk_rgf
JOIN erp_escolar.cargo       cg ON cg.codigo_cargo = f.codigo_cargo
WHERE p.ativo = TRUE
ORDER BY f.rgf;

-- ============================================================
-- STEP 9: dim_metodo_pagamento
-- Vocabulario controlado carregado direto de metodo_pagamento (OLTP)
-- Garante que todo metodo existente no OLTP tenha um SK no OLAP
-- ============================================================
INSERT INTO erp_escolar_olap.dim_metodo_pagamento (nome_metodo)
SELECT metodo
FROM erp_escolar.metodo_pagamento
ORDER BY metodo;

-- ============================================================
-- STEP 10: ft_desempenho_academico
-- Grain: 1 linha por (matricula, turma) = aluno x materia x semestre
-- Subqueries pre-agregadas para evitar produto cartesiano entre
-- avaliacao/nota e frequencia quando ambas tem N linhas por turma
-- ============================================================
INSERT INTO erp_escolar_olap.ft_desempenho_academico
    (fk_SK_aluno, fk_SK_curso, fk_SK_materia, ano_letivo, semestre_letivo,
     turno, nota_final, total_aulas, total_presencas, percentual_presenca, status_turma)
SELECT
    da.SK_aluno,
    dc.SK_curso,
    dm.SK_materia,
    ca.ano,
    ca.semestre,
    t.turno,
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
-- STEP 11: ft_folha_rh
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
-- STEP 12: ft_movimentacao_rh
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
-- STEP 13: ft_inadimplencia
-- Grain: 1 linha por mensalidade com atraso registrado no OLTP
-- Fonte: atraso_mensalidade JOIN mensalidade JOIN contrato → matricula → aluno
-- valor_em_aberto: liquido da mensalidade menos o que ja foi pago ate o momento da carga
-- recuperado: flag 1/0 se a mensalidade ja foi quitada apos o atraso
-- Todos os periodos de atraso_mensalidade ja existem em dim_tempo (via mensalidade no STEP 1)
-- ============================================================
INSERT INTO erp_escolar_olap.ft_inadimplencia
    (fk_SK_tempo, fk_SK_aluno, fk_SK_curso, dias_atraso, valor_multa, valor_juros,
     valor_em_aberto, recuperado)
SELECT
    CAST(REPLACE(am.periodo, '-', '') AS UNSIGNED)                 AS fk_SK_tempo,
    da.SK_aluno,
    dc.SK_curso,
    am.dias_atraso,
    am.valor_multa,
    am.valor_juros,
    -- valor ainda nao recuperado: liquido da mensalidade menos o total pago confirmado
    (ms.valor_base - ms.valor_desconto) - COALESCE(pag.total_pago, 0.00) AS valor_em_aberto,
    CASE WHEN ms.status = 'Pago' THEN 1 ELSE 0 END                AS recuperado
FROM erp_escolar.atraso_mensalidade am
JOIN erp_escolar.mensalidade        ms  ON ms.fk_id_contrato = am.fk_id_contrato
                                       AND ms.periodo        = am.periodo
JOIN erp_escolar.contrato           ct  ON ct.pk_id_contrato = ms.fk_id_contrato
JOIN erp_escolar.matricula          m   ON m.pk_id_matricula = ct.fk_id_matricula
JOIN erp_escolar.aluno              a   ON a.rga             = m.fk_rga
JOIN erp_escolar_olap.dim_aluno     da  ON da.rga            = a.rga
JOIN erp_escolar_olap.dim_curso     dc  ON dc.codigo_curso   = m.fk_curso
-- pagamentos confirmados da mensalidade em atraso (LEFT JOIN: pode nao ter nenhum ainda)
LEFT JOIN (
    SELECT fk_id_contrato, periodo, SUM(valor_pago) AS total_pago
    FROM erp_escolar.pagamento
    WHERE status = 'Pago'
    GROUP BY fk_id_contrato, periodo
) pag ON pag.fk_id_contrato = am.fk_id_contrato
     AND pag.periodo        = am.periodo
ORDER BY am.periodo, a.rga;

-- ============================================================
-- STEP 14: ft_carga_docente
-- Grain: 1 linha por (professor, turma, semestre)
-- Agregacoes por turma: alunos, nota media, presenca media, aprovados, reprovados
-- turno: degenerate dim diretamente de turma.turno
-- Professores inativos (ativo=FALSE no OLTP) nao estao em dim_professor →
--   suas turmas sao silenciosamente excluidas (INNER JOIN intencional)
-- ============================================================
INSERT INTO erp_escolar_olap.ft_carga_docente
    (fk_SK_professor, fk_SK_curso, fk_SK_materia, ano_letivo, semestre_letivo,
     turno, qtd_alunos, nota_media_turma, presenca_media_pct, qtd_aprovados, qtd_reprovados)
SELECT
    dp.SK_professor,
    dc.SK_curso,
    dm.SK_materia,
    ca.ano,
    ca.semestre,
    t.turno,
    COUNT(DISTINCT mt.fk_id_matricula)                                       AS qtd_alunos,
    ROUND(AVG(notas.nota_final), 2)                                          AS nota_media_turma,
    CASE
        WHEN SUM(COALESCE(freq.total_aulas, 0)) > 0
        THEN ROUND(SUM(COALESCE(freq.total_presencas, 0)) * 100.0
                 / SUM(COALESCE(freq.total_aulas, 0)), 2)
        ELSE 0.00
    END                                                                      AS presenca_media_pct,
    SUM(CASE WHEN notas.nota_final >= 6                        THEN 1 ELSE 0 END) AS qtd_aprovados,
    SUM(CASE WHEN notas.nota_final < 6 AND notas.nota_final IS NOT NULL
                                                               THEN 1 ELSE 0 END) AS qtd_reprovados
FROM erp_escolar.turma                t
JOIN erp_escolar.calendario_academico ca  ON ca.pk_id_calendario = t.fk_id_calendario
JOIN erp_escolar.matricula_turma      mt  ON mt.fk_id_turma      = t.pk_id_turma
-- INNER JOIN: exclui turmas de professores inativos (nao estao em dim_professor)
JOIN erp_escolar_olap.dim_professor   dp  ON dp.rgf              = t.fk_rgf
JOIN erp_escolar_olap.dim_curso       dc  ON dc.codigo_curso     = t.fk_curso
JOIN erp_escolar_olap.dim_materia     dm  ON dm.codigo_materia   = t.fk_materia
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
GROUP BY dp.SK_professor, dc.SK_curso, dm.SK_materia, ca.ano, ca.semestre, t.turno
ORDER BY ca.ano, ca.semestre, dp.SK_professor;

-- ============================================================
-- STEP 15: ft_pagamento
-- Grain: 1 linha por registro efetivado na tabela pagamento do OLTP
-- fk_SK_tempo: mes do pagamento EFETIVO (cashflow), nao do periodo da cobranca
--   Ex: mensalidade 2024-07 paga em agosto → SK_tempo = 202408
--   Isso permite responder "quanto entrou no caixa em X?" sem afetar ft_receita
-- dim_tempo expandida no STEP 1 garante que 202408 exista antes deste INSERT
-- Apenas pagamentos com status = 'Pago' (cancelados sao excluidos)
-- pagamento_a_vista: fluxo alternativo, nao incluso (coberto por ft_receita_mensalidade)
-- ============================================================
INSERT INTO erp_escolar_olap.ft_pagamento
    (fk_SK_tempo, fk_SK_aluno, fk_SK_curso, fk_SK_metodo, valor_pago)
SELECT
    CAST(DATE_FORMAT(pg.data_pagamento, '%Y%m') AS UNSIGNED)  AS fk_SK_tempo,
    da.SK_aluno,
    dc.SK_curso,
    dmp.SK_metodo,
    pg.valor_pago
FROM erp_escolar.pagamento          pg
JOIN erp_escolar.mensalidade        ms  ON ms.fk_id_contrato = pg.fk_id_contrato
                                       AND ms.periodo        = pg.periodo
JOIN erp_escolar.contrato           ct  ON ct.pk_id_contrato = ms.fk_id_contrato
JOIN erp_escolar.matricula          m   ON m.pk_id_matricula = ct.fk_id_matricula
JOIN erp_escolar.aluno              a   ON a.rga             = m.fk_rga
JOIN erp_escolar_olap.dim_aluno     da  ON da.rga            = a.rga
JOIN erp_escolar_olap.dim_curso     dc  ON dc.codigo_curso   = m.fk_curso
JOIN erp_escolar_olap.dim_metodo_pagamento dmp
                                        ON dmp.nome_metodo   = pg.metodo
WHERE pg.status = 'Pago'
ORDER BY pg.data_pagamento, pg.pk_id_pagamento;

-- ============================================================
-- STEP 16: evidencia de carga OLAP
-- ============================================================
SELECT 'dim_tempo'                 AS tabela, COUNT(*) AS registros FROM dim_tempo
UNION ALL SELECT 'dim_aluno',                COUNT(*) FROM dim_aluno
UNION ALL SELECT 'dim_curso',                COUNT(*) FROM dim_curso
UNION ALL SELECT 'dim_unidade',              COUNT(*) FROM dim_unidade
UNION ALL SELECT 'dim_materia',              COUNT(*) FROM dim_materia
UNION ALL SELECT 'dim_funcionario',          COUNT(*) FROM dim_funcionario
UNION ALL SELECT 'dim_professor',            COUNT(*) FROM dim_professor
UNION ALL SELECT 'dim_metodo_pagamento',     COUNT(*) FROM dim_metodo_pagamento
UNION ALL SELECT 'ft_receita_mensalidade',   COUNT(*) FROM ft_receita_mensalidade
UNION ALL SELECT 'ft_desempenho_academico',  COUNT(*) FROM ft_desempenho_academico
UNION ALL SELECT 'ft_folha_rh',              COUNT(*) FROM ft_folha_rh
UNION ALL SELECT 'ft_movimentacao_rh',       COUNT(*) FROM ft_movimentacao_rh
UNION ALL SELECT 'ft_inadimplencia',         COUNT(*) FROM ft_inadimplencia
UNION ALL SELECT 'ft_carga_docente',         COUNT(*) FROM ft_carga_docente
UNION ALL SELECT 'ft_pagamento',             COUNT(*) FROM ft_pagamento;

-- ============================================================
-- STEP 17: validacao cruzada OLTP x OLAP
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
