# Dicionário de Dados — SisGESC (ERP Escolar)

Sistema de gestão escolar com três módulos: RH, Acadêmico e Financeiro.
Dialeto: MySQL 8+ · Charset: utf8mb4_unicode_ci · Schema: `erp_escolar`

---

## Tabelas de Apoio (Domínio)

Todas seguem o mesmo padrão: PK = o próprio valor VARCHAR. Sem surrogate, sem id. Uma tabela por contexto semântico para que o banco rejeite valores inválidos via FK.

| Tabela | PK | Valores |
|---|---|---|
| `status_aluno` | status | Ativo, Inativo |
| `status_matricula` | status | Cursando, Concluido, Trancado, Cancelado |
| `status_matricula_turma` | status | Cursando, Aprovado, Reprovado |
| `status_funcionario` | status | Ativo, Afastado, Desligado |
| `status_contrato` | status | Ativo, Encerrado, Suspenso, Cancelado |
| `status_mensalidade` | status | Pendente, Pago, Atrasado, Cancelado |
| `status_pagamento` | status | Pendente, Pago, Cancelado |
| `status_ferias` | status | Planejada, Em andamento, Concluida, Cancelada |
| `status_folha` | status | Em processamento, Paga, Cancelada |
| `turno` | turno | Manha, Tarde, Noite |
| `tipo_conta_bancaria` | tipo | Corrente, Poupanca, Salario |
| `tipo_ocorrencia` | tipo | Atraso, Falta, Saida antecipada |
| `tipo_parentesco` | tipo | Conjuge, Filho Biologico, Filho Adotivo, etc. |
| `tipo_evento_folha` | tipo | Provento, Desconto |
| `nivel_cargo` | nivel | Junior, Pleno, Senior |
| `tipo_ponto` | tipo | Entrada, Saida, Intervalo, Retorno intervalo |
| `metodo_pagamento` | metodo | Pix, Boleto, Cartao, Transferencia, Dinheiro |
| `nivel_ensino` | nivel | Tecnico, Tecnologo, Bacharelado, Pos-Graduacao |

---

## Módulo RH

### `departamento`
Unidade administrativa da instituição.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `nome_departamento` | VARCHAR(100) | PK | Nome identifica univocamente o depto. PK natural. |
| `descricao` | TEXT | NULL | Descrição livre. |
| `ativo` | BOOLEAN | NOT NULL, DEFAULT TRUE | Soft delete. |

---

### `cargo`
Cargo com nível hierárquico e salário de referência.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `codigo_cargo` | CHAR(3) | PK | Código alfanumérico estável. PK natural. |
| `nome_cargo` | VARCHAR(120) | NOT NULL | |
| `nome_departamento` | VARCHAR(100) | FK → departamento | |
| `nivel` | VARCHAR(10) | FK → nivel_cargo | Junior / Pleno / Senior. |
| `salario_base` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Referência para o cargo, não o salário real do funcionário. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `evento_folha`
Catálogo de eventos que compõem a folha (proventos e descontos).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `nome_evento` | VARCHAR(50) | PK | Ex: "INSS", "Vale Refeicao". |
| `tipo` | VARCHAR(20) | FK → tipo_evento_folha | Provento ou Desconto. |

---

### `funcionario`
Entidade central do módulo RH.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `rgf` | CHAR(5) | PK | Registro Geral de Funcionário. Natural, estável, controlado internamente. |
| `cpf` | CHAR(11) | NOT NULL, UNIQUE, CHECK regex | Apenas dígitos. |
| `nome` | VARCHAR(50) | NOT NULL | Atomizado (1FN): nome e sobrenome em colunas separadas. |
| `sobrenome` | VARCHAR(50) | NOT NULL | |
| `data_nascimento` | DATE | NOT NULL | |
| `codigo_cargo` | CHAR(3) | FK → cargo | Cargo atual. Histórico em `historico_salario`. |
| `data_admissao` | DATE | NOT NULL, CHECK > data_nascimento | |
| `data_desligamento` | DATE | NULL | NULL = ainda ativo. |
| `status` | VARCHAR(20) | FK → status_funcionario | |
| `data_criacao` | DATETIME | DEFAULT NOW() | Auditoria básica. |
| `ultima_atualizacao` | DATETIME | DEFAULT NOW() | |

---

