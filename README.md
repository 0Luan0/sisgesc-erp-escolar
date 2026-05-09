# SisGESC — ERP Escolar

Sistema de gestão escolar com três módulos: RH, Acadêmico e Financeiro.
Desenvolvido como projeto de banco de dados relacional em MySQL 8+.

---

## Pré-requisitos

- MySQL 8.0+
- Usuário com `CREATE DATABASE`, `CREATE TABLE`, `TRIGGER`, `EVENT` privileges
- Cliente MySQL (Workbench, DBeaver, ou CLI)

---

## Como executar

### Opção 1 — script único (recomendado)

```bash
mysql -u root -p < run_all.sql
```

Executa todas as fases em ordem: DDL → carga → consultas OLTP → OLAP → ETL → validação.

### Opção 2 — fase a fase

Útil para acompanhar a saída de cada etapa separadamente.

```bash
mysql -u root -p < 01_ddl_estrutura.sql   # cria banco e tabelas
mysql -u root -p < 02_dml_carga.sql       # carga inicial
mysql -u root -p < 03_oltp_consultas.sql  # consultas OLTP
mysql -u root -p < 04_olap_star_schema.sql # estrutura OLAP
mysql -u root -p < 05_etl_carga_olap.sql  # ETL + validação cruzada
mysql -u root -p < 06_validacao.sql       # índices + EXPLAIN + consistência
```

### Resetar tudo

```bash
mysql -u root -p < 07_reset.sql
```

Remove todas as tabelas do `erp_escolar` e dropa o banco `erp_escolar_olap`. Após o reset, basta rodar `run_all.sql` novamente.

---

## Estrutura do repositório

```
/
├── run_all.sql              # ponto de entrada único
├── 01_ddl_estrutura.sql     # DDL completo: tabelas, views, triggers
├── 02_dml_carga.sql         # carga idempotente (INSERT IGNORE)
├── 03_oltp_consultas.sql    # 12 consultas OLTP em 3 níveis
├── 04_olap_star_schema.sql  # star schema (banco erp_escolar_olap)
├── 05_etl_carga_olap.sql    # ETL full reload OLTP → OLAP
├── 06_validacao.sql         # índices, EXPLAIN antes/depois, SUM OLTP = OLAP
├── 07_reset.sql             # DROP/TRUNCATE para execução limpa
└── docs/
    └── dicionario_dados.md  # dicionário completo de todas as tabelas
```

---

## Módulos e principais entidades

**RH:** `funcionario` → `professor` (papel, PK herdada), `cargo`, `folha_pagamentos`, `folha_evento`, `historico_salario`, `ferias`

**Acadêmico:** `curso` → `materia` (grade em `curso_materia`), `calendario_academico`, `aluno` → `matricula` → `turma` → `nota` / `frequencia`

**Financeiro:** `matricula` → `contrato` → `mensalidade` → `pagamento`. Toda cobrança nasce no contrato.

---

## Decisões de arquitetura relevantes

- **Pix/Boleto** não têm tabela própria. A operação financeira é delegada a uma API externa; o banco registra apenas `id_transacao_externo` em `pagamento`. Evita duplicar regras de negócio de meios de pagamento dentro do banco.
- **Campos derivados** (`nota_final`, `salario_liquido`, `valor_final`) nunca são armazenados. Existem como `VIEW` para consulta.
- **Holerite** é relatório gerado pela aplicação — não é tabela.
- **dim_unidade** no OLAP não existe no OLTP. É criada no ETL via mapeamento `curso → área acadêmica`, permitindo análise por grande área sem expor a granularidade do curso.
- **Calendário acadêmico** com `fk_curso NULL` representa o calendário institucional (vale para todos os cursos). PK surrogate porque nullable impede PK composta.

---

## Bancos criados

| Banco | Propósito |
|---|---|
| `erp_escolar` | OLTP — operações do dia a dia |
| `erp_escolar_olap` | OLAP — star schema para análise |
