-- ============================================================
-- SCRIPT DE RESET — limpa tudo para execucao do zero
-- DROP DATABASE elimina todos os objetos de uma vez (tabelas,
-- views, triggers, indices). Nao precisa de USE nem de DROPs
-- individuais — e mais simples e funciona em MySQL limpo.
-- ============================================================

-- FK_CHECKS off para evitar conflito de ordem entre bancos
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS erp_escolar_olap;
DROP DATABASE IF EXISTS erp_escolar;

SET FOREIGN_KEY_CHECKS = 1;
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
INSERT INTO status_mensalidade (status) VALUES ('Pendente'), ('Pago'), ('Atrasado'), ('Cancelado'), ('Parcial');
-- Parcial: pagamento registrado mas valor ainda nao cobre o total da mensalidade

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
  data_solicitacao DATE          NOT NULL,
  PRIMARY KEY (fk_id_periodo),
  CONSTRAINT chk_abono_dias  CHECK (dias_vendidos >= 1 AND dias_vendidos <= 10),
  CONSTRAINT chk_abono_valor CHECK (valor > 0),
  CONSTRAINT fk_abono_periodo FOREIGN KEY (fk_id_periodo)
    REFERENCES periodo_aquisitivo(pk_id_periodo) ON DELETE RESTRICT ON UPDATE CASCADE
);


