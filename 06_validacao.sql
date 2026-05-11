-- ============================================================
-- SISGESC — Validacao, Indices e Performance
-- Fase 6: prova SUM OLTP = SUM OLAP + indices estrategicos
-- Executar apos 05_etl_carga_olap.sql
-- ============================================================

-- ============================================================
-- PARTE 1: VALIDACAO FINANCEIRA — SUM OLTP = SUM OLAP
-- Tres niveis de granularidade: total, por periodo, por curso
-- Qualquer diferenca != 0 indica erro no ETL
-- ============================================================

-- 1A: Validacao global (linha unica, diferenca deve ser 0.00)
SELECT
    oltp.soma_oltp,
    olap.soma_olap,
    oltp.soma_oltp - olap.soma_olap AS diferenca,
    oltp.total_registros            AS registros_oltp,
    olap.total_registros            AS registros_olap
FROM (
    SELECT
        COUNT(*)                       AS total_registros,
        SUM(COALESCE(p.valor_pago, 0)) AS soma_oltp
    FROM erp_escolar.mensalidade ms
    JOIN erp_escolar.contrato ct ON ct.pk_id_contrato = ms.fk_id_contrato
    LEFT JOIN (
        SELECT fk_id_contrato, periodo, SUM(valor_pago) AS valor_pago
        FROM erp_escolar.pagamento
        WHERE status = 'Pago'
        GROUP BY fk_id_contrato, periodo
    ) p ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
) oltp
JOIN (
    SELECT
        COUNT(*)       AS total_registros,
        SUM(valor_pago) AS soma_olap
    FROM erp_escolar_olap.ft_receita_mensalidade
) olap ON TRUE;

-- 1B: Validacao por periodo (cada linha deve ter diferenca = 0.00)
SELECT
    oltp.periodo,
    oltp.soma_oltp,
    olap.soma_olap,
    oltp.soma_oltp - olap.soma_olap AS diferenca
FROM (
    SELECT
        ms.periodo,
        SUM(COALESCE(p.valor_pago, 0)) AS soma_oltp
    FROM erp_escolar.mensalidade ms
    JOIN erp_escolar.contrato ct ON ct.pk_id_contrato = ms.fk_id_contrato
    LEFT JOIN (
        SELECT fk_id_contrato, periodo, SUM(valor_pago) AS valor_pago
        FROM erp_escolar.pagamento
        WHERE status = 'Pago'
        GROUP BY fk_id_contrato, periodo
    ) p ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
    GROUP BY ms.periodo
) oltp
JOIN (
    SELECT
        dt.ano * 100 + dt.mes                     AS periodo_num,
        CONCAT(dt.ano, '-', LPAD(dt.mes, 2, '0')) AS periodo,
        SUM(ft.valor_pago)                         AS soma_olap
    FROM erp_escolar_olap.ft_receita_mensalidade ft
    JOIN erp_escolar_olap.dim_tempo dt ON dt.SK_tempo = ft.fk_SK_tempo
    GROUP BY dt.SK_tempo
) olap ON oltp.periodo = olap.periodo
ORDER BY oltp.periodo;

-- 1C: Validacao por curso (cada linha deve ter diferenca = 0.00)
SELECT
    oltp.codigo_curso,
    oltp.soma_oltp,
    olap.soma_olap,
    oltp.soma_oltp - olap.soma_olap AS diferenca
FROM (
    SELECT
        m.fk_curso                              AS codigo_curso,
        SUM(COALESCE(p.valor_pago, 0))          AS soma_oltp
    FROM erp_escolar.mensalidade ms
    JOIN erp_escolar.contrato  ct ON ct.pk_id_contrato  = ms.fk_id_contrato
    JOIN erp_escolar.matricula m  ON m.pk_id_matricula  = ct.fk_id_matricula
    LEFT JOIN (
        SELECT fk_id_contrato, periodo, SUM(valor_pago) AS valor_pago
        FROM erp_escolar.pagamento
        WHERE status = 'Pago'
        GROUP BY fk_id_contrato, periodo
    ) p ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
    GROUP BY m.fk_curso
) oltp
JOIN (
    SELECT
        dc.codigo_curso,
        SUM(ft.valor_pago) AS soma_olap
    FROM erp_escolar_olap.ft_receita_mensalidade ft
    JOIN erp_escolar_olap.dim_curso dc ON dc.SK_curso = ft.fk_SK_curso
    GROUP BY dc.codigo_curso
) olap ON oltp.codigo_curso = olap.codigo_curso
ORDER BY oltp.codigo_curso;

