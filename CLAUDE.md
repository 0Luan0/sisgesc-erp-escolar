# CLAUDE.md — SisGESC ERP Escolar

## Estado atual do projeto

Projeto de banco de dados relacional (MySQL 8+) para avaliação acadêmica (banca técnica — Unicid/SENAC).
Projeto testado e funcionando do zero em MySQL 9.7.0 (Mac) e compatível com MySQL 8.0 (Windows).

**Status:** pronto para entrega. Todos os arquivos estão no GitHub: https://github.com/0Luan0/sisgesc-erp-escolar

---

## Arquivos do projeto

| Arquivo | Conteúdo |
|---|---|
| `run_all.sql` | Ponto de entrada único — concatenação dos 7 arquivos abaixo, sem SOURCE |
| `01_ddl_estrutura.sql` | DDL completo: 33 tabelas, 5 views, 14 triggers |
| `02_dml_carga.sql` | Carga de dados (INSERT IGNORE) |
| `03_oltp_consultas.sql` | 15 consultas OLTP (Q01–Q15) + demonstração ACID |
| `04_olap_star_schema.sql` | Star schema (banco erp_escolar_olap) — 6 dims + 4 fatos |
| `05_etl_carga_olap.sql` | ETL full reload OLTP → OLAP |
| `06_validacao.sql` | Índices, EXPLAIN antes/depois, validação SUM OLTP = OLAP, 6 queries analíticas OLAP |
| `07_reset.sql` | DROP DATABASE erp_escolar e erp_escolar_olap |
| `docs/dicionario_dados.md` | Dicionário de dados completo |
| `docs/dbdiagram_sisgesc.dbml` | Código DBML para importar em dbdiagram.io |
| `docs/der_oltp_olap.png` | Imagem do diagrama ER (exportar manualmente do dbdiagram.io após editar DBML) |
| `teste_carga_duplicidade.sql` | Script de teste de carga com 1000 inserções + verificação de idempotência |

**IMPORTANTE:** sempre que alterar qualquer dos 7 arquivos individuais, regenerar o `run_all.sql`:
```bash
cat 07_reset.sql 01_ddl_estrutura.sql 02_dml_carga.sql 03_oltp_consultas.sql \
    04_olap_star_schema.sql 05_etl_carga_olap.sql 06_validacao.sql > run_all.sql
```

---

## Como testar localmente (Mac)

```bash
cp "/Users/luanlucena/Documents/Claude/Projects/Banco de Dados/run_all.sql" /tmp/run_all.sql
/usr/local/mysql/bin/mysql -u root -p
```

Dentro do MySQL (senha: Enter sem digitar nada):
```sql
SOURCE /tmp/run_all.sql
```

O MySQL está em `/usr/local/mysql/bin/mysql`. O SOURCE não aceita caminhos com espaço — por isso o cp para /tmp.

---

## Resultado esperado após execução limpa

- **33 tabelas** em `erp_escolar`
- **10 tabelas** em `erp_escolar_olap` (6 dims + 4 fatos)
- `ferias`: 3 registros, `conjuge_funcionario`: 2 registros
- `pagamento_a_vista`: 1 registro (Lucas/ADS, julho 2024, R$ 950.00 em Dinheiro)
- Validação financeira: `soma_oltp = soma_olap = 36387.50`, `diferenca = 0.00`
- ACID: rollback → 8 alunos antes = 8 depois; commit → A0000009 persiste

---

## Estrutura OLAP — Star Schema

### Dimensões (6)

| Tabela | PK | Descrição |
|---|---|---|
| `dim_tempo` | `SK_tempo` | Calendário YYYYMM — chave natural |
| `dim_aluno` | `SK_aluno` | Snapshot do aluno no momento da carga |
| `dim_curso` | `SK_curso` | Cursos ativos |
| `dim_unidade` | `SK_unidade` | Área acadêmica — criada no ETL, não existe no OLTP |
| `dim_materia` | `SK_materia` | Matérias ativas |
| `dim_funcionario` | `SK_funcionario` | Snapshot do funcionário no momento da carga |

### Fatos (4)

| Tabela | Grain | Dimensões usadas |
|---|---|---|
| `ft_receita_mensalidade` | 1 linha por mensalidade | tempo, aluno, curso, unidade |
| `ft_desempenho_academico` | 1 linha por (aluno × matéria × semestre) | aluno, curso, materia + degenerate dims |
| `ft_folha_rh` | 1 linha por (funcionário × período) | funcionario, tempo |
| `ft_movimentacao_rh` | 1 linha por admissão ou desligamento | funcionario, tempo |

### Convenção de nomenclatura OLAP (Kimball)

- PKs das dimensões: `SK_<entidade>` (ex: `SK_tempo`, `SK_aluno`)
- FKs nas fatos: `fk_SK_<entidade>` (ex: `fk_SK_tempo`, `fk_SK_aluno`)
- PKs das fatos: mantêm padrão OLTP `pk_id_fato` (não são surrogates de dimensão)

---

## Triggers ativos (14)

| Trigger | Tabela | Regra |
|---|---|---|
| `TR_matricula_ativa_insert` | matricula | Impede aluno com matrícula Cursando em outro curso |
| `TR_ponto_alternancia_insert` | ponto | Primeiro registro deve ser Entrada; alternância obrigatória |
| `TR_ponto_alternancia_update` | ponto | Mesmo critério na atualização |
| `TR_matricula_turma_curso_insert` | matricula_turma | Impede inscrição em turma de curso diferente da matrícula |
| `TR_turma_limite_alunos_insert` | matricula_turma | Impede ultrapassar `limite_alunos` da turma |
| `TR_pagamento_avista_contrato_coerente_insert` | pagamento_a_vista | Contrato deve estar Ativo |
| + 8 outros triggers de integridade | várias | Validações diversas |

