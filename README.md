# SisGESC — ERP Escolar

Sistema de gestão escolar com três módulos: RH, Acadêmico e Financeiro.
Desenvolvido como projeto de banco de dados relacional em MySQL 8+.

---

## Execução — passo a passo (MySQL Workbench)

> Recomendado para avaliação. Funciona igual em Windows e macOS.

1. Abra o **MySQL Workbench** e conecte-se ao servidor local
2. No menu superior: **File → Run SQL Script...**
3. Selecione o arquivo **`run_all.sql`** (disponível na raiz do repositório)
4. Na caixa "Default Schema" que aparecer: deixe em **branco** e clique em **Run**
5. Aguarde a execução completa (alguns segundos)
6. Verifique o resultado esperado abaixo

> **Importante:** use sempre "Run SQL Script" (menu File), não o botão de raio (Execute). O "Run SQL Script" processa corretamente as mudanças de DELIMITER necessárias para os triggers.

---

## Execução — linha de comando

### Windows (CMD)

```cmd
cd C:\caminho\ate\a\pasta\do\projeto
"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" -u root -p < run_all.sql
```

### macOS / Linux

```bash
cp run_all.sql /tmp/run_all.sql
/usr/local/mysql/bin/mysql -u root -p
```
Dentro do MySQL:
```sql
SOURCE /tmp/run_all.sql
```

> O arquivo `run_all.sql` e autocontido — nao usa SOURCE internamente. Funciona com qualquer cliente MySQL.

---

## Resultado esperado apos execucao

### Banco OLTP — `erp_escolar` (33 tabelas)

| tabela | registros |
|---|---|
| funcionario | 6 |
| professor | 2 |
| aluno | 8 |
| matricula | 8 |
| curso | 3 |
| materia | 6 |
| turma | 6 |
| contrato | 8 |
| mensalidade | 48 |
| pagamento | 42 |
| folha_pagamentos | 18 |
| folha_evento | 78 |
| ferias | 3 |
| conjuge_funcionario | 2 |

### Banco OLAP — `erp_escolar_olap` (star schema)

| tabela | registros |
|---|---|
| dim_tempo | 6 |
| dim_aluno | 8 |
| dim_curso | 3 |
| dim_unidade | 3 |
| ft_receita_mensalidade | 48 |

### Validacao financeira (OLTP = OLAP)

```
soma_oltp   soma_olap   diferenca
36387.50    36387.50    0.00
```

Qualquer `diferenca != 0.00` indica erro no ETL.

---

## Resetar e executar do zero

Para repetir a execucao em um banco ja populado:

**Workbench:** File -> Run SQL Script -> selecione `07_reset.sql` -> Run.
Em seguida repita com `run_all.sql`.

**Linha de comando:**
```cmd
mysql -u root -p < 07_reset.sql
mysql -u root -p < run_all.sql
```

O reset elimina os bancos `erp_escolar` e `erp_escolar_olap` completamente antes de recriar.

---

## Estrutura do repositorio

```
/
├── run_all.sql              <- ponto de entrada unico (use este)
├── 01_ddl_estrutura.sql     # DDL completo: 33 tabelas, views, 14 triggers
├── 02_dml_carga.sql         # carga de dados idempotente (INSERT IGNORE)
├── 03_oltp_consultas.sql    # 12 consultas OLTP + demonstracao ACID
├── 04_olap_star_schema.sql  # star schema (banco erp_escolar_olap)
├── 05_etl_carga_olap.sql    # ETL full reload OLTP -> OLAP
├── 06_validacao.sql         # indices, EXPLAIN antes/depois, SUM OLTP = OLAP
├── 07_reset.sql             # DROP DATABASE para reinicio limpo
└── docs/
    ├── dicionario_dados.md  # dicionario de dados completo (todas as 33 tabelas)
    └── der_oltp_olap.png    # DER com modelagem OLTP + Star Schema OLAP
```

---

## Documentacao tecnica

- **[Dicionario de Dados](docs/dicionario_dados.md)** — todas as 33 tabelas, tipos, restricoes e proposito de cada coluna
- **[DER OLTP + OLAP](docs/der_oltp_olap.png)** — diagrama entidade-relacionamento refletindo exatamente o schema atual, incluindo o Star Schema

---

## Modulos e principais entidades

**RH:** `funcionario` -> `professor` (papel, PK herdada), `cargo`, `folha_pagamentos`, `folha_evento`, `historico_salario`, `ferias`, `periodo_aquisitivo`, `ponto`, `dependente`, `conjuge_funcionario`

**Academico:** `curso` -> `materia` (grade em `curso_materia`), `calendario_academico`, `aluno` -> `matricula` -> `turma` -> `nota` / `frequencia`

**Financeiro:** `matricula` -> `contrato` -> `mensalidade` -> `pagamento`. Toda cobranca nasce no contrato.

---

## Decisoes de arquitetura

| Decisao | Justificativa |
|---|---|
| Pix/Boleto sem tabela propria | Operacao delegada a API externa; banco guarda apenas `id_transacao_externo` |
| Campos derivados nunca armazenados | `nota_final`, `salario_liquido` existem como VIEW — criterio 3FN |
| Holerite nao e tabela | Relatorio gerado sob demanda pela aplicacao |
| `dim_unidade` criada no ETL | Nao existe no OLTP; mapeada via curso -> area academica no ETL |
| Calendario com `fk_curso NULL` | NULL = institucional (vale para todos); PK surrogate porque nullable impede PK composta |
| `professor` com PK herdada | Professor e papel de funcionario — cardinalidade 1:1, sem identidade propria |

---

## Bancos criados

| Banco | Proposito |
|---|---|
| `erp_escolar` | OLTP — operacoes transacionais do dia a dia |
| `erp_escolar_olap` | OLAP — star schema para analise gerencial |