-- ============================================================
-- PARTE 2: EXPLAIN ANTES DOS INDICES
-- Consultas representativas executadas sem indices adicionais
-- Observar: type = ALL (full scan), key = NULL
-- ============================================================

USE erp_escolar;

-- 2A: Busca de mensalidades por status (Q04 do OLTP)
-- Sem indice em mensalidade.status → full scan esperado
EXPLAIN
SELECT ms.periodo, ms.status, ms.valor_base - ms.valor_desconto AS valor_liquido
FROM mensalidade ms
WHERE ms.status IN ('Pendente', 'Atrasado');

-- 2B: Salario vigente por funcionario (Q02 do OLTP)
-- Filtro data_fim IS NULL sem indice → full scan em historico_salario
EXPLAIN
SELECT fk_rgf, salario
FROM historico_salario
WHERE data_fim IS NULL;

-- 2C: Join ETL — mensalidade + pagamento por contrato/periodo
-- Coluna status em pagamento sem indice → scan em cada lookup
EXPLAIN
SELECT ms.fk_id_contrato, ms.periodo, p.valor_pago
FROM mensalidade ms
LEFT JOIN pagamento p ON p.fk_id_contrato = ms.fk_id_contrato
                     AND p.periodo = ms.periodo
                     AND p.status = 'Pago';

-- ============================================================
-- PARTE 3: CRIACAO DE INDICES ESTRATEGICOS
-- Criterio de selecao: colunas usadas em WHERE, JOIN e ORDER BY
-- das consultas OLTP (Fase 3) e do ETL (Fase 5)
-- ============================================================

-- OLTP — Modulo Financeiro
-- mensalidade.status: filtro de inadimplencia (Q04) e ETL (Fase 5)
CREATE INDEX idx_mensalidade_status
    ON mensalidade (status);

-- pagamento(fk_id_contrato, periodo, status): join critico do ETL
-- composto porque as tres colunas aparecem juntas no ON do LEFT JOIN
CREATE INDEX idx_pagamento_contrato_periodo
    ON pagamento (fk_id_contrato, periodo, status);

-- OLTP — Modulo RH
-- historico_salario(fk_rgf, data_fim): salario vigente (Q02, Q08)
-- data_fim IS NULL e o filtro mais seletivo; composto cobre o JOIN por fk_rgf
CREATE INDEX idx_historico_salario_vigente
    ON historico_salario (fk_rgf, data_fim);

-- OLTP — Modulo Academico
-- matricula(fk_curso, status): contagem por curso (Q07) e join do ETL
CREATE INDEX idx_matricula_curso_status
    ON matricula (fk_curso, status);

-- frequencia(fk_id_matricula, fk_id_turma): GROUP BY de frequencia (Q09)
CREATE INDEX idx_frequencia_matricula_turma
    ON frequencia (fk_id_matricula, fk_id_turma);

-- OLAP — ft_receita_mensalidade
-- queries analiticas filtram e agrupam por tempo e curso com frequencia
CREATE INDEX idx_ft_tempo
    ON erp_escolar_olap.ft_receita_mensalidade (fk_SK_tempo);

CREATE INDEX idx_ft_curso_tempo
    ON erp_escolar_olap.ft_receita_mensalidade (fk_SK_curso, fk_SK_tempo);

CREATE INDEX idx_ft_status
    ON erp_escolar_olap.ft_receita_mensalidade (status_mensalidade);

-- OLAP — ft_desempenho_academico
-- filtros mais comuns: aluno, materia, semestre
CREATE INDEX idx_fda_aluno_materia
    ON erp_escolar_olap.ft_desempenho_academico (fk_SK_aluno, fk_SK_materia);

CREATE INDEX idx_fda_curso_ano
    ON erp_escolar_olap.ft_desempenho_academico (fk_SK_curso, ano_letivo, semestre_letivo);

-- OLAP — ft_folha_rh
-- filtros por tempo (mes) e funcionario para relatorios de folha
CREATE INDEX idx_ffr_tempo
    ON erp_escolar_olap.ft_folha_rh (fk_SK_tempo);