### `professor`
Papel exercido por um funcionário. PK herdada de `funcionario` — relação 1:1.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_rgf` | CHAR(5) | PK, FK → funcionario | Herda a identidade do funcionário. |
| `formacao` | VARCHAR(100) | NOT NULL | |
| `especialidade` | VARCHAR(100) | NOT NULL | |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `documentos_trabalhistas`
Documentação legal do vínculo empregatício. 1:1 com `funcionario`.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_rgf` | CHAR(5) | PK, FK → funcionario | |
| `pis` | CHAR(11) | NOT NULL, UNIQUE, CHECK regex | |
| `numero_ctps` | CHAR(7) | NOT NULL, UNIQUE | |
| `serie_ctps` | CHAR(4) | NOT NULL | |
| `titulo_eleitor` | CHAR(12) | NOT NULL, UNIQUE | |

---

### `dependente`
Dependentes do funcionário para IR e plano de saúde.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `rgd` | CHAR(5) | PK | Registro do dependente. Natural, controlado internamente. |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `cpf` | CHAR(11) | NOT NULL, UNIQUE | |
| `nome` / `sobrenome` | VARCHAR(50) | NOT NULL | Atomizado. |
| `data_nascimento` | DATE | NOT NULL | |
| `parentesco` | VARCHAR(30) | FK → tipo_parentesco | |
| `dependente_ir` | BOOLEAN | NOT NULL | Dedução de IR. |
| `dependente_plano_saude` | BOOLEAN | NOT NULL | |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `conta_banco_funcionario`
Contas para depósito de salário. Um funcionário pode ter mais de uma; apenas uma é `principal = TRUE`.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_conta` | INT | PK surrogate | Sem chave natural clara. Composta seria (fk_rgf, banco, agencia, conta) — 4+ campos, surrogate preferível. |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `banco` | VARCHAR(50) | NOT NULL | |
| `agencia` | VARCHAR(10) | NOT NULL | |
| `conta` | VARCHAR(15) | NOT NULL | |
| `digito_conta` | CHAR(1) | NOT NULL | |
| `tipo_conta` | VARCHAR(20) | FK → tipo_conta_bancaria | |
| `principal` | BOOLEAN | NOT NULL | Regra: apenas uma conta principal ativa por funcionário. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `ponto`
Registros de entrada/saída. Trigger garante alternância obrigatória (Entrada → Saída → Entrada…).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_ponto` | INT | PK surrogate AUTO_INCREMENT | |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `data_hora` | DATETIME | NOT NULL | |
| `tipo` | VARCHAR(30) | FK → tipo_ponto | Entrada, Saida, Intervalo, Retorno intervalo. |

---

### `ocorrencia_desconto`
Registros de atraso, falta e saída antecipada usados na composição da folha.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_ocorrencia` | INT | PK surrogate | |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `tipo_ocorrencia` | VARCHAR(30) | FK → tipo_ocorrencia | |
| `data_ocorrencia` | DATE | NOT NULL | |
| `minutos` | INT | NOT NULL, CHECK > 0 | Tempo da ocorrência em minutos. |

---

### `folha_pagamentos`
Cabeçalho da folha mensal por funcionário.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_rgf` | CHAR(5) | PK composta + FK → funcionario | |
| `periodo` | CHAR(7) | PK composta | Formato YYYY-MM. |
| `salario_bruto` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Snapshot do salário bruto do mês. |
| `data_pagamento` | DATE | NOT NULL | |
| `status` | VARCHAR(20) | FK → status_folha | |

**PK composta:** (fk_rgf, periodo) — identidade natural, sem necessidade de surrogate.

---

### `folha_evento`
Linha de detalhe da folha: um evento por funcionário por período. Valor sempre positivo — o sinal é determinado por `evento_folha.tipo`.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_rgf` | CHAR(5) | PK + FK → folha_pagamentos | |
| `periodo` | CHAR(7) | PK | |
| `nome_evento` | VARCHAR(50) | PK + FK → evento_folha | |
| `valor` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Sempre positivo. |

---

### `folha_ocorrencia`
Associa ocorrências de desconto à folha do mês em que foram computadas.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_rgf` | CHAR(5) | PK | |
| `periodo` | CHAR(7) | PK | |
| `pk_id_ocorrencia` | INT | PK + FK → ocorrencia_desconto | |

---