---

## Views ativas (5) — banco erp_escolar

| View | Calcula |
|---|---|
| `vw_salario_liquido` | Salário bruto − descontos por funcionário |
| `vw_nota_final` | Média ponderada das notas por aluno/matéria/turma |
| `vw_valor_mensalidade` | Valor real após desconto do contrato |
| `vw_inadimplencia` | Mensalidades em atraso com dados do aluno e contrato |
| `vw_funcionario_aluno` | Lista unificada para evitar CPF duplicado entre módulos |

---

## Bugs corrigidos (histórico completo)

| Bug | Causa | Correção |
|---|---|---|
| `ferias` vazia após DML | Datas fora do `periodo_aquisitivo` — trigger rejeitava via INSERT IGNORE | Corrigidas as datas e referências de período |
| ERROR 1146 `conjuge_funcionario doesn't exist` | `DEFAULT (CURRENT_DATE)` parava o DDL antes de chegar na tabela | Removido o DEFAULT da coluna `data_solicitacao` em `abono_ferias` |
| ERROR 3823 | `fk_rgf_1/fk_rgf_2` em CHECK constraint + FK com ON UPDATE CASCADE | Trocado para ON UPDATE RESTRICT em `conjuge_funcionario` |
| ACID Cenário 1 e 2 falhavam | RGA 'A0000001' já existia — INSERT duplicado | Trocado para 'A0000009' |
| `SOURCE` não funcionava com `<` redirecionamento | SOURCE é comando interativo do MySQL | `run_all.sql` gerado como arquivo único sem SOURCE |
| `CREATE INDEX IF NOT EXISTS` falhava | Sintaxe inválida no MySQL | Removido o `IF NOT EXISTS` de todos os CREATE INDEX |
| SOURCE com espaço no caminho falhava | SOURCE não aceita espaços nem com aspas nem com backslash | Copiar para /tmp antes de rodar |
| `TR_ponto_alternancia` aceitava qualquer tipo como primeiro ponto | Bloco `IF ultimo_tipo IS NOT NULL` pulado quando sem registro anterior | Adicionado `ELSE` nos dois triggers exigindo `Entrada` como primeiro registro |
| `03_oltp_consultas.sql` com dois Q05 e Q13 antes de Q12 | Q05-RH e Q05 nomeados igual; Q13 escrito antes de Q12 | Renumeração completa Q01–Q15 |
| ERROR 1644 no teste de carga | `TR_matricula_ativa` usa SIGNAL — não suprimido por INSERT IGNORE | Comportamento correto: trigger funciona, duplicatas bloqueadas |

---

## Critérios de modelagem (lei do projeto)

1. **1FN/2FN/3FN** obrigatórios em todas as tabelas
2. **PK natural** quando estável/imutável/controlada pelo sistema (rga, rgf, codigo_curso)
3. **PK composta** em N:N simples (curso_materia, matricula_turma)
4. **PK surrogate** quando composta teria 4+ campos e seria usada como FK
5. **Tabelas de domínio separadas por contexto** (status_aluno, status_matricula — nunca unificadas)
6. **Campos derivados nunca armazenados** — viram VIEW (nota_final, salario_liquido)
7. **Regras de negócio** via CHECK, UNIQUE documentado, ou trigger
8. **Nomenclatura OLTP:** tabelas snake_case singular, FKs `fk_<campo>`, surrogates `pk_id_<entidade>`
9. **Nomenclatura OLAP:** PKs de dimensão `SK_<entidade>`, FKs de fato `fk_SK_<entidade>` (convenção Kimball)

---

## Decisões de design já tomadas (não alterar)

- Financeiro: `matricula → contrato → mensalidade → pagamento`
- Professor é papel de funcionário (PK herdada, não entidade independente)
- Calendário acadêmico: `fk_curso NULL` = institucional; PK surrogate (nullable impede composta)
- Grade curricular versionada: `curso_materia` (base) + `curso_materia_revisao` (alterações)
- `folha_evento.valor` sempre positivo; sinal determinado por `evento_folha.tipo`
- Pix/Boleto delegados a API externa — banco guarda apenas `id_transacao_externo`
- Holerite é relatório, não tabela
- `dim_unidade` não existe no OLTP — criada no ETL por mapeamento: ADS→TI, ENF→Saúde, LOG→Gestão
- `salario_liquido` em `ft_folha_rh` é snapshot OLAP intencional — não é campo derivado proibido
- OLAP usa full reload (TRUNCATE + INSERT): idempotente, rodar N vezes produz o mesmo resultado

---

## Dialeto e restrições técnicas

- MySQL 8+ (utf8mb4_unicode_ci)
- UNIQUE parcial (WHERE) não existe no MySQL — documentar como comentário e sugerir trigger
- `CREATE INDEX IF NOT EXISTS` não existe no MySQL — usar `CREATE INDEX` simples
- `DEFAULT (CURRENT_DATE)` com parênteses requer MySQL 8.0.13+ mas causa problemas — evitar
- `ON UPDATE CASCADE` em FK cujas colunas aparecem em CHECK constraint gera ERROR 3823 — usar RESTRICT
- `SIGNAL SQLSTATE '45000'` em trigger NÃO é suprimido por INSERT IGNORE — erro 1644 é impresso mas execução continua
- Todo código deve ser executável diretamente sem erros de sintaxe
