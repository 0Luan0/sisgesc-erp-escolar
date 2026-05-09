-- ============================================================
-- SISGESC — Sistema de Gestao Escolar
-- DDL Completo | MySQL 8+ (utf8mb4_unicode_ci)
-- Modulos: Academico | Financeiro | RH
-- ============================================================
-- Criterios de PK:
--   Natural: valor estavel, unico, imutavel, controlado pelo sistema
--   Composta: N:N ou entidade dependente sem identidade propria
--   Surrogate: sem chave natural clara ou composta pesada como FK
-- ============================================================

CREATE DATABASE IF NOT EXISTS erp_escolar
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE erp_escolar;


-- ============================================================
-- TABELAS DE APOIO (dominio)
-- PK = proprio valor varchar — chave natural, estavel
-- Separadas por contexto: impede aluno.status = 'Pago'
-- ============================================================

CREATE TABLE status_aluno (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_aluno (status) VALUES ('Ativo'), ('Inativo');

CREATE TABLE status_matricula (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_matricula (status) VALUES ('Cursando'), ('Concluido'), ('Trancado'), ('Cancelado');

CREATE TABLE status_matricula_turma (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_matricula_turma (status) VALUES ('Cursando'), ('Aprovado'), ('Reprovado');

CREATE TABLE status_funcionario (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_funcionario (status) VALUES ('Ativo'), ('Afastado'), ('Desligado');

CREATE TABLE status_contrato (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_contrato (status) VALUES ('Ativo'), ('Encerrado'), ('Suspenso'), ('Cancelado');

CREATE TABLE status_mensalidade (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_mensalidade (status) VALUES ('Pendente'), ('Pago'), ('Atrasado'), ('Cancelado');

CREATE TABLE status_pagamento (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_pagamento (status) VALUES ('Pendente'), ('Pago'), ('Cancelado');

CREATE TABLE status_ferias (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_ferias (status) VALUES ('Planejada'), ('Em andamento'), ('Concluida'), ('Cancelada');

CREATE TABLE status_folha (
  status VARCHAR(20) NOT NULL,
  PRIMARY KEY (status)
);
INSERT INTO status_folha (status) VALUES ('Em processamento'), ('Paga'), ('Cancelada');

CREATE TABLE turno (
  turno VARCHAR(10) NOT NULL,
  PRIMARY KEY (turno)
);
INSERT INTO turno (turno) VALUES ('Manha'), ('Tarde'), ('Noite');

CREATE TABLE tipo_conta_bancaria (
  tipo VARCHAR(20) NOT NULL,
  PRIMARY KEY (tipo)
);
INSERT INTO tipo_conta_bancaria (tipo) VALUES ('Corrente'), ('Poupanca'), ('Salario');

CREATE TABLE tipo_ocorrencia (
  tipo VARCHAR(30) NOT NULL,
  PRIMARY KEY (tipo)
);
INSERT INTO tipo_ocorrencia (tipo) VALUES ('Atraso'), ('Falta'), ('Saida antecipada');

CREATE TABLE tipo_parentesco (
  tipo VARCHAR(30) NOT NULL,
  PRIMARY KEY (tipo)
);
INSERT INTO tipo_parentesco (tipo) VALUES
  ('Filho Biologico'), ('Filho Adotivo'), ('Conjuge'), ('Pai'), ('Mae'), ('Outro');

CREATE TABLE tipo_evento_folha (
  tipo VARCHAR(20) NOT NULL,
  PRIMARY KEY (tipo)
);
INSERT INTO tipo_evento_folha (tipo) VALUES ('Provento'), ('Desconto');

CREATE TABLE nivel_cargo (
  nivel VARCHAR(10) NOT NULL,
  PRIMARY KEY (nivel)
);
INSERT INTO nivel_cargo (nivel) VALUES ('Junior'), ('Pleno'), ('Senior');

CREATE TABLE tipo_ponto (
  tipo VARCHAR(30) NOT NULL,
  PRIMARY KEY (tipo)
);
INSERT INTO tipo_ponto (tipo) VALUES ('Entrada'), ('Saida'), ('Intervalo'), ('Retorno intervalo');

CREATE TABLE metodo_pagamento (
  metodo VARCHAR(30) NOT NULL,
  PRIMARY KEY (metodo)
);
INSERT INTO metodo_pagamento (metodo) VALUES ('Pix'), ('Boleto'), ('Cartao'), ('Transferencia'), ('Dinheiro');

-- correcao feedback 1a entrega: nivel de ensino no curso
CREATE TABLE nivel_ensino (
  nivel VARCHAR(20) NOT NULL,
  PRIMARY KEY (nivel)
);
INSERT INTO nivel_ensino (nivel) VALUES ('Tecnico'), ('Tecnologo'), ('Bacharelado'), ('Pos-Graduacao');


-- ============================================================
-- MODULO RH — Departamento, Cargo
-- ============================================================

CREATE TABLE departamento (
  nome_departamento VARCHAR(100) NOT NULL,
  descricao         TEXT,
  ativo             BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (nome_departamento)
);

-- salario_base depende do cargo (3FN ok)
CREATE TABLE cargo (
  codigo_cargo      CHAR(3)       NOT NULL,
  nome_cargo        VARCHAR(120)  NOT NULL,
  nome_departamento VARCHAR(100)  NOT NULL,
  nivel             VARCHAR(10)   NOT NULL,
  salario_base      DECIMAL(10,2) NOT NULL,
  ativo             BOOLEAN       NOT NULL DEFAULT TRUE,
  PRIMARY KEY (codigo_cargo),
  CONSTRAINT chk_cargo_salario CHECK (salario_base > 0),
  CONSTRAINT fk_cargo_depto FOREIGN KEY (nome_departamento)
    REFERENCES departamento(nome_departamento) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cargo_nivel FOREIGN KEY (nivel)
    REFERENCES nivel_cargo(nivel) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- cadastro de proventos e descontos
CREATE TABLE evento_folha (
  nome_evento VARCHAR(50) NOT NULL,
  tipo        VARCHAR(20) NOT NULL,
  PRIMARY KEY (nome_evento),
  CONSTRAINT fk_evfolha_tipo FOREIGN KEY (tipo)
    REFERENCES tipo_evento_folha(tipo) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ============================================================
-- MODULO RH — Funcionario e tabelas relacionadas
-- ============================================================

-- PK natural: rgf gerado pelo sistema, estavel e imutavel
-- TR_func_desligamento: status = 'Desligado' exige data_desligamento NOT NULL
CREATE TABLE funcionario (
  rgf                CHAR(5)      NOT NULL,
  cpf                CHAR(11)     NOT NULL,
  nome               VARCHAR(50)  NOT NULL,
  sobrenome          VARCHAR(50)  NOT NULL,
  data_nascimento    DATE         NOT NULL,
  codigo_cargo       CHAR(3)      NOT NULL,
  data_admissao      DATE         NOT NULL,
  data_desligamento  DATE,
  status             VARCHAR(20)  NOT NULL,
  data_criacao       DATETIME     NOT NULL DEFAULT NOW(),
  ultima_atualizacao DATETIME     NOT NULL DEFAULT NOW(),
  PRIMARY KEY (rgf),
  CONSTRAINT uq_func_cpf        UNIQUE (cpf),
  CONSTRAINT chk_func_cpf       CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT chk_func_admissao  CHECK (data_admissao > data_nascimento),
  CONSTRAINT chk_func_desligado CHECK (data_desligamento IS NULL OR data_desligamento > data_admissao),
  CONSTRAINT fk_func_cargo FOREIGN KEY (codigo_cargo)
    REFERENCES cargo(codigo_cargo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_func_status FOREIGN KEY (status)
    REFERENCES status_funcionario(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- professor e papel de funcionario, nao entidade independente
-- PK herdada — relacao 1:1 opcional
CREATE TABLE professor (
  fk_rgf        CHAR(5)      NOT NULL,
  formacao      VARCHAR(100),
  especialidade VARCHAR(100),
  ativo         BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (fk_rgf),
  CONSTRAINT fk_prof_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1:1 com funcionario, PK herdada
-- UQ_ctps: UNIQUE(numero_ctps, serie_ctps)
CREATE TABLE documentos_trabalhistas (
  fk_rgf         CHAR(5)  NOT NULL,
  pis            CHAR(11) NOT NULL,
  numero_ctps    CHAR(7)  NOT NULL,
  serie_ctps     CHAR(4)  NOT NULL,
  titulo_eleitor CHAR(12) NOT NULL,
  PRIMARY KEY (fk_rgf),
  CONSTRAINT chk_doctrab_pis    CHECK (pis            REGEXP '^[0-9]{11}$'),
  CONSTRAINT chk_doctrab_ctps   CHECK (numero_ctps    REGEXP '^[0-9]{7}$'),
  CONSTRAINT chk_doctrab_serie  CHECK (serie_ctps     REGEXP '^[0-9]{4}$'),
  CONSTRAINT chk_doctrab_titulo CHECK (titulo_eleitor REGEXP '^[0-9]{12}$'),
  CONSTRAINT uq_doctrab_pis    UNIQUE (pis),
  CONSTRAINT uq_doctrab_titulo UNIQUE (titulo_eleitor),
  CONSTRAINT uq_doctrab_ctps   UNIQUE (numero_ctps, serie_ctps),
  CONSTRAINT fk_doctrab_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1 funcionario -> N dependentes
-- TR_dependente_cpf_diferente_func: CPF do dependente != CPF do funcionario
CREATE TABLE dependente (
  rgd                    CHAR(5)     NOT NULL,
  fk_rgf                 CHAR(5)     NOT NULL,
  cpf                    CHAR(11)    NOT NULL,
  nome                   VARCHAR(50) NOT NULL,
  sobrenome              VARCHAR(50) NOT NULL,
  data_nascimento        DATE        NOT NULL,
  parentesco             VARCHAR(30) NOT NULL,
  dependente_ir          BOOLEAN     NOT NULL,
  dependente_plano_saude BOOLEAN     NOT NULL,
  ativo                  BOOLEAN     NOT NULL DEFAULT TRUE,
  PRIMARY KEY (rgd),
  CONSTRAINT uq_dep_func_cpf UNIQUE (fk_rgf, cpf),
  CONSTRAINT chk_dep_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT fk_dep_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_dep_parentesco FOREIGN KEY (parentesco)
    REFERENCES tipo_parentesco(tipo) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1 funcionario -> N contas bancarias. PK surrogate
-- TR_conta_principal: max 1 conta com principal = TRUE por funcionario
CREATE TABLE conta_banco_funcionario (
  pk_id_conta   INT         NOT NULL AUTO_INCREMENT,
  fk_rgf        CHAR(5)     NOT NULL,
  banco         VARCHAR(50) NOT NULL,
  agencia       VARCHAR(10) NOT NULL,
  conta         VARCHAR(20) NOT NULL,
  digito_conta  VARCHAR(5),
  tipo_conta    VARCHAR(20) NOT NULL,
  principal     BOOLEAN     NOT NULL DEFAULT FALSE,
  ativo         BOOLEAN     NOT NULL DEFAULT TRUE,
  data_cadastro DATETIME    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (pk_id_conta),
  CONSTRAINT fk_contabanco_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_contabanco_tipo FOREIGN KEY (tipo_conta)
    REFERENCES tipo_conta_bancaria(tipo) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK composta natural (fk_rgf, data_hora)
-- TR_ponto_alternancia: registros devem alternar Entrada/Saida
CREATE TABLE ponto (
  fk_rgf    CHAR(5)     NOT NULL,
  data_hora DATETIME    NOT NULL,
  tipo      VARCHAR(30) NOT NULL,
  PRIMARY KEY (fk_rgf, data_hora),
  CONSTRAINT fk_ponto_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ponto_tipo FOREIGN KEY (tipo)
    REFERENCES tipo_ponto(tipo) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK surrogate (mesmo func pode ter 2 ocorrencias do mesmo tipo no mesmo dia)
CREATE TABLE ocorrencia_desconto (
  pk_id_ocorrencia INT         NOT NULL AUTO_INCREMENT,
  fk_rgf           CHAR(5)     NOT NULL,
  tipo_ocorrencia  VARCHAR(30) NOT NULL,
  data_ocorrencia  DATE        NOT NULL,
  minutos          INT         NOT NULL,
  PRIMARY KEY (pk_id_ocorrencia),
  CONSTRAINT chk_ocorr_min CHECK (minutos > 0),
  CONSTRAINT fk_ocorr_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ocorr_tipo FOREIGN KEY (tipo_ocorrencia)
    REFERENCES tipo_ocorrencia(tipo) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK composta (fk_rgf, periodo) — 1 folha por funcionario por mes
-- salario_liquido eh DERIVADO = bruto + proventos - descontos (nao armazenar)
-- salario_bruto eh SNAPSHOT do historico_salario vigente
CREATE TABLE folha_pagamentos (
  fk_rgf         CHAR(5)       NOT NULL,
  periodo        CHAR(7)       NOT NULL,
  salario_bruto  DECIMAL(10,2) NOT NULL,
  data_pagamento DATE,
  status         VARCHAR(20)   NOT NULL,
  PRIMARY KEY (fk_rgf, periodo),
  CONSTRAINT chk_folha_periodo CHECK (periodo REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  CONSTRAINT chk_folha_salario CHECK (salario_bruto > 0),
  CONSTRAINT fk_folha_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_folha_status FOREIGN KEY (status)
    REFERENCES status_folha(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1 folha -> N eventos. valor SEMPRE positivo, sinal pelo tipo do evento_folha
CREATE TABLE folha_evento (
  fk_rgf      CHAR(5)       NOT NULL,
  periodo     CHAR(7)       NOT NULL,
  nome_evento VARCHAR(50)   NOT NULL,
  valor       DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (fk_rgf, periodo, nome_evento),
  CONSTRAINT chk_folhaev_valor CHECK (valor > 0),
  CONSTRAINT fk_folhaev_folha FOREIGN KEY (fk_rgf, periodo)
    REFERENCES folha_pagamentos(fk_rgf, periodo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_folhaev_evento FOREIGN KEY (nome_evento)
    REFERENCES evento_folha(nome_evento) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- N:N folha x ocorrencia
CREATE TABLE folha_ocorrencia (
  fk_rgf           CHAR(5) NOT NULL,
  periodo          CHAR(7) NOT NULL,
  pk_id_ocorrencia INT     NOT NULL,
  PRIMARY KEY (fk_rgf, periodo, pk_id_ocorrencia),
  CONSTRAINT fk_folhaoc_folha FOREIGN KEY (fk_rgf, periodo)
    REFERENCES folha_pagamentos(fk_rgf, periodo) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_folhaoc_ocorr FOREIGN KEY (pk_id_ocorrencia)
    REFERENCES ocorrencia_desconto(pk_id_ocorrencia) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- historico salarial — surrogate pq edge case de 2 reajustes no mesmo dia
-- TR_historico_salario_vigente: max 1 registro com data_fim IS NULL por func
CREATE TABLE historico_salario (
  pk_id_historico  INT           NOT NULL AUTO_INCREMENT,
  fk_rgf           CHAR(5)       NOT NULL,
  salario          DECIMAL(10,2) NOT NULL,
  data_inicio      DATE          NOT NULL,
  data_fim         DATE,
  motivo_alteracao VARCHAR(100),
  PRIMARY KEY (pk_id_historico),
  CONSTRAINT chk_histsal_valor CHECK (salario > 0),
  CONSTRAINT chk_histsal_datas CHECK (data_fim IS NULL OR data_fim > data_inicio),
  CONSTRAINT fk_histsal_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE periodo_aquisitivo (
  pk_id_periodo INT     NOT NULL AUTO_INCREMENT,
  fk_rgf        CHAR(5) NOT NULL,
  data_inicio   DATE    NOT NULL,
  data_fim      DATE    NOT NULL,
  dias_direito  INT     NOT NULL,
  PRIMARY KEY (pk_id_periodo),
  CONSTRAINT chk_peraquis_dias  CHECK (dias_direito >= 15 AND dias_direito <= 30),
  CONSTRAINT chk_peraquis_datas CHECK (data_fim > data_inicio),
  CONSTRAINT fk_peraquis_func FOREIGN KEY (fk_rgf)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1 periodo_aquisitivo -> N ferias (parceladas em ate 3)
-- TR_ferias_dentro_periodo: datas devem cair dentro do periodo aquisitivo
CREATE TABLE ferias (
  pk_id_ferias  INT         NOT NULL AUTO_INCREMENT,
  fk_id_periodo INT         NOT NULL,
  data_inicio   DATE        NOT NULL,
  data_fim      DATE        NOT NULL,
  status        VARCHAR(20) NOT NULL,
  PRIMARY KEY (pk_id_ferias),
  CONSTRAINT chk_ferias_datas CHECK (data_fim > data_inicio),
  CONSTRAINT fk_ferias_periodo FOREIGN KEY (fk_id_periodo)
    REFERENCES periodo_aquisitivo(pk_id_periodo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ferias_status FOREIGN KEY (status)
    REFERENCES status_ferias(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1:1 com periodo_aquisitivo (abono pecuniario)
CREATE TABLE abono_ferias (
  fk_id_periodo    INT           NOT NULL,
  dias_vendidos    INT           NOT NULL,
  valor            DECIMAL(10,2) NOT NULL,
  data_solicitacao DATE          NOT NULL DEFAULT (CURRENT_DATE),
  PRIMARY KEY (fk_id_periodo),
  CONSTRAINT chk_abono_dias  CHECK (dias_vendidos >= 1 AND dias_vendidos <= 10),
  CONSTRAINT chk_abono_valor CHECK (valor > 0),
  CONSTRAINT fk_abono_periodo FOREIGN KEY (fk_id_periodo)
    REFERENCES periodo_aquisitivo(pk_id_periodo) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ============================================================
-- MODULO ACADEMICO
-- ============================================================

-- PK natural — codigo controlado pelo sistema
-- nivel_ensino: correcao do feedback da 1a entrega
CREATE TABLE curso (
  codigo_curso       CHAR(3)     NOT NULL,
  nome_curso         VARCHAR(60) NOT NULL,
  descricao          TEXT        NOT NULL,
  nivel_ensino       VARCHAR(20) NOT NULL,
  ativo              BOOLEAN     NOT NULL DEFAULT TRUE,
  data_criacao       DATETIME    NOT NULL DEFAULT NOW(),
  ultima_atualizacao DATETIME    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (codigo_curso),
  CONSTRAINT fk_curso_nivel FOREIGN KEY (nivel_ensino)
    REFERENCES nivel_ensino(nivel) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE materia (
  codigo_materia     CHAR(5)     NOT NULL,
  nome_materia       VARCHAR(60) NOT NULL,
  carga_horaria      INT         NOT NULL,
  ativo              BOOLEAN     NOT NULL DEFAULT TRUE,
  data_criacao       DATETIME    NOT NULL DEFAULT NOW(),
  ultima_atualizacao DATETIME    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (codigo_materia),
  CONSTRAINT chk_mat_ch CHECK (carga_horaria > 0)
);

-- N:N curso x materia — grade base vigente
CREATE TABLE curso_materia (
  codigo_curso         CHAR(3)  NOT NULL,
  codigo_materia       CHAR(5)  NOT NULL,
  obrigatoria          BOOLEAN  NOT NULL DEFAULT TRUE,
  semestre_recomendado INT,
  PRIMARY KEY (codigo_curso, codigo_materia),
  CONSTRAINT chk_cm_semrec CHECK (semestre_recomendado > 0),
  CONSTRAINT fk_cm_curso FOREIGN KEY (codigo_curso)
    REFERENCES curso(codigo_curso) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cm_materia FOREIGN KEY (codigo_materia)
    REFERENCES materia(codigo_materia) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- grade revisada — alteracoes por periodo letivo
CREATE TABLE curso_materia_revisao (
  codigo_curso         CHAR(3)  NOT NULL,
  codigo_materia       CHAR(5)  NOT NULL,
  ano                  YEAR     NOT NULL,
  semestre             INT      NOT NULL,
  obrigatoria          BOOLEAN  NOT NULL DEFAULT TRUE,
  semestre_recomendado INT,
  ativo                BOOLEAN  NOT NULL DEFAULT TRUE,
  PRIMARY KEY (codigo_curso, codigo_materia, ano, semestre),
  CONSTRAINT chk_cmr_semestre CHECK (semestre IN (1, 2)),
  CONSTRAINT chk_cmr_semrec   CHECK (semestre_recomendado > 0),
  CONSTRAINT fk_cmr_curso FOREIGN KEY (codigo_curso)
    REFERENCES curso(codigo_curso) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_cmr_materia FOREIGN KEY (codigo_materia)
    REFERENCES materia(codigo_materia) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK surrogate: fk_curso nullable (NULL = institucional) impossibilita PK composta
-- TR_calendario_unico_institucional: MySQL trata NULL como distinto em UNIQUE
CREATE TABLE calendario_academico (
  pk_id_calendario INT          NOT NULL AUTO_INCREMENT,
  ano              YEAR         NOT NULL,
  semestre         INT          NOT NULL,
  data_inicio      DATE         NOT NULL,
  data_fim         DATE         NOT NULL,
  descricao        VARCHAR(100),
  fk_curso         CHAR(3),
  ativo            BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (pk_id_calendario),
  CONSTRAINT chk_cal_semestre CHECK (semestre IN (1, 2)),
  CONSTRAINT chk_cal_datas    CHECK (data_fim > data_inicio),
  CONSTRAINT uq_calendario    UNIQUE (ano, semestre, fk_curso),
  CONSTRAINT fk_cal_curso FOREIGN KEY (fk_curso)
    REFERENCES curso(codigo_curso) ON DELETE CASCADE ON UPDATE CASCADE
);

-- PK natural: rga gerado pelo sistema
CREATE TABLE aluno (
  rga                CHAR(8)     NOT NULL,
  cpf                CHAR(11)    NOT NULL,
  nome               VARCHAR(50) NOT NULL,
  sobrenome          VARCHAR(50) NOT NULL,
  data_nascimento    DATE        NOT NULL,
  status             VARCHAR(20) NOT NULL,
  data_criacao       DATETIME    NOT NULL DEFAULT NOW(),
  ultima_atualizacao DATETIME    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (rga),
  CONSTRAINT uq_aluno_cpf UNIQUE (cpf),
  CONSTRAINT chk_aluno_cpf CHECK (cpf REGEXP '^[0-9]{11}$'),
  CONSTRAINT fk_aluno_status FOREIGN KEY (status)
    REFERENCES status_aluno(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK surrogate — sem chave natural simples
-- 1 aluno -> N matriculas (cursos diferentes ou mesmo curso em anos diferentes)
-- TR_matricula_ativa: max 1 matricula 'Cursando' por aluno por curso
CREATE TABLE matricula (
  pk_id_matricula    INT         NOT NULL AUTO_INCREMENT,
  fk_rga             CHAR(8)     NOT NULL,
  fk_curso           CHAR(3)     NOT NULL,
  data_matricula     DATE        NOT NULL,
  status             VARCHAR(20) NOT NULL,
  ano_ingresso       INT         NOT NULL,
  data_criacao       DATETIME    NOT NULL DEFAULT NOW(),
  ultima_atualizacao DATETIME    NOT NULL DEFAULT NOW(),
  PRIMARY KEY (pk_id_matricula),
  CONSTRAINT fk_mat_aluno FOREIGN KEY (fk_rga)
    REFERENCES aluno(rga) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mat_curso FOREIGN KEY (fk_curso)
    REFERENCES curso(codigo_curso) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mat_status FOREIGN KEY (status)
    REFERENCES status_matricula(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK surrogate — composta (rgf, curso, materia, calendario, turno) seria 5 campos
-- TR_turma_calendario_coerente: calendario especifico deve ser do mesmo curso
CREATE TABLE turma (
  pk_id_turma      INT         NOT NULL AUTO_INCREMENT,
  fk_rgf           CHAR(5)     NOT NULL,
  fk_curso         CHAR(3)     NOT NULL,
  fk_materia       CHAR(5)     NOT NULL,
  fk_id_calendario INT         NOT NULL,
  turno            VARCHAR(10) NOT NULL,
  limite_alunos    INT         NOT NULL,
  PRIMARY KEY (pk_id_turma),
  CONSTRAINT uq_turma         UNIQUE (fk_curso, fk_materia, fk_id_calendario, turno),
  CONSTRAINT chk_turma_limite CHECK (limite_alunos > 0),
  CONSTRAINT fk_turma_prof FOREIGN KEY (fk_rgf)
    REFERENCES professor(fk_rgf) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_turma_curso FOREIGN KEY (fk_curso)
    REFERENCES curso(codigo_curso) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_turma_materia FOREIGN KEY (fk_materia)
    REFERENCES materia(codigo_materia) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_turma_cal FOREIGN KEY (fk_id_calendario)
    REFERENCES calendario_academico(pk_id_calendario) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_turma_turno FOREIGN KEY (turno)
    REFERENCES turno(turno) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- N:N matricula x turma
-- nota_final DERIVADO via VIEW (nao armazenar)
CREATE TABLE matricula_turma (
  fk_id_matricula INT         NOT NULL,
  fk_id_turma     INT         NOT NULL,
  status          VARCHAR(20) NOT NULL,
  PRIMARY KEY (fk_id_matricula, fk_id_turma),
  CONSTRAINT fk_mt_mat FOREIGN KEY (fk_id_matricula)
    REFERENCES matricula(pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mt_turma FOREIGN KEY (fk_id_turma)
    REFERENCES turma(pk_id_turma) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_mt_status FOREIGN KEY (status)
    REFERENCES status_matricula_turma(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE avaliacao (
  pk_id_avaliacao INT          NOT NULL AUTO_INCREMENT,
  fk_id_turma     INT          NOT NULL,
  nome_atividade  VARCHAR(60)  NOT NULL,
  peso            DECIMAL(4,2) NOT NULL,
  data_aplicacao  DATE,
  PRIMARY KEY (pk_id_avaliacao),
  CONSTRAINT chk_aval_peso CHECK (peso > 0),
  CONSTRAINT fk_aval_turma FOREIGN KEY (fk_id_turma)
    REFERENCES turma(pk_id_turma) ON DELETE CASCADE ON UPDATE CASCADE
);

-- PK composta (avaliacao + matricula)
-- fk_id_turma removido — redundante via avaliacao, violaria 3FN
-- TR_nota_aluno_na_turma: aluno deve estar na turma da avaliacao
CREATE TABLE nota (
  fk_id_avaliacao INT          NOT NULL,
  fk_id_matricula INT          NOT NULL,
  nota_atividade  DECIMAL(4,2) NOT NULL,
  PRIMARY KEY (fk_id_avaliacao, fk_id_matricula),
  CONSTRAINT chk_nota_valor CHECK (nota_atividade >= 0),
  CONSTRAINT fk_nota_aval FOREIGN KEY (fk_id_avaliacao)
    REFERENCES avaliacao(pk_id_avaliacao) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_nota_mat FOREIGN KEY (fk_id_matricula)
    REFERENCES matricula(pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- PK composta (matricula + turma + data_aula)
-- TR_frequencia_aluno_na_turma: aluno deve estar matriculado na turma
CREATE TABLE frequencia (
  fk_id_matricula INT     NOT NULL,
  fk_id_turma     INT     NOT NULL,
  data_aula       DATE    NOT NULL,
  presente        BOOLEAN NOT NULL,
  justificativa   TEXT,
  PRIMARY KEY (fk_id_matricula, fk_id_turma, data_aula),
  CONSTRAINT fk_freq_mat FOREIGN KEY (fk_id_matricula)
    REFERENCES matricula(pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_freq_turma FOREIGN KEY (fk_id_turma)
    REFERENCES turma(pk_id_turma) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ============================================================
-- MODULO FINANCEIRO
-- ============================================================

-- toda cobranca nasce no contrato, nao na matricula
-- 1 matricula -> 1 contrato (UNIQUE na FK)
CREATE TABLE contrato (
  pk_id_contrato               INT           NOT NULL AUTO_INCREMENT,
  fk_id_matricula              INT           NOT NULL,
  data_assinatura              DATE          NOT NULL,
  data_inicio_vigencia         DATE          NOT NULL,
  data_fim_vigencia            DATE,
  valor_mensalidade_referencia DECIMAL(10,2) NOT NULL,
  status                       VARCHAR(20)   NOT NULL,
  observacoes                  TEXT,
  data_criacao                 DATETIME      NOT NULL DEFAULT NOW(),
  ultima_atualizacao           DATETIME      NOT NULL DEFAULT NOW(),
  PRIMARY KEY (pk_id_contrato),
  CONSTRAINT uq_contrato_mat   UNIQUE (fk_id_matricula),
  CONSTRAINT chk_contr_valor   CHECK (valor_mensalidade_referencia > 0),
  CONSTRAINT chk_contr_inicio  CHECK (data_inicio_vigencia >= data_assinatura),
  CONSTRAINT chk_contr_datas   CHECK (data_fim_vigencia IS NULL OR data_fim_vigencia > data_inicio_vigencia),
  CONSTRAINT fk_contr_mat FOREIGN KEY (fk_id_matricula)
    REFERENCES matricula(pk_id_matricula) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_contr_status FOREIGN KEY (status)
    REFERENCES status_contrato(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE bolsa (
  pk_id_bolsa    INT          NOT NULL AUTO_INCREMENT,
  fk_id_contrato INT          NOT NULL,
  percentual     DECIMAL(5,2) NOT NULL,
  data_inicio    DATE         NOT NULL,
  data_fim       DATE,
  ativo          BOOLEAN      NOT NULL DEFAULT TRUE,
  PRIMARY KEY (pk_id_bolsa),
  CONSTRAINT chk_bolsa_perc  CHECK (percentual > 0 AND percentual <= 100),
  CONSTRAINT chk_bolsa_datas CHECK (data_fim IS NULL OR data_fim > data_inicio),
  CONSTRAINT fk_bolsa_contr FOREIGN KEY (fk_id_contrato)
    REFERENCES contrato(pk_id_contrato) ON DELETE CASCADE ON UPDATE CASCADE
);

-- PK composta (contrato + periodo)
-- valor_base e valor_desconto sao SNAPSHOTS (intencional, nao campo derivado)
-- valor_final = valor_base - valor_desconto -> DERIVADO via VIEW
CREATE TABLE mensalidade (
  fk_id_contrato  INT           NOT NULL,
  periodo         CHAR(7)       NOT NULL,
  valor_base      DECIMAL(10,2) NOT NULL,
  valor_desconto  DECIMAL(10,2) NOT NULL DEFAULT 0,
  data_vencimento DATE          NOT NULL,
  status          VARCHAR(20)   NOT NULL,
  PRIMARY KEY (fk_id_contrato, periodo),
  CONSTRAINT chk_mens_periodo CHECK (periodo REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
  CONSTRAINT chk_mens_base    CHECK (valor_base > 0),
  CONSTRAINT chk_mens_desc    CHECK (valor_desconto >= 0 AND valor_desconto <= valor_base),
  CONSTRAINT fk_mens_contr FOREIGN KEY (fk_id_contrato)
    REFERENCES contrato(pk_id_contrato) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_mens_status FOREIGN KEY (status)
    REFERENCES status_mensalidade(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- 1 mensalidade -> 0 ou 1 atraso (1:1)
CREATE TABLE atraso_mensalidade (
  fk_id_contrato INT           NOT NULL,
  periodo        CHAR(7)       NOT NULL,
  dias_atraso    INT           NOT NULL,
  valor_multa    DECIMAL(10,2) NOT NULL,
  valor_juros    DECIMAL(10,2) NOT NULL,
  data_calculo   DATETIME      NOT NULL DEFAULT NOW(),
  PRIMARY KEY (fk_id_contrato, periodo),
  CONSTRAINT chk_atraso_dias  CHECK (dias_atraso > 0),
  CONSTRAINT chk_atraso_multa CHECK (valor_multa >= 0),
  CONSTRAINT chk_atraso_juros CHECK (valor_juros >= 0),
  CONSTRAINT fk_atraso_mens FOREIGN KEY (fk_id_contrato, periodo)
    REFERENCES mensalidade(fk_id_contrato, periodo) ON DELETE CASCADE ON UPDATE CASCADE
);

-- 1 mensalidade -> N pagamentos (parcial permitido)
-- id_transacao_externo = ID da API de pagamento (Pix/Boleto delegados)
CREATE TABLE pagamento (
  pk_id_pagamento      INT           NOT NULL AUTO_INCREMENT,
  fk_id_contrato       INT           NOT NULL,
  periodo              CHAR(7)       NOT NULL,
  metodo               VARCHAR(30)   NOT NULL,
  data_pagamento       DATE          NOT NULL,
  valor_pago           DECIMAL(10,2) NOT NULL,
  status               VARCHAR(20)   NOT NULL,
  id_transacao_externo VARCHAR(100),
  PRIMARY KEY (pk_id_pagamento),
  CONSTRAINT chk_pag_valor CHECK (valor_pago > 0),
  CONSTRAINT fk_pag_mens FOREIGN KEY (fk_id_contrato, periodo)
    REFERENCES mensalidade(fk_id_contrato, periodo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pag_metodo FOREIGN KEY (metodo)
    REFERENCES metodo_pagamento(metodo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_pag_status FOREIGN KEY (status)
    REFERENCES status_pagamento(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE pagamento_a_vista (
  pk_id_avista   INT           NOT NULL AUTO_INCREMENT,
  fk_id_contrato INT           NOT NULL,
  metodo         VARCHAR(30)   NOT NULL,
  valor_total    DECIMAL(10,2) NOT NULL,
  data_pagamento DATE          NOT NULL,
  status         VARCHAR(20)   NOT NULL,
  PRIMARY KEY (pk_id_avista),
  CONSTRAINT chk_avista_valor CHECK (valor_total > 0),
  CONSTRAINT fk_avista_contr FOREIGN KEY (fk_id_contrato)
    REFERENCES contrato(pk_id_contrato) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_avista_metodo FOREIGN KEY (metodo)
    REFERENCES metodo_pagamento(metodo) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_avista_status FOREIGN KEY (status)
    REFERENCES status_pagamento(status) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- N:N pagamento_a_vista x mensalidade
-- TR_pagamento_avista_contrato_coerente: contrato deve bater
CREATE TABLE pagamento_avista_mensalidade (
  fk_id_avista   INT     NOT NULL,
  fk_id_contrato INT     NOT NULL,
  periodo        CHAR(7) NOT NULL,
  PRIMARY KEY (fk_id_avista, fk_id_contrato, periodo),
  CONSTRAINT fk_pam_avista FOREIGN KEY (fk_id_avista)
    REFERENCES pagamento_a_vista(pk_id_avista) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pam_mens FOREIGN KEY (fk_id_contrato, periodo)
    REFERENCES mensalidade(fk_id_contrato, periodo) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- ============================================================
-- TRIGGERS
-- ============================================================

DELIMITER $$
CREATE TRIGGER TR_func_desligamento_insert
BEFORE INSERT ON funcionario
FOR EACH ROW
BEGIN
  IF NEW.status = 'Desligado' AND NEW.data_desligamento IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Funcionario desligado deve ter data_desligamento preenchida.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_func_desligamento_update
BEFORE UPDATE ON funcionario
FOR EACH ROW
BEGIN
  IF NEW.status = 'Desligado' AND NEW.data_desligamento IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Funcionario desligado deve ter data_desligamento preenchida.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_ponto_alternancia_insert
BEFORE INSERT ON ponto
FOR EACH ROW
BEGIN
  DECLARE ultimo_tipo VARCHAR(30);
  SELECT tipo INTO ultimo_tipo
    FROM ponto
    WHERE fk_rgf = NEW.fk_rgf AND data_hora < NEW.data_hora
    ORDER BY data_hora DESC
    LIMIT 1;

  IF ultimo_tipo IS NOT NULL THEN
    IF ultimo_tipo = 'Entrada' AND NEW.tipo NOT IN ('Saida', 'Intervalo') THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Entrada, esperado Saida ou Intervalo.';
    END IF;
    IF ultimo_tipo = 'Saida' AND NEW.tipo != 'Entrada' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Saida, esperado Entrada.';
    END IF;
    IF ultimo_tipo = 'Intervalo' AND NEW.tipo != 'Retorno intervalo' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Intervalo, esperado Retorno intervalo.';
    END IF;
    IF ultimo_tipo = 'Retorno intervalo' AND NEW.tipo NOT IN ('Saida', 'Intervalo') THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Retorno intervalo, esperado Saida ou Intervalo.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_ponto_alternancia_update
BEFORE UPDATE ON ponto
FOR EACH ROW
BEGIN
  DECLARE ultimo_tipo VARCHAR(30);
  SELECT tipo INTO ultimo_tipo
    FROM ponto
    WHERE fk_rgf = NEW.fk_rgf AND data_hora < NEW.data_hora
    ORDER BY data_hora DESC
    LIMIT 1;

  IF ultimo_tipo IS NOT NULL THEN
    IF ultimo_tipo = 'Entrada' AND NEW.tipo NOT IN ('Saida', 'Intervalo') THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Entrada, esperado Saida ou Intervalo.';
    END IF;
    IF ultimo_tipo = 'Saida' AND NEW.tipo != 'Entrada' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Saida, esperado Entrada.';
    END IF;
    IF ultimo_tipo = 'Intervalo' AND NEW.tipo != 'Retorno intervalo' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Intervalo, esperado Retorno intervalo.';
    END IF;
    IF ultimo_tipo = 'Retorno intervalo' AND NEW.tipo NOT IN ('Saida', 'Intervalo') THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Apos Retorno intervalo, esperado Saida ou Intervalo.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_calendario_unico_institucional_insert
BEFORE INSERT ON calendario_academico
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.fk_curso IS NULL THEN
    SELECT COUNT(*) INTO total
      FROM calendario_academico
      WHERE ano = NEW.ano AND semestre = NEW.semestre AND fk_curso IS NULL;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ja existe calendario institucional para este ano/semestre.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_calendario_unico_institucional_update
BEFORE UPDATE ON calendario_academico
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.fk_curso IS NULL THEN
    SELECT COUNT(*) INTO total
      FROM calendario_academico
      WHERE ano = NEW.ano AND semestre = NEW.semestre AND fk_curso IS NULL
        AND pk_id_calendario != NEW.pk_id_calendario;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Ja existe calendario institucional para este ano/semestre.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_dependente_cpf_diferente_func_insert
BEFORE INSERT ON dependente
FOR EACH ROW
BEGIN
  DECLARE cpf_func CHAR(11);
  SELECT cpf INTO cpf_func FROM funcionario WHERE rgf = NEW.fk_rgf;
  IF NEW.cpf = cpf_func THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'CPF do dependente nao pode ser igual ao CPF do funcionario.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_dependente_cpf_diferente_func_update
BEFORE UPDATE ON dependente
FOR EACH ROW
BEGIN
  DECLARE cpf_func CHAR(11);
  IF NEW.cpf != OLD.cpf THEN
    SELECT cpf INTO cpf_func FROM funcionario WHERE rgf = NEW.fk_rgf;
    IF NEW.cpf = cpf_func THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'CPF do dependente nao pode ser igual ao CPF do funcionario.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_conta_principal_insert
BEFORE INSERT ON conta_banco_funcionario
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.principal = TRUE THEN
    SELECT COUNT(*) INTO total
      FROM conta_banco_funcionario
      WHERE fk_rgf = NEW.fk_rgf AND principal = TRUE;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Funcionario ja possui conta bancaria principal.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_conta_principal_update
BEFORE UPDATE ON conta_banco_funcionario
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.principal = TRUE AND OLD.principal = FALSE THEN
    SELECT COUNT(*) INTO total
      FROM conta_banco_funcionario
      WHERE fk_rgf = NEW.fk_rgf AND principal = TRUE AND pk_id_conta != NEW.pk_id_conta;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Funcionario ja possui conta bancaria principal.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_historico_salario_vigente_insert
BEFORE INSERT ON historico_salario
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.data_fim IS NULL THEN
    SELECT COUNT(*) INTO total
      FROM historico_salario
      WHERE fk_rgf = NEW.fk_rgf AND data_fim IS NULL;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Funcionario ja possui salario vigente sem data de encerramento.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_historico_salario_vigente_update
BEFORE UPDATE ON historico_salario
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.data_fim IS NULL THEN
    SELECT COUNT(*) INTO total
      FROM historico_salario
      WHERE fk_rgf = NEW.fk_rgf AND data_fim IS NULL AND pk_id_historico != NEW.pk_id_historico;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Funcionario ja possui salario vigente sem data de encerramento.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_ferias_dentro_periodo_insert
BEFORE INSERT ON ferias
FOR EACH ROW
BEGIN
  DECLARE v_inicio DATE;
  DECLARE v_fim    DATE;
  SELECT data_inicio, data_fim INTO v_inicio, v_fim
    FROM periodo_aquisitivo WHERE pk_id_periodo = NEW.fk_id_periodo;
  IF NEW.data_inicio < v_inicio OR NEW.data_fim > v_fim THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Ferias devem estar dentro do periodo aquisitivo.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_ferias_dentro_periodo_update
BEFORE UPDATE ON ferias
FOR EACH ROW
BEGIN
  DECLARE v_inicio DATE;
  DECLARE v_fim    DATE;
  SELECT data_inicio, data_fim INTO v_inicio, v_fim
    FROM periodo_aquisitivo WHERE pk_id_periodo = NEW.fk_id_periodo;
  IF NEW.data_inicio < v_inicio OR NEW.data_fim > v_fim THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Ferias devem estar dentro do periodo aquisitivo.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_matricula_ativa_insert
BEFORE INSERT ON matricula
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.status = 'Cursando' THEN
    SELECT COUNT(*) INTO total
      FROM matricula
      WHERE fk_rga = NEW.fk_rga AND fk_curso = NEW.fk_curso AND status = 'Cursando';
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Aluno ja possui matricula ativa neste curso.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_matricula_ativa_update
BEFORE UPDATE ON matricula
FOR EACH ROW
BEGIN
  DECLARE total INT;
  IF NEW.status = 'Cursando' AND OLD.status != 'Cursando' THEN
    SELECT COUNT(*) INTO total
      FROM matricula
      WHERE fk_rga = NEW.fk_rga AND fk_curso = NEW.fk_curso AND status = 'Cursando'
        AND pk_id_matricula != NEW.pk_id_matricula;
    IF total > 0 THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Aluno ja possui matricula ativa neste curso.';
    END IF;
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_turma_calendario_coerente_insert
BEFORE INSERT ON turma
FOR EACH ROW
BEGIN
  DECLARE cal_curso CHAR(3);
  SELECT fk_curso INTO cal_curso
    FROM calendario_academico WHERE pk_id_calendario = NEW.fk_id_calendario;
  IF cal_curso IS NOT NULL AND cal_curso != NEW.fk_curso THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Turma deve usar calendario institucional ou do mesmo curso.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_turma_calendario_coerente_update
BEFORE UPDATE ON turma
FOR EACH ROW
BEGIN
  DECLARE cal_curso CHAR(3);
  SELECT fk_curso INTO cal_curso
    FROM calendario_academico WHERE pk_id_calendario = NEW.fk_id_calendario;
  IF cal_curso IS NOT NULL AND cal_curso != NEW.fk_curso THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Turma deve usar calendario institucional ou do mesmo curso.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_nota_aluno_na_turma_insert
BEFORE INSERT ON nota
FOR EACH ROW
BEGIN
  DECLARE v_turma INT;
  DECLARE total   INT;
  SELECT fk_id_turma INTO v_turma
    FROM avaliacao WHERE pk_id_avaliacao = NEW.fk_id_avaliacao;
  SELECT COUNT(*) INTO total
    FROM matricula_turma
    WHERE fk_id_matricula = NEW.fk_id_matricula AND fk_id_turma = v_turma;
  IF total = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aluno nao esta matriculado na turma desta avaliacao.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_nota_aluno_na_turma_update
BEFORE UPDATE ON nota
FOR EACH ROW
BEGIN
  DECLARE v_turma INT;
  DECLARE total   INT;
  SELECT fk_id_turma INTO v_turma
    FROM avaliacao WHERE pk_id_avaliacao = NEW.fk_id_avaliacao;
  SELECT COUNT(*) INTO total
    FROM matricula_turma
    WHERE fk_id_matricula = NEW.fk_id_matricula AND fk_id_turma = v_turma;
  IF total = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aluno nao esta matriculado na turma desta avaliacao.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_frequencia_aluno_na_turma_insert
BEFORE INSERT ON frequencia
FOR EACH ROW
BEGIN
  DECLARE total INT;
  SELECT COUNT(*) INTO total
    FROM matricula_turma
    WHERE fk_id_matricula = NEW.fk_id_matricula AND fk_id_turma = NEW.fk_id_turma;
  IF total = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aluno nao esta matriculado nesta turma.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_frequencia_aluno_na_turma_update
BEFORE UPDATE ON frequencia
FOR EACH ROW
BEGIN
  DECLARE total INT;
  SELECT COUNT(*) INTO total
    FROM matricula_turma
    WHERE fk_id_matricula = NEW.fk_id_matricula AND fk_id_turma = NEW.fk_id_turma;
  IF total = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aluno nao esta matriculado nesta turma.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_pagamento_avista_contrato_coerente_insert
BEFORE INSERT ON pagamento_avista_mensalidade
FOR EACH ROW
BEGIN
  DECLARE v_contrato INT;
  SELECT fk_id_contrato INTO v_contrato
    FROM pagamento_a_vista WHERE pk_id_avista = NEW.fk_id_avista;
  IF v_contrato != NEW.fk_id_contrato THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Pagamento a vista nao pertence ao contrato desta mensalidade.';
  END IF;
END$$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER TR_pagamento_avista_contrato_coerente_update
BEFORE UPDATE ON pagamento_avista_mensalidade
FOR EACH ROW
BEGIN
  DECLARE v_contrato INT;
  SELECT fk_id_contrato INTO v_contrato
    FROM pagamento_a_vista WHERE pk_id_avista = NEW.fk_id_avista;
  IF v_contrato != NEW.fk_id_contrato THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Pagamento a vista nao pertence ao contrato desta mensalidade.';
  END IF;
END$$
DELIMITER ;


-- ============================================================
-- VIEWS — campos derivados (calculados, nao armazenados)
-- ============================================================

CREATE VIEW vw_salario_liquido AS
SELECT
  fp.fk_rgf,
  fp.periodo,
  fp.salario_bruto,
  COALESCE(SUM(CASE WHEN ef.tipo = 'Provento' THEN fe.valor ELSE 0 END), 0) AS total_proventos,
  COALESCE(SUM(CASE WHEN ef.tipo = 'Desconto' THEN fe.valor ELSE 0 END), 0) AS total_descontos,
  fp.salario_bruto
    + COALESCE(SUM(CASE WHEN ef.tipo = 'Provento' THEN fe.valor ELSE 0 END), 0)
    - COALESCE(SUM(CASE WHEN ef.tipo = 'Desconto' THEN fe.valor ELSE 0 END), 0)
  AS salario_liquido
FROM folha_pagamentos fp
LEFT JOIN folha_evento fe ON fe.fk_rgf = fp.fk_rgf AND fe.periodo = fp.periodo
LEFT JOIN evento_folha ef ON ef.nome_evento = fe.nome_evento
GROUP BY fp.fk_rgf, fp.periodo, fp.salario_bruto;

CREATE VIEW vw_nota_final AS
SELECT
  n.fk_id_matricula,
  a.fk_id_turma,
  SUM(n.nota_atividade * a.peso) / SUM(a.peso) AS nota_final
FROM nota n
JOIN avaliacao a ON a.pk_id_avaliacao = n.fk_id_avaliacao
GROUP BY n.fk_id_matricula, a.fk_id_turma;

CREATE VIEW vw_valor_mensalidade AS
SELECT
  fk_id_contrato,
  periodo,
  valor_base,
  valor_desconto,
  (valor_base - valor_desconto) AS valor_final
FROM mensalidade;