### `historico_salario`
Histórico de alterações salariais. `data_fim IS NULL` = salário vigente.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_historico` | INT | PK surrogate | Surrogate porque a composta (fk_rgf, data_inicio) seria FK em outras tabelas. |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `salario` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | |
| `data_inicio` | DATE | NOT NULL | |
| `data_fim` | DATE | NULL | NULL = vigente. Trigger garante apenas um registro vigente. |
| `motivo_alteracao` | VARCHAR(100) | NULL | |

---

### `periodo_aquisitivo`
Período de 12 meses que gera direito a férias.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_periodo` | INT | PK surrogate | |
| `fk_rgf` | CHAR(5) | FK → funcionario | |
| `data_inicio` | DATE | NOT NULL | |
| `data_fim` | DATE | NOT NULL | |
| `dias_direito` | INT | NOT NULL, CHECK > 0 | Normalmente 30. |

---

### `ferias`
Período de gozo vinculado a um período aquisitivo.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_ferias` | INT | PK surrogate | |
| `fk_id_periodo` | INT | FK → periodo_aquisitivo | |
| `data_inicio` | DATE | NOT NULL | Trigger: deve estar dentro do período aquisitivo. |
| `data_fim` | DATE | NOT NULL | |
| `status` | VARCHAR(20) | FK → status_ferias | |

---

## Módulo Acadêmico

### `curso`
Curso oferecido pela instituição.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `codigo_curso` | CHAR(3) | PK | Natural, estável, controlado internamente. Ex: ADS, ENF, LOG. |
| `nome_curso` | VARCHAR(100) | NOT NULL, UNIQUE | |
| `descricao` | TEXT | NULL | |
| `nivel_ensino` | VARCHAR(20) | FK → nivel_ensino | Tecnico, Tecnologo, Bacharelado, Pos-Graduacao. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `materia`
Disciplina catalogada independente de curso.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `codigo_materia` | CHAR(5) | PK | Natural, estável. Ex: BD001. |
| `nome_materia` | VARCHAR(60) | NOT NULL, UNIQUE | |
| `carga_horaria` | INT | NOT NULL, CHECK > 0 | Em horas. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `curso_materia`
Grade curricular: N:N entre curso e matéria. PK composta — relação associativa pura.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `codigo_curso` | CHAR(3) | PK + FK → curso | |
| `codigo_materia` | CHAR(5) | PK + FK → materia | |
| `obrigatoria` | BOOLEAN | NOT NULL | |
| `semestre_recomendado` | INT | NULL, CHECK > 0 | Sugestão curricular. |

---

### `curso_materia_revisao`
Versão histórica da grade curricular. Permite rastrear alterações por período letivo sem sobrescrever `curso_materia`.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `codigo_curso` | CHAR(3) | PK | |
| `codigo_materia` | CHAR(5) | PK | |
| `ano` | YEAR | PK | |
| `semestre` | INT | PK, CHECK IN (1,2) | |
| `obrigatoria` | BOOLEAN | NOT NULL | |
| `semestre_recomendado` | INT | NULL | |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `calendario_academico`
Define os períodos letivos. `fk_curso NULL` = calendário institucional (vale para todos os cursos).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_calendario` | INT | PK surrogate | Surrogate porque `fk_curso` é nullable, o que inviabiliza PK composta. |
| `ano` | YEAR | NOT NULL | |
| `semestre` | INT | NOT NULL, CHECK IN (1,2) | |
| `data_inicio` | DATE | NOT NULL | |
| `data_fim` | DATE | NOT NULL, CHECK > data_inicio | |
| `descricao` | VARCHAR(100) | NULL | |
| `fk_curso` | CHAR(3) | NULL, FK → curso | NULL = institucional. Trigger garante unicidade do calendário institucional por ano/semestre. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `aluno`
Aluno matriculado na instituição.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `rga` | CHAR(8) | PK | Registro Geral do Aluno. Natural, estável. |
| `cpf` | CHAR(11) | NOT NULL, UNIQUE, CHECK regex | |
| `nome` / `sobrenome` | VARCHAR(50) | NOT NULL | Atomizado (1FN). |
| `data_nascimento` | DATE | NOT NULL | |
| `status` | VARCHAR(20) | FK → status_aluno | |

---