CREATE INDEX idx_ffr_funcionario
    ON erp_escolar_olap.ft_folha_rh (fk_SK_funcionario);

-- OLAP — ft_movimentacao_rh
-- filtros por tipo de evento e periodo para analise de turnover
CREATE INDEX idx_fmr_tipo_tempo
    ON erp_escolar_olap.ft_movimentacao_rh (tipo_movimentacao, fk_SK_tempo);

-- ============================================================
-- PARTE 4: EXPLAIN DEPOIS DOS INDICES
-- Mesmas consultas da Parte 2 — comparar key e type
-- Esperado: type = ref ou range, key = nome do indice criado
-- ============================================================

USE erp_escolar;

-- 4A: mesma consulta de mensalidade por status
EXPLAIN
SELECT ms.periodo, ms.status, ms.valor_base - ms.valor_desconto AS valor_liquido
FROM mensalidade ms
WHERE ms.status IN ('Pendente', 'Atrasado');

-- 4B: salario vigente — agora com idx_historico_salario_vigente
EXPLAIN
SELECT fk_rgf, salario
FROM historico_salario
WHERE data_fim IS NULL;

-- 4C: join ETL — agora com idx_pagamento_contrato_periodo
EXPLAIN
SELECT ms.fk_id_contrato, ms.periodo, p.valor_pago
FROM mensalidade ms
LEFT JOIN pagamento p ON p.fk_id_contrato = ms.fk_id_contrato
                     AND p.periodo = ms.periodo
                     AND p.status = 'Pago';

-- ============================================================
-- PARTE 5: CONSISTENCIA INTERNA DO OLTP
-- Verificacoes adicionais de integridade que a banca pode cobrar
-- ============================================================

-- 5A: Todo contrato ativo tem mensalidades geradas?
SELECT
    ct.pk_id_contrato,
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    ct.status,
    COUNT(ms.fk_id_contrato)         AS qtd_mensalidades
FROM contrato ct
JOIN matricula m ON m.pk_id_matricula = ct.fk_id_matricula
JOIN aluno     a ON a.rga             = m.fk_rga
LEFT JOIN mensalidade ms ON ms.fk_id_contrato = ct.pk_id_contrato
WHERE ct.status = 'Ativo'
GROUP BY ct.pk_id_contrato
ORDER BY qtd_mensalidades ASC;

-- 5B: Toda mensalidade Pago tem pagamento registrado?
SELECT
    ms.fk_id_contrato,
    ms.periodo,
    ms.status                  AS status_mensalidade,
    p.pk_id_pagamento          AS id_pagamento,
    p.status                   AS status_pagamento
FROM mensalidade ms
LEFT JOIN pagamento p ON p.fk_id_contrato = ms.fk_id_contrato
                     AND p.periodo = ms.periodo
                     AND p.status = 'Pago'
WHERE ms.status = 'Pago' AND p.pk_id_pagamento IS NULL;
-- resultado esperado: 0 linhas

-- 5C: Algum aluno em turma sem matricula no curso correspondente?
SELECT mt.fk_id_matricula, mt.fk_id_turma
FROM matricula_turma mt
JOIN turma       t ON t.pk_id_turma      = mt.fk_id_turma
JOIN matricula   m ON m.pk_id_matricula  = mt.fk_id_matricula
WHERE m.fk_curso != t.fk_curso;
-- resultado esperado: 0 linhas

-- ============================================================
-- PARTE 6: CONSULTAS ANALITICAS OLAP
-- Demonstra o valor do star schema: perguntas de negocio
-- que seriam custosas no OLTP, aqui sao diretas e rapidas
-- ============================================================

USE erp_escolar_olap;

-- 6A: Faturamento mensal — receita esperada vs realizada
-- Responde: em qual mes cobramos mais? Em qual pagamos mais?
SELECT
    dt.nome_mes,
    dt.ano,
    COUNT(*)                                             AS mensalidades,
    SUM(ft.valor_liquido)                                AS receita_esperada,
    SUM(ft.valor_pago)                                   AS receita_realizada,
    ROUND(SUM(ft.valor_pago) / SUM(ft.valor_liquido) * 100, 1) AS taxa_pagamento_pct
FROM ft_receita_mensalidade ft
JOIN dim_tempo              dt ON dt.SK_tempo = ft.fk_SK_tempo
GROUP BY dt.SK_tempo, dt.nome_mes, dt.ano
ORDER BY dt.SK_tempo;

