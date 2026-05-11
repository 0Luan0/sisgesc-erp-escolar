-- ============================================================
-- SISGESC — Star Schema (OLAP)
-- Grain: 1 linha por mensalidade gerada
-- Dimensoes: Tempo, Aluno, Curso, Unidade
-- Fato: ft_receita_mensalidade
-- Banco separado para isolar OLTP de OLAP
-- ============================================================

CREATE DATABASE IF NOT EXISTS erp_escolar_olap
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE erp_escolar_olap;

-- ============================================================
-- DIMENSAO TEMPO
-- PK: YYYYMM (ex: 202402) — natural, estavel, imutavel
-- Sem surrogate: o proprio valor identifica univocamente o periodo
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_tempo (
  SK_tempo       INT         NOT NULL COMMENT 'YYYYMM — chave natural do periodo',
  ano            YEAR        NOT NULL,
  mes            TINYINT     NOT NULL,
  nome_mes       VARCHAR(20) NOT NULL,
  trimestre      TINYINT     NOT NULL,
  semestre       TINYINT     NOT NULL,
  dia_semana     TINYINT     NOT NULL COMMENT '1=Segunda ... 7=Domingo (ISO) — dia 1 do mes',
  nome_dia_semana VARCHAR(15) NOT NULL COMMENT 'ex: Segunda-Feira — dia 1 do mes',
  PRIMARY KEY (SK_tempo),
  CONSTRAINT chk_dt_mes  CHECK (mes BETWEEN 1 AND 12),
  CONSTRAINT chk_dt_trim CHECK (trimestre BETWEEN 1 AND 4),
  CONSTRAINT chk_dt_sem  CHECK (semestre BETWEEN 1 AND 2),
  CONSTRAINT chk_dt_dow  CHECK (dia_semana BETWEEN 1 AND 7)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO ALUNO
-- Surrogate: rga e chave natural no OLTP mas o star schema
-- usa surrogate para isolar do OLTP e permitir SCD futura
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_aluno (
  SK_aluno   INT          NOT NULL AUTO_INCREMENT,
  rga           CHAR(8)      NOT NULL,
  nome_completo VARCHAR(202) NOT NULL,
  ano_ingresso  YEAR         NOT NULL,
  curso_ingresso CHAR(3)     NOT NULL COMMENT 'curso no momento da matricula (snapshot)',
  PRIMARY KEY (SK_aluno),
  UNIQUE KEY uq_da_rga (rga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO CURSO
-- Surrogate: codigo_curso e CHAR(3) — bom para FK no OLTP,
-- mas star schema padroniza surrogate em todas as dims
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_curso (
  SK_curso   INT         NOT NULL AUTO_INCREMENT,
  codigo_curso  CHAR(3)     NOT NULL,
  nome_curso    VARCHAR(100) NOT NULL,
  nivel_ensino  VARCHAR(30) NOT NULL,
  PRIMARY KEY (SK_curso),
  UNIQUE KEY uq_dc_codigo (codigo_curso)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO UNIDADE
-- Representa a area academica que agrupa os cursos.
-- Permite analise por grande area sem depender de curso especifico.
-- Surrogate: sem chave natural clara no OLTP (nao ha tabela unidade)
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_unidade (
  SK_unidade INT         NOT NULL AUTO_INCREMENT,
  nome_unidade  VARCHAR(60) NOT NULL,
  PRIMARY KEY (SK_unidade),
  UNIQUE KEY uq_du_nome (nome_unidade)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABELA FATO — ft_receita_mensalidade
-- Grain: 1 linha por mensalidade gerada no OLTP
-- Metricas aditivas: valor_base, valor_desconto, valor_liquido, valor_pago
-- Metricas semi-aditivas: flag pago (nao soma por tempo de forma direta)
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_receita_mensalidade (
  pk_id_fato      INT            NOT NULL AUTO_INCREMENT,
  fk_SK_tempo     INT            NOT NULL,
  fk_SK_aluno     INT            NOT NULL,
  fk_SK_curso     INT            NOT NULL,
  fk_SK_unidade   INT            NOT NULL,
  -- metricas financeiras (snapshot do momento da geracao da mensalidade)
  valor_base      DECIMAL(10,2)  NOT NULL,
  valor_desconto  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  valor_liquido   DECIMAL(10,2)  NOT NULL COMMENT 'valor_base - valor_desconto',
  valor_pago      DECIMAL(10,2)  NOT NULL DEFAULT 0.00 COMMENT '0 se nao quitada',
  -- flags analiticas (degenerate dimensions)
  status_mensalidade VARCHAR(10) NOT NULL,
  tem_bolsa       TINYINT(1)     NOT NULL DEFAULT 0,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_ft_tempo    FOREIGN KEY (fk_SK_tempo)   REFERENCES dim_tempo(SK_tempo),
  CONSTRAINT fk_ft_aluno    FOREIGN KEY (fk_SK_aluno)   REFERENCES dim_aluno(SK_aluno),
  CONSTRAINT fk_ft_curso    FOREIGN KEY (fk_SK_curso)   REFERENCES dim_curso(SK_curso),
  CONSTRAINT fk_ft_unidade  FOREIGN KEY (fk_SK_unidade) REFERENCES dim_unidade(SK_unidade)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO MATERIA
-- Surrogate: star schema padroniza surrogate em todas as dims
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_materia (
  SK_materia  INT         NOT NULL AUTO_INCREMENT,
  codigo_materia CHAR(5)     NOT NULL,
  nome_materia   VARCHAR(60) NOT NULL,
  carga_horaria  INT         NOT NULL,
  PRIMARY KEY (SK_materia),
  UNIQUE KEY uq_dm_codigo (codigo_materia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO FUNCIONARIO
-- Surrogate: isolamento do OLTP e consistencia com demais dims
-- Snapshot dos atributos descritivos no momento da carga
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_funcionario (
  SK_funcionario INT          NOT NULL AUTO_INCREMENT,
  rgf               CHAR(5)      NOT NULL,
  nome_completo     VARCHAR(101) NOT NULL,
  codigo_cargo      CHAR(3)      NOT NULL,
  nome_cargo        VARCHAR(120) NOT NULL,
  nome_departamento VARCHAR(100) NOT NULL,
  nivel_cargo       VARCHAR(10)  NOT NULL,
  data_admissao     DATE         NOT NULL,
  PRIMARY KEY (SK_funcionario),
  UNIQUE KEY uq_df_rgf (rgf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABELA FATO — ft_desempenho_academico
-- Grain: 1 linha por (aluno, materia, semestre letivo)
-- Metricas: nota_final ponderada, frequencia absoluta e percentual
-- Dimensoes temporais como degenerate dims (ano+semestre != YYYYMM)
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_desempenho_academico (
  pk_id_fato          INT            NOT NULL AUTO_INCREMENT,
  fk_SK_aluno         INT            NOT NULL,
  fk_SK_curso         INT            NOT NULL,
  fk_SK_materia       INT            NOT NULL,
  ano_letivo          YEAR           NOT NULL,
  semestre_letivo     TINYINT        NOT NULL COMMENT '1 ou 2',
  -- degenerate dim
  turno               VARCHAR(10)    NOT NULL COMMENT 'Manha | Tarde | Noite',
  -- metricas academicas
  nota_final          DECIMAL(4,2)   COMMENT 'media ponderada; NULL se sem avaliacao registrada',
  total_aulas         INT            NOT NULL DEFAULT 0,
  total_presencas     INT            NOT NULL DEFAULT 0,
  percentual_presenca DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
  status_turma        VARCHAR(20)    NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fda_aluno   FOREIGN KEY (fk_SK_aluno)   REFERENCES dim_aluno(SK_aluno),
  CONSTRAINT fk_fda_curso   FOREIGN KEY (fk_SK_curso)   REFERENCES dim_curso(SK_curso),
  CONSTRAINT fk_fda_materia FOREIGN KEY (fk_SK_materia) REFERENCES dim_materia(SK_materia),
  CONSTRAINT chk_fda_sem    CHECK (semestre_letivo IN (1, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABELA FATO — ft_folha_rh
-- Grain: 1 linha por (funcionario, periodo mensal)
-- Metricas: bruto, proventos, descontos, liquido (snapshot OLAP)
-- salario_liquido aqui e metrica agregada do OLAP, nao campo
-- derivado do OLTP — intencional, analogo aos snapshots financeiros
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_folha_rh (
  pk_id_fato        INT            NOT NULL AUTO_INCREMENT,
  fk_SK_funcionario INT            NOT NULL,
  fk_SK_tempo       INT            NOT NULL,
  -- metricas (snapshot do mes processado)
  salario_bruto     DECIMAL(10,2)  NOT NULL,
  total_proventos   DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  total_descontos   DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  salario_liquido   DECIMAL(10,2)  NOT NULL,
  status_folha      VARCHAR(20)    NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_ffr_func  FOREIGN KEY (fk_SK_funcionario) REFERENCES dim_funcionario(SK_funcionario),
  CONSTRAINT fk_ffr_tempo FOREIGN KEY (fk_SK_tempo)       REFERENCES dim_tempo(SK_tempo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABELA FATO — ft_movimentacao_rh
-- Grain: 1 linha por evento de admissao ou desligamento
-- Permite analise de turnover: headcount, tempo medio de empresa
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_movimentacao_rh (
  pk_id_fato        INT          NOT NULL AUTO_INCREMENT,
  fk_SK_funcionario INT          NOT NULL,
  fk_SK_tempo       INT          NOT NULL COMMENT 'mes do evento (YYYYMM)',
  tipo_movimentacao VARCHAR(20)  NOT NULL COMMENT 'Admissao | Desligamento',
  dias_empresa      INT          NOT NULL DEFAULT 0 COMMENT '0 na admissao; DATEDIFF na saida',
  data_evento       DATE         NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fmr_func  FOREIGN KEY (fk_SK_funcionario) REFERENCES dim_funcionario(SK_funcionario),
  CONSTRAINT fk_fmr_tempo FOREIGN KEY (fk_SK_tempo)       REFERENCES dim_tempo(SK_tempo),
  CONSTRAINT chk_fmr_tipo CHECK (tipo_movimentacao IN ('Admissao', 'Desligamento'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- DIMENSAO PROFESSOR
-- Subconjunto especializado de dim_funcionario: somente professores
-- Surrogate: padrao star schema — isolamento do OLTP e consistencia com demais dims
-- Atributos proprios de professor (formacao, especialidade) nao existem em dim_funcionario
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_professor (
  SK_professor      INT          NOT NULL AUTO_INCREMENT,
  rgf               CHAR(5)      NOT NULL,
  nome_completo     VARCHAR(101) NOT NULL,
  formacao          VARCHAR(100)          COMMENT 'NULL se nao cadastrado no OLTP',
  especialidade     VARCHAR(100)          COMMENT 'NULL se nao cadastrado no OLTP',
  nome_departamento VARCHAR(100) NOT NULL,
  data_admissao     DATE         NOT NULL,
  PRIMARY KEY (SK_professor),
  UNIQUE KEY uq_dp_rgf (rgf)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- DIMENSAO METODO PAGAMENTO
-- Vocabulario controlado carregado de metodo_pagamento (OLTP)
-- Surrogate: padrao star schema — mesmo que o OLTP use varchar como PK natural,
-- o star schema padroniza INT surrogate em todas as dims para JOINs uniformes
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_metodo_pagamento (
  SK_metodo   INT         NOT NULL AUTO_INCREMENT,
  nome_metodo VARCHAR(30) NOT NULL,
  PRIMARY KEY (SK_metodo),
  UNIQUE KEY uq_dmp_metodo (nome_metodo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- TABELA FATO — ft_inadimplencia
-- Grain: 1 linha por mensalidade com atraso registrado (tabela atraso_mensalidade)
-- Metricas aditivas: dias_atraso, valor_multa, valor_juros, valor_em_aberto
-- Flag recuperado: 1 se a mensalidade foi quitada apos o atraso
-- Dimensoes: tempo (periodo da cobranca), aluno, curso
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_inadimplencia (
  pk_id_fato      INT           NOT NULL AUTO_INCREMENT,
  fk_SK_tempo     INT           NOT NULL COMMENT 'periodo da mensalidade (YYYYMM)',
  fk_SK_aluno     INT           NOT NULL,
  fk_SK_curso     INT           NOT NULL,
  dias_atraso     INT           NOT NULL,
  valor_multa     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_juros     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  valor_em_aberto DECIMAL(10,2) NOT NULL COMMENT 'valor_liquido - total_pago no momento da carga ETL',
  recuperado      TINYINT(1)    NOT NULL DEFAULT 0 COMMENT '1 se mensalidade.status = Pago',
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fi_tempo FOREIGN KEY (fk_SK_tempo) REFERENCES dim_tempo(SK_tempo),
  CONSTRAINT fk_fi_aluno FOREIGN KEY (fk_SK_aluno) REFERENCES dim_aluno(SK_aluno),
  CONSTRAINT fk_fi_curso FOREIGN KEY (fk_SK_curso) REFERENCES dim_curso(SK_curso)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- TABELA FATO — ft_carga_docente
-- Grain: 1 linha por (professor, turma, semestre letivo)
-- Metricas: qtd_alunos, nota_media, presenca_media, aprovados, reprovados
-- turno: degenerate dim — valor direto da turma, nao justifica tabela propria
-- Nao ha fk_SK_tempo: semestre nao tem granularidade mensal (degenerate dim)
-- consistente com ft_desempenho_academico que usa o mesmo padrao
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_carga_docente (
  pk_id_fato          INT           NOT NULL AUTO_INCREMENT,
  fk_SK_professor     INT           NOT NULL,
  fk_SK_curso         INT           NOT NULL,
  fk_SK_materia       INT           NOT NULL,
  ano_letivo          YEAR          NOT NULL,
  semestre_letivo     TINYINT       NOT NULL COMMENT '1 ou 2',
  turno               VARCHAR(10)   NOT NULL COMMENT 'degenerate dim: Manha | Tarde | Noite',
  qtd_alunos          INT           NOT NULL DEFAULT 0,
  nota_media_turma    DECIMAL(4,2)           COMMENT 'NULL se sem avaliacao registrada',
  presenca_media_pct  DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
  qtd_aprovados       INT           NOT NULL DEFAULT 0,
  qtd_reprovados      INT           NOT NULL DEFAULT 0,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fcd_prof    FOREIGN KEY (fk_SK_professor) REFERENCES dim_professor(SK_professor),
  CONSTRAINT fk_fcd_curso   FOREIGN KEY (fk_SK_curso)     REFERENCES dim_curso(SK_curso),
  CONSTRAINT fk_fcd_materia FOREIGN KEY (fk_SK_materia)   REFERENCES dim_materia(SK_materia),
  CONSTRAINT chk_fcd_sem    CHECK (semestre_letivo IN (1, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
-- TABELA FATO — ft_pagamento
-- Grain: 1 linha por registro na tabela pagamento do OLTP (pagamentos efetivados)
-- fk_SK_tempo: mes do pagamento EFETIVO (cashflow), nao do periodo da cobranca
--   -> permite responder "quanto entrou no caixa em agosto?" independente do vencimento
-- Nota: nao inclui pagamento_a_vista (fluxo alternativo coberto por ft_receita_mensalidade)
-- Expansao de dim_tempo no STEP 1 garante que meses de pagamento existam na dimensao
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_pagamento (
  pk_id_fato   INT           NOT NULL AUTO_INCREMENT,
  fk_SK_tempo  INT           NOT NULL COMMENT 'mes do pagamento efetivo (YYYYMM)',
  fk_SK_aluno  INT           NOT NULL,
  fk_SK_curso  INT           NOT NULL,
  fk_SK_metodo INT           NOT NULL,
  valor_pago   DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fpag_tempo   FOREIGN KEY (fk_SK_tempo)  REFERENCES dim_tempo(SK_tempo),
  CONSTRAINT fk_fpag_aluno   FOREIGN KEY (fk_SK_aluno)  REFERENCES dim_aluno(SK_aluno),
  CONSTRAINT fk_fpag_curso   FOREIGN KEY (fk_SK_curso)  REFERENCES dim_curso(SK_curso),
  CONSTRAINT fk_fpag_metodo  FOREIGN KEY (fk_SK_metodo) REFERENCES dim_metodo_pagamento(SK_metodo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