### `matricula`
Vínculo do aluno a um curso. Trigger impede dois registros "Cursando" para o mesmo aluno no mesmo curso.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_matricula` | INT | PK surrogate | Surrogate: será FK em contrato e outras tabelas. |
| `fk_rga` | CHAR(8) | FK → aluno | |
| `fk_curso` | CHAR(3) | FK → curso | |
| `data_matricula` | DATE | NOT NULL | |
| `status` | VARCHAR(20) | FK → status_matricula | |
| `ano_ingresso` | INT | NOT NULL | |

---

### `turma`
Oferta de uma matéria em um semestre por um professor.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_turma` | INT | PK surrogate | |
| `fk_rgf` | CHAR(5) | FK → professor | |
| `fk_curso` | CHAR(3) | FK → curso | |
| `fk_materia` | CHAR(5) | FK → materia | |
| `fk_id_calendario` | INT | FK → calendario_academico | |
| `turno` | VARCHAR(10) | FK → turno | |
| `limite_alunos` | INT | NOT NULL, CHECK > 0 | |

**UNIQUE:** (fk_curso, fk_materia, fk_id_calendario, turno) — impede turma duplicada.

---

### `matricula_turma`
N:N entre matrícula e turma. Controla em quais turmas o aluno está inscrito.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_id_matricula` | INT | PK + FK → matricula | |
| `fk_id_turma` | INT | PK + FK → turma | |
| `status` | VARCHAR(20) | FK → status_matricula_turma | |

---

### `avaliacao`
Atividade avaliativa de uma turma, com peso para média ponderada.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_avaliacao` | INT | PK surrogate | |
| `fk_id_turma` | INT | FK → turma | |
| `nome_atividade` | VARCHAR(60) | NOT NULL | Ex: "Prova 1", "Trabalho". |
| `peso` | DECIMAL(4,2) | NOT NULL, CHECK > 0 | |
| `data_aplicacao` | DATE | NULL | |

---

### `nota`
Nota do aluno em uma avaliação. PK composta — N:N entre avaliação e matrícula.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_id_avaliacao` | INT | PK + FK → avaliacao | |
| `fk_id_matricula` | INT | PK + FK → matricula | |
| `nota_atividade` | DECIMAL(4,2) | NOT NULL, CHECK >= 0 | |

**Trigger:** valida que a matrícula pertence à turma da avaliação.

---

### `frequencia`
Presença do aluno por aula. PK composta de três campos.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_id_matricula` | INT | PK + FK → matricula | |
| `fk_id_turma` | INT | PK + FK → turma | |
| `data_aula` | DATE | PK | |
| `presente` | BOOLEAN | NOT NULL | |
| `justificativa` | TEXT | NULL | Preenchida quando ausente com justificativa. |

---

## Módulo Financeiro

### `contrato`
Formaliza o acordo financeiro de uma matrícula. Um contrato por matrícula (UNIQUE fk_id_matricula).

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_contrato` | INT | PK surrogate | |
| `fk_id_matricula` | INT | NOT NULL, UNIQUE, FK → matricula | |
| `data_assinatura` | DATE | NOT NULL | |
| `data_inicio_vigencia` | DATE | NOT NULL, CHECK >= data_assinatura | |
| `data_fim_vigencia` | DATE | NULL | NULL = contrato aberto (ativo). |
| `valor_mensalidade_referencia` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Valor de tabela no momento da assinatura. |
| `status` | VARCHAR(20) | FK → status_contrato | |

---

### `bolsa`
Desconto percentual vinculado a um contrato com vigência definida.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_bolsa` | INT | PK surrogate | |
| `fk_id_contrato` | INT | FK → contrato | |
| `percentual` | DECIMAL(5,2) | CHECK 0 < x <= 100 | |
| `data_inicio` | DATE | NOT NULL | |
| `data_fim` | DATE | NULL | NULL = bolsa ativa. |
| `ativo` | BOOLEAN | NOT NULL | |

---