-- 6B: Faturamento por unidade academica
-- Responde: qual area gera mais receita?
SELECT
    du.nome_unidade,
    COUNT(DISTINCT ft.fk_SK_aluno)  AS alunos,
    SUM(ft.valor_liquido)           AS receita_esperada,
    SUM(ft.valor_pago)              AS receita_realizada
FROM ft_receita_mensalidade ft
JOIN dim_unidade             du ON du.SK_unidade = ft.fk_SK_unidade
GROUP BY du.SK_unidade, du.nome_unidade
ORDER BY receita_realizada DESC;

-- 6C: Alunos com bolsa vs sem bolsa — impacto na receita
-- Responde: qual o custo financeiro das bolsas concedidas?
SELECT
    CASE tem_bolsa WHEN 1 THEN 'Com bolsa' ELSE 'Sem bolsa' END AS perfil,
    COUNT(DISTINCT fk_SK_aluno) AS alunos,
    SUM(valor_liquido)          AS receita_liquida,
    SUM(valor_desconto)         AS total_descontos,
    SUM(valor_pago)             AS receita_realizada
FROM ft_receita_mensalidade
GROUP BY tem_bolsa
ORDER BY tem_bolsa DESC;

-- 6D: Desempenho academico por materia — nota media e frequencia
-- Responde: qual materia tem menor media? Qual tem pior presenca?
SELECT
    dm.nome_materia,
    dc.nome_curso,
    COUNT(*)                                   AS alunos_avaliados,
    ROUND(AVG(fda.nota_final), 2)              AS nota_media,
    MIN(fda.nota_final)                        AS nota_minima,
    MAX(fda.nota_final)                        AS nota_maxima,
    ROUND(AVG(fda.percentual_presenca), 1)     AS presenca_media_pct,
    SUM(CASE WHEN fda.nota_final >= 6 THEN 1 ELSE 0 END) AS aprovados,
    SUM(CASE WHEN fda.nota_final < 6  THEN 1 ELSE 0 END) AS reprovados
FROM ft_desempenho_academico fda
JOIN dim_materia              dm  ON dm.SK_materia = fda.fk_SK_materia
JOIN dim_curso                dc  ON dc.SK_curso   = fda.fk_SK_curso
WHERE fda.nota_final IS NOT NULL
GROUP BY dm.SK_materia, dc.SK_curso
ORDER BY nota_media ASC;

-- 6E: Custo total de folha por mes e por departamento
-- Responde: qual departamento pesa mais na folha? Como evoluiu mensalmente?
SELECT
    dt.nome_mes,
    dt.ano,
    df.nome_departamento,
    COUNT(DISTINCT ff.fk_SK_funcionario)  AS funcionarios,
    SUM(ff.salario_bruto)                 AS total_bruto,
    SUM(ff.total_proventos)               AS total_proventos,
    SUM(ff.total_descontos)               AS total_descontos,
    SUM(ff.salario_liquido)               AS total_liquido
FROM ft_folha_rh      ff
JOIN dim_tempo        dt ON dt.SK_tempo        = ff.fk_SK_tempo
JOIN dim_funcionario  df ON df.SK_funcionario  = ff.fk_SK_funcionario
GROUP BY dt.SK_tempo, df.nome_departamento
ORDER BY dt.SK_tempo, total_bruto DESC;

-- 6F: Movimentacao de RH — headcount e admissoes por periodo
-- Responde: em qual mes contratamos mais? Qual e o tempo medio de empresa?
SELECT
    dt.ano,
    dt.nome_mes,
    SUM(CASE WHEN fm.tipo_movimentacao = 'Admissao'    THEN 1 ELSE 0 END) AS admissoes,
    SUM(CASE WHEN fm.tipo_movimentacao = 'Desligamento' THEN 1 ELSE 0 END) AS desligamentos,
    ROUND(AVG(CASE WHEN fm.tipo_movimentacao = 'Desligamento'
                   THEN fm.dias_empresa END), 0)                           AS tempo_medio_dias
FROM ft_movimentacao_rh fm
JOIN dim_tempo          dt ON dt.SK_tempo = fm.fk_SK_tempo
GROUP BY dt.SK_tempo
ORDER BY dt.SK_tempo;