-- Relacionamento simetrico entre funcionarios casados ou em uniao estavel
-- CHECK (fk_rgf_1 < fk_rgf_2) elimina o par invertido (A,B) != (B,A)
-- RN: empresa permite conjuges mas proibe relacao hierarquica direta (verificar via aplicacao)
CREATE TABLE conjuge_funcionario (
  fk_rgf_1   CHAR(5)     NOT NULL,
  fk_rgf_2   CHAR(5)     NOT NULL,
  tipo_uniao VARCHAR(20) NOT NULL,
  data_uniao DATE        NOT NULL,
  PRIMARY KEY (fk_rgf_1, fk_rgf_2),
  CONSTRAINT chk_conjuge_distintos CHECK (fk_rgf_1 != fk_rgf_2),
  CONSTRAINT chk_conjuge_ordem     CHECK (fk_rgf_1 < fk_rgf_2),
  CONSTRAINT chk_conjuge_tipo      CHECK (tipo_uniao IN ('Casamento', 'Uniao Estavel')),
  CONSTRAINT fk_conjuge_func1 FOREIGN KEY (fk_rgf_1)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT fk_conjuge_func2 FOREIGN KEY (fk_rgf_2)
    REFERENCES funcionario(rgf) ON DELETE RESTRICT ON UPDATE RESTRICT
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

-- pk surrogate: (fk_id_turma, nome_atividade) seria chave natural candidata,
-- mas o surrogate evita FK de 2 campos em nota e simplifica referenciar a avaliacao
-- UNIQUE garante que o nome e de fato unico dentro de cada turma (chave candidata)
CREATE TABLE avaliacao (
  pk_id_avaliacao INT          NOT NULL AUTO_INCREMENT,
  fk_id_turma     INT          NOT NULL,
  nome_atividade  VARCHAR(60)  NOT NULL,
  peso            DECIMAL(4,2) NOT NULL,
  data_aplicacao  DATE,
  PRIMARY KEY (pk_id_avaliacao),
  CONSTRAINT uq_aval_turma_nome UNIQUE (fk_id_turma, nome_atividade),
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
  CONSTRAINT chk_nota_valor CHECK (nota_atividade >= 0 AND nota_atividade <= 10),
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
  ELSE
    -- Primeiro registro de ponto do funcionario deve obrigatoriamente ser Entrada
    IF NEW.tipo != 'Entrada' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Primeiro registro de ponto deve ser Entrada.';
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
  ELSE
    -- Primeiro registro de ponto do funcionario deve obrigatoriamente ser Entrada
    IF NEW.tipo != 'Entrada' THEN
      SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Primeiro registro de ponto deve ser Entrada.';
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

-- TR_matricula_turma_curso: aluno nao pode ser inserido em turma de curso diferente da sua matricula
-- UNIQUE parcial nao disponivel no MySQL; regra implementada via trigger
DELIMITER $$
CREATE TRIGGER TR_matricula_turma_curso_insert
BEFORE INSERT ON matricula_turma
FOR EACH ROW
BEGIN
  DECLARE curso_matricula CHAR(3);
  DECLARE curso_turma     CHAR(3);
  SELECT fk_curso INTO curso_matricula FROM matricula WHERE pk_id_matricula = NEW.fk_id_matricula;
  SELECT fk_curso INTO curso_turma     FROM turma     WHERE pk_id_turma     = NEW.fk_id_turma;
  IF curso_matricula != curso_turma THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Aluno nao pode ser matriculado em turma de curso diferente da sua matricula.';
  END IF;
END$$
DELIMITER ;

-- TR_turma_limite_alunos: capacidade maxima da turma nao pode ser ultrapassada
DELIMITER $$
CREATE TRIGGER TR_turma_limite_alunos_insert
BEFORE INSERT ON matricula_turma
FOR EACH ROW
BEGIN
  DECLARE alunos_atuais INT;
  DECLARE limite        INT;
  SELECT COUNT(*)      INTO alunos_atuais FROM matricula_turma WHERE fk_id_turma = NEW.fk_id_turma;
  SELECT limite_alunos INTO limite        FROM turma           WHERE pk_id_turma  = NEW.fk_id_turma;
  IF alunos_atuais >= limite THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Turma atingiu o limite maximo de alunos.';
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


-- Atualiza mensalidade.status automaticamente apos cada pagamento registrado
-- 'Parcial': pagamento iniciado mas insuficiente para quitar o saldo devedor
-- 'Pago'   : soma dos pagamentos confirmados >= valor_liquido da mensalidade
-- Resolve o cenario de pagamento parcelado sem precisar de UPDATE manual na aplicacao
--
-- LIMITACAO MySQL (ERROR 1442): este trigger nao pode executar quando o INSERT em
-- pagamento e feito via "INSERT ... SELECT FROM mensalidade", pois o MySQL proibe
-- UPDATE na mesma tabela que a instrucao pai esta lendo na mesma execucao.
-- Em uso normal da aplicacao (INSERT com VALUES explicitos, um pagamento por vez),
-- o trigger funciona corretamente sem nenhuma restricao.
-- Workaround para scripts ETL/bulk: ler de contrato+matricula para montar o INSERT
-- em pagamento — nunca fazer SELECT FROM mensalidade como fonte do INSERT.
DELIMITER $$
CREATE TRIGGER TR_pagamento_quita_mensalidade_insert
AFTER INSERT ON pagamento
FOR EACH ROW
BEGIN
    DECLARE v_total_pago   DECIMAL(10,2);
    DECLARE v_valor_liquido DECIMAL(10,2);

    IF NEW.status = 'Pago' THEN
        SELECT COALESCE(SUM(p.valor_pago), 0)
        INTO v_total_pago
        FROM pagamento p
        WHERE p.fk_id_contrato = NEW.fk_id_contrato
          AND p.periodo        = NEW.periodo
          AND p.status         = 'Pago';

        SELECT (ms.valor_base - ms.valor_desconto)
        INTO v_valor_liquido
        FROM mensalidade ms
        WHERE ms.fk_id_contrato = NEW.fk_id_contrato
          AND ms.periodo        = NEW.periodo;

        IF v_total_pago >= v_valor_liquido THEN
            UPDATE mensalidade SET status = 'Pago'
            WHERE fk_id_contrato = NEW.fk_id_contrato AND periodo = NEW.periodo;
        ELSEIF v_total_pago > 0 THEN
            UPDATE mensalidade SET status = 'Parcial'
            WHERE fk_id_contrato = NEW.fk_id_contrato AND periodo = NEW.periodo;
        END IF;
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
  SUM(n.nota_atividade * a.peso) / NULLIF(SUM(a.peso), 0) AS nota_final
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

-- Resumo de inadimplencia por aluno: meses em aberto e total devedor
-- valor_em_aberto = valor_liquido das mensalidades Pendente/Atrasado sem pagamento integral
CREATE VIEW vw_inadimplencia AS
SELECT
  CONCAT(a.nome, ' ', a.sobrenome)         AS aluno,
  c.nome_curso,
  COUNT(ms.periodo)                        AS meses_em_aberto,
  SUM(ms.valor_base - ms.valor_desconto)   AS total_em_aberto,
  MIN(ms.data_vencimento)                  AS vencimento_mais_antigo
FROM mensalidade ms
JOIN contrato  ct ON ct.pk_id_contrato  = ms.fk_id_contrato
JOIN matricula m  ON m.pk_id_matricula  = ct.fk_id_matricula
JOIN aluno     a  ON a.rga              = m.fk_rga
JOIN curso     c  ON c.codigo_curso     = m.fk_curso
WHERE ms.status IN ('Pendente', 'Atrasado')
GROUP BY a.rga, c.codigo_curso
ORDER BY total_em_aberto DESC;

-- Identifica funcionarios que tambem sao alunos da instituicao
-- Link via CPF (unico em ambas as tabelas)
-- Util para gestao de beneficios (desconto de funcionario) e conflitos de interesse
CREATE VIEW vw_funcionario_aluno AS
SELECT
  f.rgf,
  a.rga,
  CONCAT(f.nome, ' ', f.sobrenome) AS nome_completo,
  cg.nome_cargo,
  cg.nome_departamento,
  c.nome_curso,
  m.ano_ingresso,
  m.status AS status_matricula
FROM funcionario f
JOIN aluno     a  ON a.cpf           = f.cpf
JOIN matricula m  ON m.fk_rga        = a.rga AND m.status = 'Cursando'
JOIN cargo     cg ON cg.codigo_cargo = f.codigo_cargo
JOIN curso     c  ON c.codigo_curso  = m.fk_curso
WHERE f.status IN ('Ativo', 'Afastado');
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

-- Q05: Pares de conjuges na empresa com seus respectivos departamentos
-- RN: empresa permite conjuges, mas relacao hierarquica direta deve ser monitorada
SELECT
    CONCAT(f1.nome, ' ', f1.sobrenome) AS conjuge_1,
    cg1.nome_cargo                     AS cargo_1,
    cg1.nome_departamento              AS depto_1,
    cf.tipo_uniao,
    CONCAT(f2.nome, ' ', f2.sobrenome) AS conjuge_2,
    cg2.nome_cargo                     AS cargo_2,
    cg2.nome_departamento              AS depto_2,
    CASE WHEN cg1.nome_departamento = cg2.nome_departamento
         THEN 'ALERTA: mesmo depto' ELSE 'OK' END AS situacao
FROM conjuge_funcionario cf
JOIN funcionario f1  ON f1.rgf          = cf.fk_rgf_1
JOIN funcionario f2  ON f2.rgf          = cf.fk_rgf_2
JOIN cargo       cg1 ON cg1.codigo_cargo = f1.codigo_cargo
JOIN cargo       cg2 ON cg2.codigo_cargo = f2.codigo_cargo
ORDER BY cf.data_uniao;

-- ============================================================
-- BLOCO 2: Subselects com agregacao
-- ============================================================

-- Q06: Total pago por aluno no ano de 2024 (soma de pagamentos confirmados)
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

-- Q07: Nota final por aluno por turma (media ponderada via view)
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

-- Q08: Quantidade de alunos matriculados por curso
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

-- Q09: Funcionarios com salario acima da media geral de salarios ativos
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

-- Q10: Alunos com percentual de presenca abaixo de 75% em alguma turma
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

-- Q11: Cursos cuja receita mensal media supera a media geral de todos os cursos
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

-- Q12: Professores que ministram mais de uma materia no semestre 2024/1
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

-- Q13: Anomalia academica — frequencia abaixo do minimo legal com nota acima da media da turma
-- Levanta casos que merecem investigacao: compensacao por desempenho? inconsistencia de registro?
-- util para o coordenador identificar alunos que podem precisar de atestado medico retroativo
SELECT
    CONCAT(a.nome, ' ', a.sobrenome) AS aluno,
    mat.nome_materia,
    ROUND(freq.pct_frequencia, 1)    AS frequencia_pct,
    ROUND(nf.nota_final, 2)          AS nota_individual,
    ROUND(media_t.media_turma, 2)    AS media_turma,
    ROUND(nf.nota_final - media_t.media_turma, 2) AS desvio_acima_da_media
FROM vw_nota_final nf
JOIN (
    SELECT
        fk_id_matricula,
        fk_id_turma,
        ROUND(SUM(presente) / COUNT(*) * 100, 1) AS pct_frequencia
    FROM frequencia
    GROUP BY fk_id_matricula, fk_id_turma
) freq ON freq.fk_id_matricula = nf.fk_id_matricula
       AND freq.fk_id_turma    = nf.fk_id_turma
JOIN (
    SELECT fk_id_turma, AVG(nota_final) AS media_turma
    FROM vw_nota_final
    GROUP BY fk_id_turma
) media_t ON media_t.fk_id_turma = nf.fk_id_turma
JOIN matricula m   ON m.pk_id_matricula = nf.fk_id_matricula
JOIN aluno     a   ON a.rga             = m.fk_rga
JOIN turma     t   ON t.pk_id_turma     = nf.fk_id_turma
JOIN materia   mat ON mat.codigo_materia = t.fk_materia
WHERE freq.pct_frequencia < 75
  AND nf.nota_final > media_t.media_turma
ORDER BY desvio_acima_da_media DESC;
-- SUM(presente) funciona porque presente e BOOLEAN (TRUE=1, FALSE=0) no MySQL

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

-- Q15: Pagamentos realizados a vista — cabecalho + mensalidades cobertas
-- Demonstra o fluxo alternativo ao pagamento recorrente:
-- pagamento_a_vista (transacao unica) vinculado a N mensalidades via N:N
SELECT
    CONCAT(a.nome, ' ', a.sobrenome)                               AS aluno,
    c.nome_curso,
    pav.pk_id_avista                                               AS id_avista,
    pav.metodo,
    pav.data_pagamento,
    pav.valor_total,
    pav.status                                                     AS status_avista,
    GROUP_CONCAT(pam.periodo ORDER BY pam.periodo SEPARATOR ', ')  AS periodos_quitados,
    COUNT(pam.periodo)                                             AS qtd_mensalidades
FROM pagamento_a_vista             pav
JOIN contrato                      ct  ON ct.pk_id_contrato  = pav.fk_id_contrato
JOIN matricula                     m   ON m.pk_id_matricula  = ct.fk_id_matricula
JOIN aluno                         a   ON a.rga              = m.fk_rga
JOIN curso                         c   ON c.codigo_curso     = m.fk_curso
JOIN pagamento_avista_mensalidade  pam ON pam.fk_id_avista   = pav.pk_id_avista
GROUP BY pav.pk_id_avista
ORDER BY pav.data_pagamento;

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
-- RGA A0000009 nao existe no DML (dados vao de A0000001 a A0000008)
-- ----------------------------------------------------------

SELECT COUNT(*) AS total_alunos_antes FROM aluno;

START TRANSACTION;

INSERT INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES ('A0000009', '99999999901', 'Aluno', 'Rollback', '2000-01-01', 'Ativo');

-- erro detectado antes do commit (ex: documentacao pendente)
ROLLBACK;

-- validacao: registro NAO deve existir apos ROLLBACK
SELECT COUNT(*) AS total_alunos_apos_rollback FROM aluno;
-- resultado esperado: mesmo valor do total_alunos_antes

SELECT rga FROM aluno WHERE rga = 'A0000009';
-- resultado esperado: 0 linhas — atomicidade garantida

-- ----------------------------------------------------------
-- Cenario 2: COMMIT — confirmando uma operacao valida
-- Mesmo INSERT, agora confirmado com COMMIT
-- ----------------------------------------------------------

START TRANSACTION;

INSERT INTO aluno (rga, cpf, nome, sobrenome, data_nascimento, status)
VALUES ('A0000009', '99999999901', 'Aluno', 'Commit', '2000-01-01', 'Ativo');

COMMIT;

-- validacao: registro DEVE existir apos COMMIT
SELECT rga, nome, sobrenome, status
FROM aluno
WHERE rga = 'A0000009';
-- resultado esperado: 1 linha — durabilidade confirmada

-- limpeza do registro de teste
DELETE FROM aluno WHERE rga = 'A0000009';

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
  pk_id_tempo  INT         NOT NULL COMMENT 'YYYYMM — chave natural do periodo',
  ano          YEAR        NOT NULL,
  mes          TINYINT     NOT NULL,
  nome_mes     VARCHAR(20) NOT NULL,
  trimestre    TINYINT     NOT NULL,
  semestre     TINYINT     NOT NULL,
  PRIMARY KEY (pk_id_tempo),
  CONSTRAINT chk_dt_mes  CHECK (mes BETWEEN 1 AND 12),
  CONSTRAINT chk_dt_trim CHECK (trimestre BETWEEN 1 AND 4),
  CONSTRAINT chk_dt_sem  CHECK (semestre BETWEEN 1 AND 2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO ALUNO
-- Surrogate: rga e chave natural no OLTP mas o star schema
-- usa surrogate para isolar do OLTP e permitir SCD futura
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_aluno (
  pk_id_aluno   INT          NOT NULL AUTO_INCREMENT,
  rga           CHAR(8)      NOT NULL,
  nome_completo VARCHAR(202) NOT NULL,
  ano_ingresso  YEAR         NOT NULL,
  curso_ingresso CHAR(3)     NOT NULL COMMENT 'curso no momento da matricula (snapshot)',
  PRIMARY KEY (pk_id_aluno),
  UNIQUE KEY uq_da_rga (rga)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO CURSO
-- Surrogate: codigo_curso e CHAR(3) — bom para FK no OLTP,
-- mas star schema padroniza surrogate em todas as dims
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_curso (
  pk_id_curso   INT         NOT NULL AUTO_INCREMENT,
  codigo_curso  CHAR(3)     NOT NULL,
  nome_curso    VARCHAR(100) NOT NULL,
  nivel_ensino  VARCHAR(30) NOT NULL,
  PRIMARY KEY (pk_id_curso),
  UNIQUE KEY uq_dc_codigo (codigo_curso)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO UNIDADE
-- Representa a area academica que agrupa os cursos.
-- Permite analise por grande area sem depender de curso especifico.
-- Surrogate: sem chave natural clara no OLTP (nao ha tabela unidade)
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_unidade (
  pk_id_unidade INT         NOT NULL AUTO_INCREMENT,
  nome_unidade  VARCHAR(60) NOT NULL,
  PRIMARY KEY (pk_id_unidade),
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
  fk_id_tempo     INT            NOT NULL,
  fk_id_aluno     INT            NOT NULL,
  fk_id_curso     INT            NOT NULL,
  fk_id_unidade   INT            NOT NULL,
  -- metricas financeiras (snapshot do momento da geracao da mensalidade)
  valor_base      DECIMAL(10,2)  NOT NULL,
  valor_desconto  DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  valor_liquido   DECIMAL(10,2)  NOT NULL COMMENT 'valor_base - valor_desconto',
  valor_pago      DECIMAL(10,2)  NOT NULL DEFAULT 0.00 COMMENT '0 se nao quitada',
  -- flags analiticas (degenerate dimensions)
  status_mensalidade VARCHAR(10) NOT NULL,
  tem_bolsa       TINYINT(1)     NOT NULL DEFAULT 0,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_ft_tempo    FOREIGN KEY (fk_id_tempo)   REFERENCES dim_tempo(pk_id_tempo),
  CONSTRAINT fk_ft_aluno    FOREIGN KEY (fk_id_aluno)   REFERENCES dim_aluno(pk_id_aluno),
  CONSTRAINT fk_ft_curso    FOREIGN KEY (fk_id_curso)   REFERENCES dim_curso(pk_id_curso),
  CONSTRAINT fk_ft_unidade  FOREIGN KEY (fk_id_unidade) REFERENCES dim_unidade(pk_id_unidade)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO MATERIA
-- Surrogate: star schema padroniza surrogate em todas as dims
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_materia (
  pk_id_materia  INT         NOT NULL AUTO_INCREMENT,
  codigo_materia CHAR(5)     NOT NULL,
  nome_materia   VARCHAR(60) NOT NULL,
  carga_horaria  INT         NOT NULL,
  PRIMARY KEY (pk_id_materia),
  UNIQUE KEY uq_dm_codigo (codigo_materia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- DIMENSAO FUNCIONARIO
-- Surrogate: isolamento do OLTP e consistencia com demais dims
-- Snapshot dos atributos descritivos no momento da carga
-- ============================================================
CREATE TABLE IF NOT EXISTS dim_funcionario (
  pk_id_funcionario INT          NOT NULL AUTO_INCREMENT,
  rgf               CHAR(5)      NOT NULL,
  nome_completo     VARCHAR(101) NOT NULL,
  codigo_cargo      CHAR(3)      NOT NULL,
  nome_cargo        VARCHAR(120) NOT NULL,
  nome_departamento VARCHAR(100) NOT NULL,
  nivel_cargo       VARCHAR(10)  NOT NULL,
  data_admissao     DATE         NOT NULL,
  PRIMARY KEY (pk_id_funcionario),
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
  fk_id_aluno         INT            NOT NULL,
  fk_id_curso         INT            NOT NULL,
  fk_id_materia       INT            NOT NULL,
  ano_letivo          YEAR           NOT NULL,
  semestre_letivo     TINYINT        NOT NULL COMMENT '1 ou 2',
  -- metricas academicas
  nota_final          DECIMAL(4,2)   COMMENT 'media ponderada; NULL se sem avaliacao registrada',
  total_aulas         INT            NOT NULL DEFAULT 0,
  total_presencas     INT            NOT NULL DEFAULT 0,
  percentual_presenca DECIMAL(5,2)   NOT NULL DEFAULT 0.00,
  status_turma        VARCHAR(20)    NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fda_aluno   FOREIGN KEY (fk_id_aluno)   REFERENCES dim_aluno(pk_id_aluno),
  CONSTRAINT fk_fda_curso   FOREIGN KEY (fk_id_curso)   REFERENCES dim_curso(pk_id_curso),
  CONSTRAINT fk_fda_materia FOREIGN KEY (fk_id_materia) REFERENCES dim_materia(pk_id_materia),
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
  fk_id_funcionario INT            NOT NULL,
  fk_id_tempo       INT            NOT NULL,
  -- metricas (snapshot do mes processado)
  salario_bruto     DECIMAL(10,2)  NOT NULL,
  total_proventos   DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  total_descontos   DECIMAL(10,2)  NOT NULL DEFAULT 0.00,
  salario_liquido   DECIMAL(10,2)  NOT NULL,
  status_folha      VARCHAR(20)    NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_ffr_func  FOREIGN KEY (fk_id_funcionario) REFERENCES dim_funcionario(pk_id_funcionario),
  CONSTRAINT fk_ffr_tempo FOREIGN KEY (fk_id_tempo)       REFERENCES dim_tempo(pk_id_tempo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABELA FATO — ft_movimentacao_rh
-- Grain: 1 linha por evento de admissao ou desligamento
-- Permite analise de turnover: headcount, tempo medio de empresa
-- ============================================================
CREATE TABLE IF NOT EXISTS ft_movimentacao_rh (
  pk_id_fato        INT          NOT NULL AUTO_INCREMENT,
  fk_id_funcionario INT          NOT NULL,
  fk_id_tempo       INT          NOT NULL COMMENT 'mes do evento (YYYYMM)',
  tipo_movimentacao VARCHAR(20)  NOT NULL COMMENT 'Admissao | Desligamento',
  dias_empresa      INT          NOT NULL DEFAULT 0 COMMENT '0 na admissao; DATEDIFF na saida',
  data_evento       DATE         NOT NULL,
  PRIMARY KEY (pk_id_fato),
  CONSTRAINT fk_fmr_func  FOREIGN KEY (fk_id_funcionario) REFERENCES dim_funcionario(pk_id_funcionario),
  CONSTRAINT fk_fmr_tempo FOREIGN KEY (fk_id_tempo)       REFERENCES dim_tempo(pk_id_tempo),
  CONSTRAINT chk_fmr_tipo CHECK (tipo_movimentacao IN ('Admissao', 'Desligamento'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
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
INSERT INTO erp_escolar_olap.dim_tempo (pk_id_tempo, ano, mes, nome_mes, trimestre, semestre)
SELECT DISTINCT
    p.periodo_num                                                     AS pk_id_tempo,
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
    (fk_id_aluno, fk_id_curso, fk_id_materia, ano_letivo, semestre_letivo,
     nota_final, total_aulas, total_presencas, percentual_presenca, status_turma)
SELECT
    da.pk_id_aluno,
    dc.pk_id_curso,
    dm.pk_id_materia,
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
ORDER BY ca.ano, ca.semestre, da.pk_id_aluno;

-- ============================================================
-- STEP 9: ft_folha_rh
-- Grain: 1 linha por (funcionario, periodo mensal)
-- salario_liquido = bruto + proventos - descontos (snapshot OLAP)
-- ============================================================
INSERT INTO erp_escolar_olap.ft_folha_rh
    (fk_id_funcionario, fk_id_tempo, salario_bruto,
     total_proventos, total_descontos, salario_liquido, status_folha)
SELECT
    df.pk_id_funcionario,
    CAST(REPLACE(fp.periodo, '-', '') AS UNSIGNED)                                          AS fk_id_tempo,
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
GROUP BY df.pk_id_funcionario, fp.fk_rgf, fp.periodo, fp.salario_bruto, fp.status
ORDER BY fp.periodo, fp.fk_rgf;

-- ============================================================
-- STEP 10: ft_movimentacao_rh
-- Grain: 1 linha por evento de admissao ou desligamento
-- Permite calculo de headcount, tempo medio de empresa, turnover
-- ============================================================
INSERT INTO erp_escolar_olap.ft_movimentacao_rh
    (fk_id_funcionario, fk_id_tempo, tipo_movimentacao, dias_empresa, data_evento)
SELECT
    df.pk_id_funcionario,
    CAST(DATE_FORMAT(f.data_admissao, '%Y%m') AS UNSIGNED) AS fk_id_tempo,
    'Admissao'                                             AS tipo_movimentacao,
    0                                                      AS dias_empresa,
    f.data_admissao                                        AS data_evento
FROM erp_escolar.funcionario          f
JOIN erp_escolar_olap.dim_funcionario df ON df.rgf = f.rgf

UNION ALL

SELECT
    df.pk_id_funcionario,
    CAST(DATE_FORMAT(f.data_desligamento, '%Y%m') AS UNSIGNED) AS fk_id_tempo,
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
    ON erp_escolar_olap.ft_receita_mensalidade (fk_id_tempo);

CREATE INDEX idx_ft_curso_tempo
    ON erp_escolar_olap.ft_receita_mensalidade (fk_id_curso, fk_id_tempo);

CREATE INDEX idx_ft_status
    ON erp_escolar_olap.ft_receita_mensalidade (status_mensalidade);

-- OLAP — ft_desempenho_academico
-- filtros mais comuns: aluno, materia, semestre
CREATE INDEX idx_fda_aluno_materia
    ON erp_escolar_olap.ft_desempenho_academico (fk_id_aluno, fk_id_materia);

CREATE INDEX idx_fda_curso_ano
    ON erp_escolar_olap.ft_desempenho_academico (fk_id_curso, ano_letivo, semestre_letivo);

-- OLAP — ft_folha_rh
-- filtros por tempo (mes) e funcionario para relatorios de folha
CREATE INDEX idx_ffr_tempo
    ON erp_escolar_olap.ft_folha_rh (fk_id_tempo);

CREATE INDEX idx_ffr_funcionario
    ON erp_escolar_olap.ft_folha_rh (fk_id_funcionario);

-- OLAP — ft_movimentacao_rh
-- filtros por tipo de evento e periodo para analise de turnover
CREATE INDEX idx_fmr_tipo_tempo
    ON erp_escolar_olap.ft_movimentacao_rh (tipo_movimentacao, fk_id_tempo);

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
JOIN dim_materia              dm  ON dm.pk_id_materia = fda.fk_id_materia
JOIN dim_curso                dc  ON dc.pk_id_curso   = fda.fk_id_curso
WHERE fda.nota_final IS NOT NULL
GROUP BY dm.pk_id_materia, dc.pk_id_curso
ORDER BY nota_media ASC;

-- 6E: Custo total de folha por mes e por departamento
-- Responde: qual departamento pesa mais na folha? Como evoluiu mensalmente?
SELECT
    dt.nome_mes,
    dt.ano,
    df.nome_departamento,
    COUNT(DISTINCT ff.fk_id_funcionario)  AS funcionarios,
    SUM(ff.salario_bruto)                 AS total_bruto,
    SUM(ff.total_proventos)               AS total_proventos,
    SUM(ff.total_descontos)               AS total_descontos,
    SUM(ff.salario_liquido)               AS total_liquido
FROM ft_folha_rh      ff
JOIN dim_tempo        dt ON dt.pk_id_tempo        = ff.fk_id_tempo
JOIN dim_funcionario  df ON df.pk_id_funcionario  = ff.fk_id_funcionario
GROUP BY dt.pk_id_tempo, df.nome_departamento
ORDER BY dt.pk_id_tempo, total_bruto DESC;

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
JOIN dim_tempo          dt ON dt.pk_id_tempo = fm.fk_id_tempo
GROUP BY dt.pk_id_tempo
ORDER BY dt.pk_id_tempo;