### `mensalidade`
Cobrança mensal gerada a partir do contrato. Snapshot financeiro intencional: `valor_base` e `valor_desconto` registram os valores no momento da geração, independente de alterações futuras no contrato ou bolsa.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_id_contrato` | INT | PK + FK → contrato | |
| `periodo` | CHAR(7) | PK | Formato YYYY-MM. CHECK regex. |
| `valor_base` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | Snapshot de `valor_mensalidade_referencia`. |
| `valor_desconto` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | Snapshot do desconto de bolsa vigente. |
| `data_vencimento` | DATE | NOT NULL | |
| `status` | VARCHAR(20) | FK → status_mensalidade | |

**View:** `vw_valor_mensalidade` calcula `valor_final = valor_base - valor_desconto` sob demanda.

---

### `atraso_mensalidade`
Registro de multa e juros calculados para mensalidades vencidas.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `fk_id_contrato` | INT | PK + FK → mensalidade | |
| `periodo` | CHAR(7) | PK | |
| `dias_atraso` | INT | NOT NULL, CHECK > 0 | |
| `valor_multa` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | |
| `valor_juros` | DECIMAL(10,2) | NOT NULL, CHECK >= 0 | |
| `data_calculo` | DATETIME | DEFAULT NOW() | |

---

### `pagamento`
Registro de quitação de uma mensalidade. Pix e boleto delegados a API externa — o banco armazena apenas `id_transacao_externo`.

| Coluna | Tipo | Restrições | Descrição |
|---|---|---|---|
| `pk_id_pagamento` | INT | PK surrogate | |
| `fk_id_contrato` | INT | FK → mensalidade (composta) | |
| `periodo` | CHAR(7) | FK → mensalidade (composta) | |
| `metodo` | VARCHAR(30) | FK → metodo_pagamento | |
| `data_pagamento` | DATE | NOT NULL | |
| `valor_pago` | DECIMAL(10,2) | NOT NULL, CHECK > 0 | |
| `status` | VARCHAR(20) | FK → status_pagamento | |
| `id_transacao_externo` | VARCHAR(50) | NULL | ID retornado pela API de Pix/Boleto. |

---

## Views OLTP

| View | Calcula | Motivo de ser view |
|---|---|---|
| `vw_valor_mensalidade` | `valor_final = valor_base - valor_desconto` | Campo derivado — nunca armazenar (critério 4). |
| `vw_nota_final` | `SUM(nota * peso) / SUM(peso)` por aluno/turma | Média ponderada é derivada das notas e pesos. |
| `vw_salario_liquido` | `salario_bruto + proventos - descontos` por folha | Líquido é derivado dos eventos de folha. |

---

## Star Schema OLAP — `erp_escolar_olap`

### `dim_tempo`
| Coluna | Tipo | Descrição |
|---|---|---|
| `pk_id_tempo` | INT | PK natural YYYYMM (ex: 202402). |
| `ano` | YEAR | |
| `mes` | TINYINT | 1–12 |
| `nome_mes` | VARCHAR(20) | Janeiro … Dezembro |
| `trimestre` | TINYINT | 1–4 |
| `semestre` | TINYINT | 1–2 |

### `dim_aluno`
| Coluna | Tipo | Descrição |
|---|---|---|
| `pk_id_aluno` | INT | Surrogate. |
| `rga` | CHAR(8) | UNIQUE — chave de lookup para o ETL. |
| `nome_completo` | VARCHAR(202) | Snapshot no momento da carga. |
| `ano_ingresso` | YEAR | |
| `curso_ingresso` | CHAR(3) | Curso na matrícula ativa (snapshot). |

### `dim_curso`
| Coluna | Tipo | Descrição |
|---|---|---|
| `pk_id_curso` | INT | Surrogate. |
| `codigo_curso` | CHAR(3) | UNIQUE — chave de lookup. |
| `nome_curso` | VARCHAR(100) | |
| `nivel_ensino` | VARCHAR(30) | |

### `dim_unidade`
Agrupamento analítico de cursos por área acadêmica. Não existe no OLTP — derivada no ETL via mapeamento `codigo_curso → area`.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pk_id_unidade` | INT | Surrogate. |
| `nome_unidade` | VARCHAR(60) | Tecnologia da Informacao, Ciencias da Saude, Gestao e Negocios. |

### `ft_receita_mensalidade`
Tabela fato. Grain: 1 linha por mensalidade gerada no OLTP.

| Coluna | Tipo | Descrição |
|---|---|---|
| `pk_id_fato` | INT | Surrogate. |
| `fk_id_tempo` | INT | FK → dim_tempo |
| `fk_id_aluno` | INT | FK → dim_aluno |
| `fk_id_curso` | INT | FK → dim_curso |
| `fk_id_unidade` | INT | FK → dim_unidade |
| `valor_base` | DECIMAL(10,2) | Métrica aditiva. |
| `valor_desconto` | DECIMAL(10,2) | Métrica aditiva. |
| `valor_liquido` | DECIMAL(10,2) | `valor_base - valor_desconto`. |
| `valor_pago` | DECIMAL(10,2) | 0.00 para não quitadas. |
| `status_mensalidade` | VARCHAR(10) | Degenerate dimension. |
| `tem_bolsa` | TINYINT(1) | Flag analítica (0/1). |
