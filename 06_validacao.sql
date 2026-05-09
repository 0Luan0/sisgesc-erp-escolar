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
        COUNT(*)                AS total_registros,
        SUM(COALESCE(p.valor_pago, 0)) AS soma_oltp
    FROM erp_escolar.mensalidade ms
    JOIN erp_escolar.contrato ct ON ct.pk_id_contrato = ms.fk_id_contrato
    LEFT JOIN erp_escolar.pagamento p
        ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
       AND p.status = 'Pago'
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
    LEFT JOIN erp_escolar.pagamento p
        ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
       AND p.status = 'Pago'
    GROUP BY ms.periodo
) oltp
JOIN (
    SELECT
        dt.ano * 100 + dt.mes                     AS periodo_num,
        CONCAT(dt.ano, '-', LPAD(dt.mes, 2, '0')) AS periodo,
        SUM(ft.valor_pago)                         AS soma_olap
    FROM erp_escolar_olap.ft_receita_mensalidade ft
    JOIN erp_escolar_olap.dim_tempo dt ON dt.pk_id_tempo = ft.fk_id_tempo
    GROUP BY dt.pk_id_tempo
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
    LEFT JOIN erp_escolar.pagamento p
        ON p.fk_id_contrato = ms.fk_id_contrato
       AND p.periodo = ms.periodo
       AND p.status = 'Pago'
    GROUP BY m.fk_curso
) oltp
JOIN (
    SELECT
        dc.codigo_curso,
        SUM(ft.valor_pago) AS soma_olap
    FROM erp_escolar_olap.ft_receita_mensalidade ft
    JOIN erp_escolar_olap.dim_curso dc ON dc.pk_id_curso = ft.fk_id_curso
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
CREATE INDEX IF NOT EXISTS idx_mensalidade_status
    ON mensalidade (status);

-- pagamento(fk_id_contrato, periodo, status): join critico do ETL
-- composto porque as tres colunas aparecem juntas no ON do LEFT JOIN
CREATE INDEX IF NOT EXISTS idx_pagamento_contrato_periodo
    ON pagamento (fk_id_contrato, periodo, status);

-- OLTP — Modulo RH
-- historico_salario(fk_rgf, data_fim): salario vigente (Q02, Q08)
-- data_fim IS NULL e o filtro mais seletivo; composto cobre o JOIN por fk_rgf
CREATE INDEX IF NOT EXISTS idx_historico_salario_vigente
    ON historico_salario (fk_rgf, data_fim);

-- OLTP — Modulo Academico
-- matricula(fk_curso, status): contagem por curso (Q07) e join do ETL
CREATE INDEX IF NOT EXISTS idx_matricula_curso_status
    ON matricula (fk_curso, status);

-- frequencia(fk_id_matricula, fk_id_turma): GROUP BY de frequencia (Q09)
CREATE INDEX IF NOT EXISTS idx_frequencia_matricula_turma
    ON frequencia (fk_id_matricula, fk_id_turma);

-- OLAP — Fato
-- queries analiticas filtram e agrupam por tempo e curso com frequencia
CREATE INDEX IF NOT EXISTS idx_ft_tempo
    ON erp_escolar_olap.ft_receita_mensalidade (fk_id_tempo);

CREATE INDEX IF NOT EXISTS idx_ft_curso_tempo
    ON erp_escolar_olap.ft_receita_mensalidade (fk_id_curso, fk_id_tempo);

CREATE INDEX IF NOT EXISTS idx_ft_status
    ON erp_escolar_olap.ft_receita_mensalidade (status_mensalidade);

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
JOIN dim_tempo              dt ON dt.pk_id_tempo = ft.fk_id_tempo
GROUP BY dt.pk_id_tempo, dt.nome_mes, dt.ano
ORDER BY dt.pk_id_tempo;

-- 6B: Faturamento por unidade academica
-- Responde: qual area gera mais receita?
SELECT
    du.nome_unidade,
    COUNT(DISTINCT ft.fk_id_aluno)  AS alunos,
    SUM(ft.valor_liquido)           AS receita_esperada,
    SUM(ft.valor_pago)              AS receita_realizada
FROM ft_receita_mensalidade ft
JOIN dim_unidade             du ON du.pk_id_unidade = ft.fk_id_unidade
GROUP BY du.pk_id_unidade, du.nome_unidade
ORDER BY receita_realizada DESC;

-- 6C: Alunos com bolsa vs sem bolsa — impacto na receita
-- Responde: qual o custo financeiro das bolsas concedidas?
SELECT
    CASE tem_bolsa WHEN 1 THEN 'Com bolsa' ELSE 'Sem bolsa' END AS perfil,
    COUNT(DISTINCT fk_id_aluno) AS alunos,
    SUM(valor_liquido)          AS receita_liquida,
    SUM(valor_desconto)         AS total_descontos,
    SUM(valor_pago)             AS receita_realizada
FROM ft_receita_mensalidade
GROUP BY tem_bolsa
ORDER BY tem_bolsa DESC;
